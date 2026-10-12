import XCTest
@testable import SparListeCore

final class PersistenceTests: XCTestCase {
    func testJSONRoundTripKeepsAllData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sparliste-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = SampleData.make(now: TestSupport.now, calendar: TestSupport.calendar)
        let persistence = JSONFilePersistence(fileURL: url)
        try persistence.save(data)
        let loaded = try XCTUnwrap(try persistence.load())
        XCTAssertEqual(loaded, data)
    }

    func testMissingFileLoadsNil() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID().uuidString).json")
        XCTAssertNil(try JSONFilePersistence(fileURL: url).load())
    }

    func testLocalDataStoreSeedsOnceAndPersistsChanges() async throws {
        let persistence = InMemoryPersistence()
        let store = try LocalDataStore(persistence: persistence, seed: { SampleData.make(now: TestSupport.now) })
        XCTAssertEqual(persistence.saveCount, 1)

        var list = ShoppingList(name: "Test")
        list.items = [ShoppingListItem(query: "Milch")]
        try await store.save(list)
        let reopened = try LocalDataStore(persistence: persistence, seed: { AppData() })
        let lists = await reopened.allLists()
        XCTAssertTrue(lists.contains { $0.id == list.id && $0.items.count == 1 })
        let reopenedStores = await reopened.allStores()
        XCTAssertFalse(reopenedStores.isEmpty, "Seed darf beim zweiten Start nicht erneut greifen")
    }

    func testDeletingStoreAlsoDeletesItsPrices() async throws {
        let store = try LocalDataStore(persistence: InMemoryPersistence(), seed: { SampleData.make(now: TestSupport.now) })
        try await store.deleteStore(id: SampleData.StoreID.lidl)
        let prices = await store.allPriceEntries()
        XCTAssertFalse(prices.contains { $0.storeID == SampleData.StoreID.lidl })
    }

    func testDuplicateListGetsNewIDsAndUncheckedItems() {
        var original = ShoppingList(name: "Wocheneinkauf", items: [ShoppingListItem(query: "Milch", isChecked: true)])
        original.items.append(ShoppingListItem(query: "Brot"))
        let copy = original.duplicated(now: TestSupport.now)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.name, "Wocheneinkauf (Kopie)")
        XCTAssertEqual(copy.items.map(\.query), ["Milch", "Brot"])
        XCTAssertTrue(copy.items.allSatisfy { !$0.isChecked })
        XCTAssertTrue(Set(copy.items.map(\.id)).isDisjoint(with: Set(original.items.map(\.id))))
    }

    func testJSONImportAddsPricesAndMarksSource() async throws {
        let store = try LocalDataStore(persistence: InMemoryPersistence(), seed: { SampleData.make(now: TestSupport.now) })
        let json = """
        {
          "prices": [
            {
              "id": "import-1",
              "productID": "butter-ja",
              "storeID": "\(SampleData.StoreID.rewe)",
              "price": { "cents": 199 },
              "kind": { "offer": { "validFrom": "2026-10-10T00:00:00Z", "validUntil": "2026-10-17T00:00:00Z" } },
              "availability": "available",
              "source": "sampleData",
              "observedAt": "2026-10-12T08:00:00Z"
            }
          ]
        }
        """
        let catalog = await store.catalog()
        let payload = try JSONPriceImporter().decode(Data(json.utf8), existingCatalog: catalog)
        XCTAssertEqual(payload.prices.first?.source, .imported)
        XCTAssertTrue(payload.prices.first?.isOffer ?? false)
        let summary = try await store.apply(payload)
        XCTAssertEqual(summary.added, 1)
        let entries = await store.allPriceEntries()
        XCTAssertTrue(entries.contains { $0.id == "import-1" })
    }

    func testJSONImportRejectsUnknownProduct() {
        let json = #"{"prices":[{"id":"x","productID":"unknown","storeID":"s","price":{"cents":1},"kind":{"regular":{}},"availability":"available","source":"imported","observedAt":"2026-10-12T08:00:00Z"}]}"#
        XCTAssertThrowsError(try JSONPriceImporter().decode(Data(json.utf8), existingCatalog: Catalog())) { error in
            XCTAssertEqual(error as? PriceImportError, .unknownProduct("unknown"))
        }
        XCTAssertThrowsError(try JSONPriceImporter().decode(Data("kein json".utf8), existingCatalog: Catalog()))
    }
}

final class ReadmeExampleTests: XCTestCase {
    /// Das JSON-Importbeispiel im README muss vom Importer akzeptiert werden.
    func testReadmeImportExampleDecodes() throws {
        let readme = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SparListeCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // SparListeKit
            .deletingLastPathComponent() // Repository
            .appendingPathComponent("README.md")
        guard let text = try? String(contentsOf: readme, encoding: .utf8) else {
            throw XCTSkip("README.md nicht gefunden")
        }
        let start = try XCTUnwrap(text.range(of: "```json\n"))
        let end = try XCTUnwrap(text.range(of: "\n```", range: start.upperBound..<text.endIndex))
        let json = String(text[start.upperBound..<end.lowerBound])
        let payload = try JSONPriceImporter().decode(Data(json.utf8), existingCatalog: Catalog())
        XCTAssertEqual(payload.brands.count, 1)
        XCTAssertEqual(payload.products.first?.packageSize, Quantity(250, .gram))
        XCTAssertEqual(payload.prices.count, 2)
        XCTAssertTrue(payload.prices[1].isOffer)
    }
}

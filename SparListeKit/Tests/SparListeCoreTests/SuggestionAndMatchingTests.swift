import XCTest
@testable import SparListeCore

final class SuggestionAndMatchingTests: XCTestCase {
    private let catalog = SampleData.make(now: TestSupport.now).catalog

    func testNormalizationIgnoresCaseAndUmlauts() {
        XCTAssertEqual(TextMatching.normalize("  Äpfel,  BIO! "), "apfel bio")
        XCTAssertTrue(TextMatching.matchesAllTokens(query: "lakto milch", in: "Laktosefreie Milch 1,5 %"))
    }

    func testGenericSuggestionComesFirst() {
        let suggestions = ProductSuggestionService(catalog: catalog).suggestions(for: "lakt")
        XCTAssertEqual(suggestions.first?.title, "Laktosefreie Milch")
        XCTAssertEqual(suggestions.first?.typicalPackageSize, Quantity(1, .liter))
        XCTAssertTrue(suggestions.contains { $0.title == "Laktosefreie Milch – MinusL" && $0.brandID == "brand-minusl" })
    }

    func testBrandPrefixFindsBrandedSuggestion() {
        let suggestions = ProductSuggestionService(catalog: catalog).suggestions(for: "Barilla")
        XCTAssertEqual(suggestions.first?.title, "Spaghetti – Barilla")
    }

    func testEmptyInputGivesNoSuggestions() {
        XCTAssertTrue(ProductSuggestionService(catalog: catalog).suggestions(for: "  ").isEmpty)
    }

    func testBrandsForGenericName() {
        let names = ProductSuggestionService(catalog: catalog).brands(forGenericName: "Butter").map(\.name)
        XCTAssertEqual(names, ["Gut & Günstig", "Ja!", "Kerrygold", "Milbona", "Milsani"])
    }

    func testExactGenericMatchDoesNotPullInOtherProducts() {
        // „Milch“ ist kein allgemeiner Name im Katalog → Teiltreffer (Vollmilch, Laktosefreie Milch).
        let matcher = ProductMatcher(catalog: catalog)
        XCTAssertTrue(matcher.candidates(for: "Milch").contains { $0.genericName == "Vollmilch" })
        // „Vollmilch“ ist exakt → nur Vollmilch.
        XCTAssertTrue(matcher.candidates(for: "Vollmilch").allSatisfy { $0.genericName == "Vollmilch" })
    }
}

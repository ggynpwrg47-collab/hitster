import XCTest
@testable import SparListeCore

final class BrandRequirementTests: XCTestCase {
    private let brands = [
        Brand(id: "minusl", name: "MinusL"),
        Brand(id: "ja", name: "Ja!", privateLabelOf: .rewe),
        Brand(id: "milsani", name: "Milsani", privateLabelOf: .aldi)
    ]
    private let products = [
        TestSupport.product("lf-minusl", generic: "Laktosefreie Milch", brand: "minusl", size: Quantity(1, .liter)),
        TestSupport.product("lf-ja", generic: "Laktosefreie Milch", brand: "ja", size: Quantity(1, .liter)),
        TestSupport.product("lf-milsani", generic: "Laktosefreie Milch", brand: "milsani", size: Quantity(1, .liter)),
        TestSupport.product("lf-bio", generic: "Laktosefreie Milch", size: Quantity(1, .liter), organic: true)
    ]
    private let stores = [TestSupport.store("rewe", .rewe), TestSupport.store("aldi", .aldi)]

    func testRequiredBrandWinsOverCheapestProduct() {
        let prices = [
            TestSupport.price("lf-minusl", "rewe", 1.69),
            TestSupport.price("lf-ja", "rewe", 1.19),
            TestSupport.price("lf-milsani", "aldi", 1.09)
        ]
        let item = ShoppingListItem(query: "Laktosefreie Milch", requiredBrandID: "minusl")
        let result = TestSupport.optimize([item], stores: stores, products: products, brands: brands, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        XCTAssertEqual(result.recommendation?.lines.first?.option.product.id, "lf-minusl")
        XCTAssertEqual(result.recommendation?.total, Money(euros: 1.69))
    }

    func testUnavailableRequiredBrandIsReportedWithAlternatives() {
        let prices = [
            TestSupport.price("lf-minusl", "rewe", 1.69, availability: .unavailable),
            TestSupport.price("lf-ja", "rewe", 1.19),
            TestSupport.price("lf-milsani", "aldi", 1.09)
        ]
        let item = ShoppingListItem(query: "Laktosefreie Milch", requiredBrandID: "minusl")
        let result = TestSupport.optimize([item], stores: stores, products: products, brands: brands, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        XCTAssertNil(result.recommendation)
        let unavailable = try? XCTUnwrap(result.unavailableItems.first)
        XCTAssertEqual(unavailable?.issues, [.requiredBrandUnavailable(brandName: "MinusL")])
        XCTAssertEqual(unavailable?.alternatives.map(\.product.id), ["lf-milsani", "lf-ja"])
        XCTAssertTrue(unavailable?.reason.contains("MinusL") ?? false)
    }

    func testBrandSubstitutionWhenAllowed() {
        let prices = [TestSupport.price("lf-ja", "rewe", 1.19), TestSupport.price("lf-milsani", "aldi", 1.09)]
        let item = ShoppingListItem(query: "Laktosefreie Milch", requiredBrandID: "minusl", allowsBrandSubstitution: true)
        let result = TestSupport.optimize([item], stores: stores, products: products, brands: brands, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        XCTAssertEqual(result.recommendation?.lines.first?.option.product.id, "lf-milsani")
        XCTAssertTrue(result.unavailableItems.isEmpty)
        XCTAssertTrue(result.notices.contains { $0.kind == .brandSubstitution })
    }

    func testExcludedBrandsAndIngredients() {
        let productsWithIngredients = [
            TestSupport.product("toast-a", generic: "Toastbrot", brand: "ja", ingredients: ["Weizenmehl", "Palmfett"]),
            TestSupport.product("toast-b", generic: "Toastbrot", brand: "milsani", ingredients: ["Weizenmehl"]),
            TestSupport.product("toast-c", generic: "Toastbrot", brand: "minusl", ingredients: ["Dinkelmehl"])
        ]
        let prices = [
            TestSupport.price("toast-a", "rewe", 0.99),
            TestSupport.price("toast-b", "aldi", 1.19),
            TestSupport.price("toast-c", "aldi", 1.49)
        ]
        let item = ShoppingListItem(query: "Toastbrot", excludedBrandIDs: ["milsani"], excludedIngredients: ["palmfett"])
        let result = TestSupport.optimize([item], stores: stores, products: productsWithIngredients, brands: brands, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        XCTAssertEqual(result.recommendation?.lines.first?.option.product.id, "toast-c")

        let allExcluded = ShoppingListItem(query: "Toastbrot", excludedIngredients: ["mehl"])
        let excludedResult = TestSupport.optimize([allExcluded], stores: stores, products: productsWithIngredients, brands: brands,
                                                  prices: prices, settings: TestSupport.settings(.cheapestOverall))
        XCTAssertEqual(excludedResult.unavailableItems.first?.issues, [.allCandidatesExcluded])
    }

    func testOrganicPreferenceUsesOrganicWhenAvailable() {
        let prices = [TestSupport.price("lf-ja", "rewe", 1.19), TestSupport.price("lf-bio", "aldi", 1.59)]
        let item = ShoppingListItem(query: "Laktosefreie Milch", prefersOrganic: true)
        let result = TestSupport.optimize([item], stores: stores, products: products, brands: brands, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        XCTAssertEqual(result.recommendation?.lines.first?.option.product.id, "lf-bio")
    }

    func testOrganicPreferenceFallsBackWithNotice() {
        let prices = [TestSupport.price("lf-ja", "rewe", 1.19)]
        let item = ShoppingListItem(query: "Laktosefreie Milch", prefersOrganic: true)
        let result = TestSupport.optimize([item], stores: stores, products: products, brands: brands, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        XCTAssertEqual(result.recommendation?.lines.first?.option.product.id, "lf-ja")
        XCTAssertTrue(result.notices.contains { $0.kind == .preference })
    }

    func testPrivateLabelPreference() {
        let prices = [TestSupport.price("lf-minusl", "rewe", 1.05), TestSupport.price("lf-ja", "rewe", 1.19)]
        let item = ShoppingListItem(query: "Laktosefreie Milch", prefersPrivateLabel: true)
        let result = TestSupport.optimize([item], stores: stores, products: products, brands: brands, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        XCTAssertEqual(result.recommendation?.lines.first?.option.product.id, "lf-ja")
    }
}

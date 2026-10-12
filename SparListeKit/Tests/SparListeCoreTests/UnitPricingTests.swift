import XCTest
@testable import SparListeCore

final class UnitPricingTests: XCTestCase {
    func testUnitPricePerKilogramForGramPackage() throws {
        let unit = try XCTUnwrap(UnitPricing.unitPrice(price: Money(euros: 2.09), packageSize: Quantity(250, .gram)))
        XCTAssertEqual(unit.basis, .perKilogram)
        XCTAssertEqual(unit.centsPerBasis, 836, accuracy: 0.0001)
        XCTAssertEqual(unit.formatted, "8,36 € / 1 kg")
    }

    func testUnitPricePerLiterForMilliliterPackage() throws {
        let unit = try XCTUnwrap(UnitPricing.unitPrice(price: Money(euros: 0.99), packageSize: Quantity(500, .milliliter)))
        XCTAssertEqual(unit.basis, .perLiter)
        XCTAssertEqual(unit.rounded, Money(euros: 1.98))
    }

    func testUnitPricePer100GramAndPerPiece() throws {
        let per100 = try XCTUnwrap(UnitPricing.unitPrice(price: Money(euros: 1.50), packageSize: Quantity(300, .gram), basis: .per100Gram))
        XCTAssertEqual(per100.centsPerBasis, 50, accuracy: 0.0001)
        let perPiece = try XCTUnwrap(UnitPricing.unitPrice(price: Money(euros: 2.49), packageSize: Quantity(10, .piece)))
        XCTAssertEqual(perPiece.centsPerBasis, 24.9, accuracy: 0.0001)
    }

    func testUnitPriceRejectsIncompatibleBasisAndZeroSize() {
        XCTAssertNil(UnitPricing.unitPrice(price: Money(euros: 1), packageSize: Quantity(1, .liter), basis: .perKilogram))
        XCTAssertNil(UnitPricing.unitPrice(price: Money(euros: 1), packageSize: Quantity(0, .gram)))
    }

    func testDifferentPackageSizesBecomeComparable() throws {
        // 1,5 l für 1,49 € ist pro Liter günstiger als 1 l für 1,09 €.
        let large = try XCTUnwrap(UnitPricing.unitPrice(price: Money(euros: 1.49), packageSize: Quantity(1.5, .liter)))
        let small = try XCTUnwrap(UnitPricing.unitPrice(price: Money(euros: 1.09), packageSize: Quantity(1, .liter)))
        XCTAssertLessThan(large, small)
    }

    func testPackagesNeeded() {
        XCTAssertEqual(UnitPricing.packagesNeeded(toCover: Quantity(2, .liter), with: Quantity(1, .liter)), 2)
        XCTAssertEqual(UnitPricing.packagesNeeded(toCover: Quantity(2, .liter), with: Quantity(1.5, .liter)), 2)
        XCTAssertEqual(UnitPricing.packagesNeeded(toCover: Quantity(1, .kilogram), with: Quantity(250, .gram)), 4)
        XCTAssertEqual(UnitPricing.packagesNeeded(toCover: Quantity(100, .gram), with: Quantity(1, .kilogram)), 1)
        XCTAssertEqual(UnitPricing.packagesNeeded(toCover: Quantity(1, .liter), with: Quantity(1.0 / 3.0, .liter)), 3)
        XCTAssertNil(UnitPricing.packagesNeeded(toCover: Quantity(1, .liter), with: Quantity(500, .gram)))
    }

    func testOptimizerComparesByNeededAmountAcrossPackageSizes() {
        // Bedarf 2 × 500 g: 2 × 500 g zu 1,10 € (2,20 €) gegen 1 × 1 kg zu 1,99 € → 1 kg gewinnt.
        let products = [
            TestSupport.product("small", generic: "Reis", size: Quantity(500, .gram)),
            TestSupport.product("large", generic: "Reis", size: Quantity(1, .kilogram))
        ]
        let prices = [TestSupport.price("small", "s1", 1.10), TestSupport.price("large", "s1", 1.99)]
        let item = ShoppingListItem(query: "Reis", quantity: 2, desiredPackageSize: Quantity(500, .gram))
        let result = TestSupport.optimize([item], stores: [TestSupport.store("s1")], products: products, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        let line = result.recommendation?.lines.first
        XCTAssertEqual(line?.option.product.id, "large")
        XCTAssertEqual(line?.option.packageCount, 1)
        XCTAssertEqual(line?.lineTotal, Money(euros: 1.99))
    }

    func testWithoutDesiredSizeTheMostCommonSizeIsTheReference() {
        // Häufigste Größe ist 1 l → Menge 2 bedeutet 2 l; die 0,5-l-Packung braucht 4 Stück.
        let products = [
            TestSupport.product("a", generic: "Saft", size: Quantity(1, .liter)),
            TestSupport.product("b", generic: "Saft", size: Quantity(1, .liter)),
            TestSupport.product("c", generic: "Saft", size: Quantity(500, .milliliter))
        ]
        let prices = [TestSupport.price("a", "s1", 1.50), TestSupport.price("b", "s1", 1.60), TestSupport.price("c", "s1", 0.70)]
        let item = ShoppingListItem(query: "Saft", quantity: 2)
        let result = TestSupport.optimize([item], stores: [TestSupport.store("s1")], products: products, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        let line = result.recommendation?.lines.first
        XCTAssertEqual(line?.option.product.id, "c")
        XCTAssertEqual(line?.option.packageCount, 4)
        XCTAssertEqual(line?.lineTotal, Money(euros: 2.80))
    }
}

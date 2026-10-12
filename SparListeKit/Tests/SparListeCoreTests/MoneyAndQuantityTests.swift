import XCTest
@testable import SparListeCore

final class MoneyAndQuantityTests: XCTestCase {
    func testMoneyFromEurosRoundsToCents() {
        XCTAssertEqual(Money(euros: 1.19).cents, 119)
        XCTAssertEqual(Money(euros: 0.1 + 0.2).cents, 30)
    }

    func testMoneyArithmeticAndFormatting() {
        let total = [Money(euros: 1.99), Money(euros: 2.01), Money(cents: 5)].sum()
        XCTAssertEqual(total.cents, 405)
        XCTAssertEqual(total.formatted, "4,05 €")
        XCTAssertEqual(Money(cents: 123_456).formatted, "1.234,56 €")
        XCTAssertEqual(Money(cents: -50).formatted, "-0,50 €")
        XCTAssertEqual((Money(euros: 1.29) * 3).cents, 387)
    }

    func testQuantityBaseValuesAndComparability() {
        XCTAssertEqual(Quantity(1.5, .liter).baseValue, 1500)
        XCTAssertEqual(Quantity(250, .gram).baseValue, 250)
        XCTAssertTrue(Quantity(1, .kilogram).isComparable(to: Quantity(500, .gram)))
        XCTAssertFalse(Quantity(1, .liter).isComparable(to: Quantity(1, .kilogram)))
        XCTAssertEqual(Quantity(1.5, .liter).formatted, "1,5 l")
        XCTAssertEqual(Quantity(10, .piece).formatted, "10 Stk.")
    }
}

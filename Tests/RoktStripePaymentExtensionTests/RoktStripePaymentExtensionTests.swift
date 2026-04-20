import XCTest
@testable import RoktStripePaymentExtension
import RoktContracts

final class RoktStripePaymentExtensionTests: XCTestCase {

    func testInitWithEmptyMerchantIdReturnsNil() {
        XCTAssertNil(RoktStripePaymentExtension(applePayMerchantId: ""))
    }

    func testInitWithValidMerchantIdReturnsInstance() {
        let ext = RoktStripePaymentExtension(applePayMerchantId: "merchant.test")
        XCTAssertNotNil(ext)
    }

    func testProtocolProperties() {
        let ext = RoktStripePaymentExtension(applePayMerchantId: "merchant.test")!
        XCTAssertEqual(ext.id, "rokt-stripe-payment-extension")
        XCTAssertEqual(ext.extensionDescription, "Rokt Stripe Payment Extension")
        XCTAssertEqual(ext.supportedMethods, ["apple_pay", "card", "afterpay_clearpay"])
    }

    func testOnRegisterWithoutStripeKeyReturnsFalse() {
        let ext = RoktStripePaymentExtension(applePayMerchantId: "merchant.test")!
        XCTAssertFalse(ext.onRegister(parameters: [:]))
    }

    func testOnRegisterWithEmptyStripeKeyReturnsFalse() {
        let ext = RoktStripePaymentExtension(applePayMerchantId: "merchant.test")!
        XCTAssertFalse(ext.onRegister(parameters: ["stripeKey": ""]))
    }

    func testOnRegisterWithValidKeyReturnsTrue() {
        let ext = RoktStripePaymentExtension(applePayMerchantId: "merchant.test")!
        XCTAssertTrue(ext.onRegister(parameters: ["stripeKey": "pk_test_123"]))
    }

    func testOnUnregisterNilsManager() {
        let ext = RoktStripePaymentExtension(applePayMerchantId: "merchant.test")!
        XCTAssertTrue(ext.onRegister(parameters: ["stripeKey": "pk_test_123"]))
        ext.onUnregister()
        XCTAssertTrue(ext.onRegister(parameters: ["stripeKey": "pk_test_456"]))
    }

    func testInitWithCustomCountryCode() {
        let ext = RoktStripePaymentExtension(applePayMerchantId: "merchant.test", countryCode: "AU")
        XCTAssertNotNil(ext)
    }

    func testInitWithReturnURL() {
        let ext = RoktStripePaymentExtension(
            applePayMerchantId: "merchant.test",
            returnURL: "myapp://stripe-redirect"
        )
        XCTAssertNotNil(ext)
    }

    func testAfterpayNotConfiguredWithoutReturnURL() {
        let ext = RoktStripePaymentExtension(applePayMerchantId: "merchant.test")!
        ext.onRegister(parameters: ["stripeKey": "pk_test_123"])

        let item = PaymentItem(id: "item-1", name: "Widget", amount: 10.00, currency: "USD")
        let context = PaymentContext(
            billingAddress: ContactAddress(name: "Test", email: "test@example.com")
        )
        let expect = expectation(description: "completion")

        ext.presentPaymentSheet(
            item: item,
            method: .afterpay,
            context: context,
            from: UIViewController(),
            preparePayment: { _, done in
                XCTFail("preparePayment should not be called when Afterpay is not configured")
                done(nil, nil)
            },
            completion: { result in
                XCTAssertEqual(result.outcome, .failed)
                XCTAssertTrue(result.errorMessage?.contains("Afterpay not configured") ?? false)
                expect.fulfill()
            }
        )

        waitForExpectations(timeout: 1)
    }

    func testHandleURLCallbackReturnsFalseForUnrelatedURL() {
        let ext = RoktStripePaymentExtension(applePayMerchantId: "merchant.test")!
        let url = URL(string: "myapp://unrelated-callback")!
        XCTAssertFalse(ext.handleURLCallback(with: url))
    }
}

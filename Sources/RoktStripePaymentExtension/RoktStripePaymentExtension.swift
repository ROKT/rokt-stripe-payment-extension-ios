import Foundation
import PassKit
import RoktContracts
import StripeApplePay
import UIKit

public class RoktStripePaymentExtension: PaymentExtension {

    // MARK: - PaymentExtension Protocol Properties

    public let id: String = "rokt-stripe-payment-extension"
    public let extensionDescription: String = "Rokt Stripe Payment Extension"
    public let supportedMethods: [String] = [
        PaymentMethodType.applePay.wireValue,
        PaymentMethodType.card.wireValue,
        PaymentMethodType.afterpay.wireValue
    ]

    // MARK: - Private Properties

    private let merchantId: String
    private let countryCode: String
    private let returnURL: String?

    private var stripeApplePayManager: StripeApplePayManager?
    private var stripeAfterpayManager: StripeAfterpayManager?

    // MARK: - Initialization

    /// Initialize RoktStripePaymentExtension with an Apple Pay merchant identifier.
    ///
    /// - Parameters:
    ///   - applePayMerchantId: Apple Pay merchant identifier (must not be empty).
    ///   - countryCode: ISO 3166-1 alpha-2 country code for the payment (default: "US").
    ///   - returnURL: Custom URL scheme for redirect-based payment methods like Afterpay
    ///     (e.g. `"myapp://stripe-redirect"`). Required for Afterpay support.
    /// - Returns: `nil` if `applePayMerchantId` is empty.
    public init?(
        applePayMerchantId: String,
        countryCode: String = "US",
        returnURL: String? = nil
    ) {
        guard !applePayMerchantId.isEmpty else { return nil }
        self.merchantId = applePayMerchantId
        self.countryCode = countryCode
        self.returnURL = returnURL
    }

    // MARK: - PaymentExtension Protocol Implementation

    @discardableResult
    public func onRegister(parameters: [String: String]) -> Bool {
        guard let stripeKey = parameters["stripeKey"], !stripeKey.isEmpty else {
            return false
        }

        let apiClient = STPAPIClient(publishableKey: stripeKey)
        stripeApplePayManager = StripeApplePayManager(
            apiClient: apiClient,
            merchantId: merchantId,
            countryCode: countryCode
        )

        if let returnURL, !returnURL.isEmpty {
            stripeAfterpayManager = StripeAfterpayManager(
                apiClient: apiClient,
                returnURL: returnURL
            )
        }

        return true
    }

    public func onUnregister() {
        stripeApplePayManager = nil
        stripeAfterpayManager = nil
    }

    public func presentPaymentSheet(
        item: PaymentItem,
        method: PaymentMethodType,
        context: PaymentContext,
        from viewController: UIViewController,
        preparePayment: @escaping (
            _ address: ContactAddress,
            _ completion: @escaping (PaymentPreparation?, Error?) -> Void
        ) -> Void,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        switch method {
        case .applePay, .card:
            guard let stripeApplePayManager else {
                completion(.failed(error: "Apple Pay not configured. Call onRegister(parameters:) with a valid stripeKey first."))
                return
            }
            stripeApplePayManager.presentPayment(
                item: item,
                from: viewController,
                preparePayment: preparePayment,
                completion: completion
            )

        case .afterpay:
            guard let stripeAfterpayManager else {
                completion(.failed(error: "Afterpay not configured. Provide a returnURL when initializing the extension."))
                return
            }
            stripeAfterpayManager.presentPayment(
                item: item,
                context: context,
                from: viewController,
                preparePayment: preparePayment,
                completion: completion
            )

        @unknown default:
            completion(.failed(error: "Unsupported payment method: \(method.wireValue)"))
        }
    }

    /// Forwards a redirect URL to Stripe so it can complete in-flight redirect-based
    /// flows (e.g. Afterpay). The Rokt SDK calls this after the host app receives a
    /// URL matching a registered extension's return URL scheme.
    public func handleURLCallback(with url: URL) -> Bool {
        StripeAPI.handleURLCallback(with: url)
    }
}

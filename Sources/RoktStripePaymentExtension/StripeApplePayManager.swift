import Foundation
import PassKit
import RoktContracts
import StripeApplePay

internal class StripeApplePayManager: NSObject {

    private let apiClient: STPAPIClient
    private let merchantId: String
    private let countryCode: String

    internal init(
        apiClient: STPAPIClient,
        merchantId: String,
        countryCode: String = "US"
    ) {
        self.apiClient = apiClient
        self.merchantId = merchantId
        self.countryCode = countryCode
    }

    internal func presentPayment(
        item: PaymentItem,
        from viewController: UIViewController,
        preparePayment: @escaping (@Sendable (ContactAddress) async throws -> PaymentPreparation),
        completion: @escaping (PaymentResult) -> Void
    ) {
        guard !item.name.isEmpty else {
            completion(.failed(error: "Payment item name cannot be empty"))
            return
        }

        guard !item.id.isEmpty else {
            completion(.failed(error: "Payment item id cannot be empty"))
            return
        }

        guard item.amount > 0 else {
            completion(.failed(error: "Payment item amount must be greater than zero"))
            return
        }

        guard !item.currency.isEmpty else {
            completion(.failed(error: "Payment item currency cannot be empty"))
            return
        }

        guard PKPaymentAuthorizationController.canMakePayments() else {
            completion(.failed(error: "Apple Pay is not available on this device"))
            return
        }

        let paymentRequest = makePaymentRequest(item: item)

        let delegate = StripeApplePayDelegate(
            apiClient: apiClient,
            item: item,
            preparePayment: preparePayment,
            completion: completion
        )

        guard let applePayContext = STPApplePayContext(
            paymentRequest: paymentRequest,
            delegate: delegate
        ) else {
            completion(.failed(error: "Failed to create Apple Pay context"))
            return
        }

        applePayContext.apiClient = apiClient

        // Retain delegate for the duration of the Apple Pay flow
        objc_setAssociatedObject(applePayContext, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

        applePayContext.presentApplePay(completion: nil)
    }

    private func makePaymentRequest(item: PaymentItem) -> PKPaymentRequest {
        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantId
        request.countryCode = countryCode
        request.currencyCode = item.currency.uppercased()
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = [.capability3DS, .capabilityCredit, .capabilityDebit]
        request.requiredShippingContactFields = [.postalAddress, .name, .phoneNumber, .emailAddress]
        request.requiredBillingContactFields = [.postalAddress, .name]
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: item.name,
                amount: NSDecimalNumber(decimal: item.amount)
            )
        ]
        return request
    }
}

// MARK: - Private delegate

private class StripeApplePayDelegate: NSObject, ApplePayContextDelegate {

    let apiClient: STPAPIClient
    let item: PaymentItem
    let preparePayment: @Sendable (ContactAddress) async throws -> PaymentPreparation
    let completion: (PaymentResult) -> Void

    private var clientSecret: String?
    private var isPaymentPrepared = false

    init(
        apiClient: STPAPIClient,
        item: PaymentItem,
        preparePayment: @escaping (@Sendable (ContactAddress) async throws -> PaymentPreparation),
        completion: @escaping (PaymentResult) -> Void
    ) {
        self.apiClient = apiClient
        self.item = item
        self.preparePayment = preparePayment
        self.completion = completion
    }

    func applePayContext(
        _ context: STPApplePayContext,
        didSelectShippingContact contact: PKContact,
        handler: @escaping (PKPaymentRequestShippingContactUpdate) -> Void
    ) {
        let address = ContactAddressMapping.map(from: contact)

        Task {
            do {
                let preparation = try await self.preparePayment(address)

                self.isPaymentPrepared = true
                self.clientSecret = preparation.clientSecret
                self.apiClient.stripeAccount = preparation.merchantId

                let updatedItems = [
                    PKPaymentSummaryItem(
                        label: "Total",
                        amount: NSDecimalNumber(decimal: self.item.amount)
                    )
                ]

                handler(PKPaymentRequestShippingContactUpdate(
                    errors: nil,
                    paymentSummaryItems: updatedItems,
                    shippingMethods: []
                ))
            } catch {
                self.isPaymentPrepared = false
                self.clientSecret = nil

                let applePayError = PKPaymentRequest.paymentShippingAddressUnserviceableError(
                    withLocalizedDescription: "Something went wrong. Please try again."
                )
                handler(PKPaymentRequestShippingContactUpdate(
                    errors: [applePayError],
                    paymentSummaryItems: [],
                    shippingMethods: []
                ))
            }
        }
    }

    func applePayContext(
        _ context: STPApplePayContext,
        didCreatePaymentMethod paymentMethod: StripeAPI.PaymentMethod,
        paymentInformation: PKPayment,
        completion: @escaping STPIntentClientSecretCompletionBlock
    ) {
        guard isPaymentPrepared, let secret = clientSecret else {
            completion(
                nil,
                NSError(
                    domain: "RoktStripePaymentExtension",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Payment must be prepared before completion"]
                )
            )
            return
        }
        completion(secret, nil)
    }

    func applePayContext(
        _ context: STPApplePayContext,
        didCompleteWith status: STPApplePayContext.PaymentStatus,
        error: Error?
    ) {
        switch status {
        case .success:
            completion(.succeeded(transactionId: clientSecret ?? "unknown"))
        case .error:
            completion(.failed(error: error?.localizedDescription ?? "Unknown error"))
        case .userCancellation:
            completion(.canceled)
        @unknown default:
            completion(.failed(error: "Unknown payment status"))
        }
    }
}

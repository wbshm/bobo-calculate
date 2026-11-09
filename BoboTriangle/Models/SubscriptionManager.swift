import Combine
import Foundation
import StoreKit

enum SubscriptionPurchaseOutcome: Equatable {
    case purchased
    case cancelled
    case pending
    case failed(String)
}

enum SubscriptionRestoreOutcome: Equatable {
    case restored
    case nothingToRestore
    case failed(String)
}

@MainActor
final class SubscriptionManager: ObservableObject {
    enum EntitlementStatus: Equatable {
        case checking
        case notSubscribed
        case subscribed
    }

    static let monthlyProductID = "bobo_monthly"

    @Published private(set) var entitlementStatus: EntitlementStatus = .checking
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var productLoadError: String?

    private var hasStarted = false
    private var transactionUpdatesTask: Task<Void, Never>?

    var isSubscribed: Bool { entitlementStatus == .subscribed }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        observeTransactionUpdates()
        await refreshEntitlement()
        await loadProduct()
    }

    func refreshEntitlement() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productID == Self.monthlyProductID,
                  transaction.revocationDate == nil else { continue }
            hasActiveSubscription = true
            break
        }

        entitlementStatus = hasActiveSubscription ? .subscribed : .notSubscribed
    }

    func loadProduct() async {
        guard monthlyProduct == nil, !isLoadingProduct else { return }
        isLoadingProduct = true
        productLoadError = nil
        defer { isLoadingProduct = false }

        do {
            monthlyProduct = try await Product.products(for: [Self.monthlyProductID]).first
            if monthlyProduct == nil {
                productLoadError = "Product \(Self.monthlyProductID) is unavailable."
            }
        } catch {
            productLoadError = error.localizedDescription
        }
    }

    func purchaseMonthlySubscription() async -> SubscriptionPurchaseOutcome {
        if monthlyProduct == nil { await loadProduct() }
        guard let monthlyProduct else {
            return .failed(productLoadError ?? "Product unavailable")
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            switch try await monthlyProduct.purchase() {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    return .failed("Transaction verification failed")
                }
                await transaction.finish()
                await refreshEntitlement()
                return isSubscribed ? .purchased : .failed("Subscription entitlement is unavailable")
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Unknown purchase result")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restorePurchases() async -> SubscriptionRestoreOutcome {
        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlement()
            return isSubscribed ? .restored : .nothingToRestore
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func observeTransactionUpdates() {
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled, let self else { return }
                guard case let .verified(transaction) = result else { continue }
                await transaction.finish()
                await self.refreshEntitlement()
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }
}

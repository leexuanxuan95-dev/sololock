import Foundation
import StoreKit

/// Pro entitlement check + paywall product loading.
/// Concrete StoreKit hookup is intentionally kept thin — the real one will
/// add receipt verification + transaction listening before submission.
@MainActor
final class SubscriptionStore: ObservableObject {

    static let monthlyID  = "com.atrium.sololock.pro.monthly"
    static let yearlyID   = "com.atrium.sololock.pro.yearly"
    static let lifetimeID = "com.atrium.sololock.pro.lifetime"

    @Published private(set) var isPro: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var loadError: String?

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = Task { await listenForTransactions() }
    }

    deinit { transactionListener?.cancel() }

    func loadProducts() async {
        do {
            let ids = [Self.monthlyID, Self.yearlyID, Self.lifetimeID]
            let fetched = try await Product.products(for: ids)
            // Sort: monthly, yearly, lifetime
            self.products = fetched.sorted { lhs, rhs in
                let order: [String: Int] = [Self.monthlyID: 0, Self.yearlyID: 1, Self.lifetimeID: 2]
                return (order[lhs.id] ?? 99) < (order[rhs.id] ?? 99)
            }
            await refreshEntitlements()
        } catch {
            self.loadError = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let txn):
                await txn.finish()
                await refreshEntitlements()
            case .unverified:
                throw NSError(domain: "SoloLock", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Could not verify purchase"])
            }
        case .userCancelled, .pending:
            return
        @unknown default:
            return
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result,
               [Self.monthlyID, Self.yearlyID, Self.lifetimeID].contains(txn.productID) {
                entitled = true
            }
        }
        self.isPro = entitled
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let txn) = result {
                await txn.finish()
                await refreshEntitlements()
            }
        }
    }
}

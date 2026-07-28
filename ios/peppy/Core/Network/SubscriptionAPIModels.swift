import Foundation

struct SubscriptionResponse: Decodable, Equatable {
    let tier: String
    let productID: String?
    let expiresAt: Date?
    let isPremium: Bool

    enum CodingKeys: String, CodingKey {
        case tier
        case productID = "product_id"
        case expiresAt = "expires_at"
        case isPremium = "is_premium"
    }

    /// The server's answer, expressed in the client's entitlement vocabulary.
    var entitlement: PremiumEntitlement {
        guard isPremium else { return .free }
        return .premium(
            plan: productID.flatMap(PremiumPlan.plan(forProductID:)),
            expires: expiresAt
        )
    }
}

struct AppleTransactionRequest: Encodable, Equatable {
    let signedTransaction: String

    enum CodingKeys: String, CodingKey {
        case signedTransaction = "signed_transaction"
    }
}

/**
 * SubscriptionManager
 * Central service for managing subscription state, entitlements, and credits.
 *
 * IMPORTANT: All entitlement checks respect the `paywallEnabled` kill switch.
 * When paywallEnabled is false, all users have unlimited access.
 */

import Foundation
import Combine
import Supabase
import Auth

// MARK: - Models

struct SubscriptionConfig: Codable {
    let paywallEnabled: Bool
    let entitlements: EntitlementConfig
    let offers: OfferConfig
    let pricing: PricingConfig
    
    struct EntitlementConfig: Codable {
        let starterRecipeCredits: Int
        let monthlyFreeCredits: Int
        let starterRemixCredits: Int
        let voicePreviewSeconds: Int
    }
    
    struct OfferConfig: Codable {
        let firstRecipeOfferEnabled: Bool
        let firstRecipeOfferDurationSeconds: Int
        let firstRecipeOfferDiscountPercent: Int
    }
    
    struct PricingConfig: Codable {
        let monthlyPrice: String
        let annualPrice: String
        let annualSavings: String
    }
    
    static let `default` = SubscriptionConfig(
        paywallEnabled: false,
        entitlements: EntitlementConfig(
            starterRecipeCredits: 5,
            monthlyFreeCredits: 3,
            starterRemixCredits: 10,
            voicePreviewSeconds: 60
        ),
        offers: OfferConfig(
            firstRecipeOfferEnabled: true,
            firstRecipeOfferDurationSeconds: 3600,
            firstRecipeOfferDiscountPercent: 50
        ),
        pricing: PricingConfig(
            monthlyPrice: "$3.99",
            annualPrice: "$21.99",
            annualSavings: "Save 45%"
        )
    )
}

struct UserEntitlements: Codable {
    let status: String
    let isPro: Bool
    let recipeCreditsUsed: Int
    let recipeCreditsRemaining: Int
    let canImportRecipe: Bool
    let voicePreviewSeconds: Int
    let canUseVoiceUnlimited: Bool
    let remixCreditsUsed: Int
    let remixCreditsRemaining: Int
    let canRemix: Bool
    let monthlyCreditsAvailable: Int
    let isFirstRecipe: Bool
    let showFirstRecipeOffer: Bool
    let monthlyCreditsAdded: Int?
    let config: SubscriptionConfig?
}

// MARK: - Models (RevenueCat)

public struct SubscriptionPackage: Identifiable {
    public let id: String
    public let storeProductIdentifier: String
    public let priceString: String
    public let period: String // "Monthly" or "Yearly"
    public let introOffer: String?
    public let packageType: PackageType
    
    // Internal RC package reference (type erased for compilation safety)
    let _rcPackage: Any?
    
    public enum PackageType {
        case monthly
        case annual
        case unknown
    }
}

// MARK: - SubscriptionManager

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published State
    @Published var config: SubscriptionConfig = .default
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // Credits
    @Published var recipeCreditsUsed: Int = 0
    @Published var remixCreditsUsed: Int = 0
    @Published var monthlyCreditsAvailable: Int = 0
    
    // First recipe offer
    @Published var showFirstRecipeOffer: Bool = false
    @Published var isFirstRecipe: Bool = true
    
    // RevenueCat State
    @Published var availablePackages: [SubscriptionPackage] = []
    
    // MARK: - Enums
    
    enum SubscriptionStatus: String {
        case free
        case pro
        case expired
    }
    
    // MARK: - Computed Properties
    
    // MARK: Alpha Testing - Add your Supabase user IDs here
    // To find your user ID: Check Supabase Dashboard -> Authentication -> Users
    private static let alphaTestUserIds: Set<String> = [
        "d58a6c92-dd6b-49a9-a04c-33102771f4ad"  // Freddy
    ]
    
    // Current user ID (set after auth)
    var currentUserId: String?
    
    /// Master kill switch - if false, everyone has unlimited access
    /// During alpha: only enables for users in alphaTestUserIds
    var isPaywallEnabled: Bool {
        guard config.paywallEnabled else { return false }
        
        // Alpha rollout: if test user list is empty, enable for everyone
        // Otherwise, only enable for users in the list
        if Self.alphaTestUserIds.isEmpty {
            return true
        }
        return currentUserId.map { Self.alphaTestUserIds.contains($0) } ?? false
    }
    
    /// Is user a Pro subscriber
    var isPro: Bool {
        guard isPaywallEnabled else { return true }
        return subscriptionStatus == .pro
    }
    
    /// Can user import a new recipe
    var canImportRecipe: Bool {
        guard isPaywallEnabled else { return true }
        return isPro || recipeCreditsRemaining > 0
    }
    
    /// Recipe credits remaining
    var recipeCreditsRemaining: Int {
        guard isPaywallEnabled else { return 999 }
        let total = config.entitlements.starterRecipeCredits + monthlyCreditsAvailable
        return max(0, total - recipeCreditsUsed)
    }
    
    /// Can user use voice companion without limits
    var canUseVoiceUnlimited: Bool {
        guard isPaywallEnabled else { return true }
        return isPro
    }
    
    /// Voice preview duration in seconds (-1 = unlimited)
    var voicePreviewSeconds: Int {
        guard isPaywallEnabled else { return -1 }
        return isPro ? -1 : config.entitlements.voicePreviewSeconds
    }
    
    /// Can user remix recipes
    var canRemix: Bool {
        guard isPaywallEnabled else { return true }
        return isPro || remixCreditsRemaining > 0
    }
    
    /// Remix credits remaining
    var remixCreditsRemaining: Int {
        guard isPaywallEnabled else { return 999 }
        return max(0, config.entitlements.starterRemixCredits - remixCreditsUsed)
    }
    
    // MARK: - User-Facing Messages
    
    /// Message to display for recipe credits (nil if plenty remaining)
    var creditsMessage: String? {
        guard isPaywallEnabled, !isPro else { return nil }
        
        switch recipeCreditsRemaining {
        case 0:
            return "Unlock unlimited recipe imports with Pro"
        case 1:
            return "1 starter credit remaining"
        case 2...3:
            return "\(recipeCreditsRemaining) starter credits remaining"
        default:
            return nil
        }
    }
    
    /// Message for remix credits
    var remixCreditsMessage: String? {
        guard isPaywallEnabled, !isPro else { return nil }
        
        switch remixCreditsRemaining {
        case 0:
            return "Unlock unlimited remixing with Pro"
        case 1...2:
            return "\(remixCreditsRemaining) remix credits left"
        default:
            return nil
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        Task {
            await loadSubscriptionStatus()
            await configureRevenueCat()
        }
    }
    
    private func configureRevenueCat() async {
        #if canImport(RevenueCat)
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "test_BddOAgtqxNNXhxQAiTlQmnXGrYl")
        
        // Identify user if logged in
        if let userId = try? await SupabaseManager.shared.client.auth.session.user.id.uuidString {
             Purchases.shared.logIn(userId) { (customerInfo, created, error) in
                 if let error = error {
                     print("RevenueCat login error: \(error)")
                 }
             }
        }
        
        await fetchOfferings()
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Load subscription status from backend
    func loadSubscriptionStatus() async {
        // Set current user ID for alpha testing
        if let userId = try? await SupabaseManager.shared.client.auth.session.user.id.uuidString {
            self.currentUserId = userId
        }
        
        guard let url = URL(string: "\(baseURL)/subscription/status") else { return }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            if let token = try? await SupabaseManager.shared.client.auth.session.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("[SubscriptionManager] Failed to load status")
                return
            }
            
            let entitlements = try JSONDecoder().decode(UserEntitlements.self, from: data)
            
            // Update state
            self.subscriptionStatus = SubscriptionStatus(rawValue: entitlements.status) ?? .free
            self.recipeCreditsUsed = entitlements.recipeCreditsUsed
            self.remixCreditsUsed = entitlements.remixCreditsUsed
            self.monthlyCreditsAvailable = entitlements.monthlyCreditsAvailable
            self.isFirstRecipe = entitlements.isFirstRecipe
            self.showFirstRecipeOffer = entitlements.showFirstRecipeOffer
            
            if let config = entitlements.config {
                self.config = config
            }
            
            // Notify user if monthly credits were just added
            if let added = entitlements.monthlyCreditsAdded, added > 0 {
                print("[SubscriptionManager] 🎉 \(added) monthly credits added!")
            }
            
        } catch {
            print("[SubscriptionManager] Error loading status: \(error)")
        }
    }
    
    /// Record that user created a recipe (increment credits used)
    func recordRecipeCreation() async {
        guard isPaywallEnabled, !isPro else { return }
        
        // Optimistic update
        recipeCreditsUsed += 1
        
        // Sync to backend
        await syncRecipeCredits()
    }
    
    /// Record that user used a remix
    func recordRemixUsage() async {
        guard isPaywallEnabled, !isPro else { return }
        
        // Optimistic update
        remixCreditsUsed += 1
        
        // Sync to backend (backend tracks this automatically via middleware)
    }
    
    /// Mark first recipe offer as shown
    func markFirstRecipeOfferShown() async {
        guard let url = URL(string: "\(baseURL)/subscription/first-recipe-offer/shown") else { return }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let token = try? await SupabaseManager.shared.client.auth.session.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let body = ["durationSeconds": config.offers.firstRecipeOfferDurationSeconds]
            request.httpBody = try JSONEncoder().encode(body)
            
            let _ = try await URLSession.shared.data(for: request)
            print("[SubscriptionManager] First recipe offer marked as shown")
        } catch {
            print("[SubscriptionManager] Error marking offer shown: \(error)")
        }
    }
    
    // MARK: - Private
    
    private var baseURL: String {
        // Use the same base URL as RecipeService
        #if DEBUG
        return "http://localhost:8080/api"
        #else
        return "https://clipcook-production.up.railway.app/api"
        #endif
    }
    
    private func syncRecipeCredits() async {
        // Backend increments credits automatically when recipe is created
        // This method is for future use if we need manual sync
    }
    
    // MARK: - RevenueCat Methods
    
    @MainActor
    func fetchOfferings() async {
        #if canImport(RevenueCat)
        do {
            let offerings = try await Purchases.shared.offerings()
            if let current = offerings.current {
                let packages = current.availablePackages.map { pkg -> SubscriptionPackage in
                    let product = pkg.storeProduct
                    let packageType: SubscriptionPackage.PackageType = pkg.packageType == .monthly ? .monthly : (pkg.packageType == .annual ? .annual : .unknown)
                    
                    return SubscriptionPackage(
                        id: pkg.identifier,
                        storeProductIdentifier: product.productIdentifier,
                        priceString: product.localizedPriceString,
                        period: pkg.packageType == .monthly ? "Monthly" : "Yearly",
                        introOffer: product.introductoryDiscount?.localizedPriceString,
                        packageType: packageType,
                        _rcPackage: pkg
                    )
                }
                self.availablePackages = packages
            }
        } catch {
            print("Error fetching offerings: \(error)")
        }
        #else
        // Mock data for development when RC SDK not present
        self.availablePackages = [
            SubscriptionPackage(id: "monthly", storeProductIdentifier: "monthly", priceString: "$3.99", period: "Monthly", introOffer: nil, packageType: .monthly, _rcPackage: nil),
            SubscriptionPackage(id: "annual", storeProductIdentifier: "yearly", priceString: "$21.99", period: "Yearly", introOffer: nil, packageType: .annual, _rcPackage: nil)
        ]
        #endif
    }
    
    @MainActor
    func purchase(package: SubscriptionPackage) async {
        isLoading = true
        defer { isLoading = false }
        
        #if canImport(RevenueCat)
        guard let rcPackage = package._rcPackage as? Package else {
            error = "Invalid package"
            return
        }
        
        do {
            let result = try await Purchases.shared.purchase(package: rcPackage)
            if !result.userCancelled {
                // Success! Force refresh status from OUR backend, as webhook should have fired
                // But give webhook a moment
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                await loadSubscriptionStatus()
            }
        } catch {
            self.error = error.localizedDescription
        }
        #else
        // Mock purchase
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        // Simulate success
        subscriptionStatus = .pro
        #endif
    }
    
    @MainActor
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        #if canImport(RevenueCat)
        do {
            let _ = try await Purchases.shared.restorePurchases()
            // Sync with our backend
             try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            await loadSubscriptionStatus()
        } catch {
            self.error = error.localizedDescription
        }
        #else
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        #endif
    }
}

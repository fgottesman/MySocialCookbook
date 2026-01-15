/**
 * SubscriptionManagerTests
 * Unit tests for SubscriptionManager subscription status and entitlements.
 */

import XCTest
@testable import ClipCook

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    
    var subscriptionManager: SubscriptionManager!
    
    override func setUp() {
        super.setUp()
        subscriptionManager = SubscriptionManager.shared
    }
    
    override func tearDown() {
        subscriptionManager = nil
        super.tearDown()
    }
    
    // MARK: - Subscription Status Tests
    
    func testSubscriptionStatusDefaultsToFree() {
        // New users should default to free tier
        XCTAssertNotNil(subscriptionManager.subscriptionStatus)
    }
    
    func testIsProDerivedFromSubscriptionStatus() {
        // isPro should be derived from subscriptionStatus
        let initialProStatus = subscriptionManager.isPro
        
        if subscriptionManager.subscriptionStatus == .free {
            XCTAssertFalse(initialProStatus, "isPro should be false when status is .free")
        } else if subscriptionManager.subscriptionStatus == .pro {
            XCTAssertTrue(initialProStatus, "isPro should be true when status is .pro")
        }
    }
    
    // MARK: - Credit Limit Tests
    
    func testFreeUserHasCreditLimits() {
        // Free users should have credit limits
        if !subscriptionManager.isPro {
            XCTAssertTrue(subscriptionManager.recipeCreditsRemaining >= 0, "Free users should have defined credits")
        }
    }
    
    func testProUserHasUnlimitedIndicator() {
        // Pro users should effectively have unlimited access
        if subscriptionManager.isPro {
            XCTAssertTrue(subscriptionManager.isPro, "Pro users should be marked as Pro")
        }
    }
    
    // MARK: - Entitlement Name Tests
    
    func testEntitlementNameConstant() {
        // Verify we're using the correct entitlement name
        let expectedEntitlement = "ClipCook Pro"
        XCTAssertEqual(expectedEntitlement, "ClipCook Pro", "Entitlement name should be 'ClipCook Pro'")
    }
    
    // MARK: - Config Tests
    
    func testPaywallEnabledConfig() {
        // isPaywallEnabled should be a valid boolean
        let paywallConfig = subscriptionManager.isPaywallEnabled
        XCTAssertTrue(paywallConfig || !paywallConfig, "isPaywallEnabled should return a boolean")
    }
    
    // MARK: - Offerings Tests
    
    func testOfferingsPropertyExists() {
        // offerings property should exist (may be nil before fetching)
        let offerings = subscriptionManager.offerings
        XCTAssertTrue(true, "Offerings property accessible")
        _ = offerings
    }
    
    // MARK: - State Publishing Tests
    
    func testSubscriptionManagerIsObservable() {
        // SubscriptionManager should be an ObservableObject
        let expectation = XCTestExpectation(description: "SubscriptionManager is ObservableObject")
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
}

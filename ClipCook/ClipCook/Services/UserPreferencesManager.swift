import Foundation
import Supabase

/// Centralized manager for user preferences
/// Handles caching, persistence, and synchronization with backend
class UserPreferencesManager: ObservableObject {
    static let shared = UserPreferencesManager()

    // MARK: - Published Properties
    @Published var unitSystem: String = "imperial"
    @Published var prepStyle: String = "just_in_time"
    @Published var defaultServings: Int = 4
    @Published var dietaryRestrictions: [String] = []
    @Published var otherPreferences: String = ""
    @Published var isLoading = false

    // MARK: - Available Dietary Restrictions
    static let availableDietaryRestrictions = [
        "Vegetarian",
        "Vegan",
        "Gluten-Free",
        "Dairy-Free",
        "Nut-Free",
        "Low-Carb"
    ]

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let unitSystem = "user_pref_unit_system"
        static let prepStyle = "user_pref_prep_style"
        static let defaultServings = "user_pref_default_servings"
        static let dietaryRestrictions = "user_pref_dietary_restrictions"
        static let otherPreferences = "user_pref_other_preferences"
        static let lastSyncedUserId = "user_pref_last_synced_user_id"
    }

    private init() {
        loadCachedPreferences()
    }

    // MARK: - Load Cached Preferences
    private func loadCachedPreferences() {
        if let cachedUnit = UserDefaults.standard.string(forKey: Keys.unitSystem) {
            unitSystem = cachedUnit
        }
        if let cachedPrep = UserDefaults.standard.string(forKey: Keys.prepStyle) {
            prepStyle = cachedPrep
        }
        let cachedServings = UserDefaults.standard.integer(forKey: Keys.defaultServings)
        if cachedServings > 0 {
            defaultServings = cachedServings
        }
        if let cachedRestrictions = UserDefaults.standard.stringArray(forKey: Keys.dietaryRestrictions) {
            dietaryRestrictions = cachedRestrictions
        }
        if let cachedOther = UserDefaults.standard.string(forKey: Keys.otherPreferences) {
            otherPreferences = cachedOther
        }
    }

    // MARK: - Cache Preferences Locally
    private func cachePreferences() {
        UserDefaults.standard.set(unitSystem, forKey: Keys.unitSystem)
        UserDefaults.standard.set(prepStyle, forKey: Keys.prepStyle)
        UserDefaults.standard.set(defaultServings, forKey: Keys.defaultServings)
        UserDefaults.standard.set(dietaryRestrictions, forKey: Keys.dietaryRestrictions)
        UserDefaults.standard.set(otherPreferences, forKey: Keys.otherPreferences)
    }

    // MARK: - Sync with Backend
    func syncPreferences() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id.uuidString

            await MainActor.run { isLoading = true }

            let prefs = try await VoiceCompanionService.shared.getPreferences(userId: userId)

            await MainActor.run {
                self.unitSystem = prefs.unitSystem
                self.prepStyle = prefs.prepStyle
                self.defaultServings = prefs.defaultServings
                self.dietaryRestrictions = prefs.dietaryRestrictions
                self.otherPreferences = prefs.otherPreferences
                self.cachePreferences()
                UserDefaults.standard.set(userId, forKey: Keys.lastSyncedUserId)
                self.isLoading = false
            }
        } catch {
            print("UserPreferencesManager: Error syncing preferences: \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - Update Unit System
    func updateUnitSystem(_ value: String) async {
        await MainActor.run {
            self.unitSystem = value
            self.cachePreferences()
        }
        await saveToBackend()
    }

    // MARK: - Update Prep Style
    func updatePrepStyle(_ value: String) async {
        await MainActor.run {
            self.prepStyle = value
            self.cachePreferences()
        }
        await saveToBackend()
    }

    // MARK: - Update Default Servings
    func updateDefaultServings(_ value: Int) async {
        await MainActor.run {
            self.defaultServings = value
            self.cachePreferences()
        }
        await saveToBackend()
    }

    // MARK: - Update Dietary Restrictions
    func updateDietaryRestrictions(_ value: [String]) async {
        await MainActor.run {
            self.dietaryRestrictions = value
            self.cachePreferences()
        }
        await saveToBackend()
    }

    // MARK: - Toggle Dietary Restriction
    func toggleDietaryRestriction(_ restriction: String) async {
        await MainActor.run {
            if dietaryRestrictions.contains(restriction) {
                dietaryRestrictions.removeAll { $0 == restriction }
            } else {
                dietaryRestrictions.append(restriction)
            }
            self.cachePreferences()
        }
        await saveToBackend()
    }

    // MARK: - Update Other Preferences
    func updateOtherPreferences(_ value: String) async {
        await MainActor.run {
            self.otherPreferences = value
            self.cachePreferences()
        }
        await saveToBackend()
    }

    // MARK: - Save to Backend
    private func saveToBackend() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id.uuidString

            let prefs = UserPreferences(
                userId: userId,
                unitSystem: unitSystem,
                prepStyle: prepStyle,
                defaultServings: defaultServings,
                dietaryRestrictions: dietaryRestrictions,
                otherPreferences: otherPreferences
            )

            _ = try await VoiceCompanionService.shared.updatePreferences(
                userId: userId,
                preferences: prefs
            )
        } catch {
            print("UserPreferencesManager: Error saving preferences: \(error)")
        }
    }

    // MARK: - Get Current Preferences (for recipe creation)
    var currentPreferences: UserPreferences {
        UserPreferences(
            userId: nil,
            unitSystem: unitSystem,
            prepStyle: prepStyle,
            defaultServings: defaultServings,
            dietaryRestrictions: dietaryRestrictions,
            otherPreferences: otherPreferences
        )
    }
}

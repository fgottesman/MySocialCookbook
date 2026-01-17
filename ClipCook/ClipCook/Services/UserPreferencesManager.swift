import Foundation
import Supabase

/// Centralized manager for user preferences
/// Handles caching, persistence, and synchronization with backend
class UserPreferencesManager: ObservableObject {
    static let shared = UserPreferencesManager()

    // MARK: - Published Properties
    @Published var unitSystem: String = "imperial"
    @Published var prepStyle: String = "just_in_time"
    @Published var isLoading = false

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let unitSystem = "user_pref_unit_system"
        static let prepStyle = "user_pref_prep_style"
        static let voiceIntroductionDelay = "user_pref_voice_intro_delay"
        static let lastSyncedUserId = "user_pref_last_synced_user_id"
    }

    // MARK: - Voice Settings (stored locally only)
    var voiceIntroductionDelay: TimeInterval {
        get {
            let value = UserDefaults.standard.double(forKey: Keys.voiceIntroductionDelay)
            // Also sync with SpeechManager
            SpeechManager.stepIntroductionDelay = value
            return value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.voiceIntroductionDelay)
            SpeechManager.stepIntroductionDelay = newValue
        }
    }

    private init() {
        // Load cached values from UserDefaults
        loadCachedPreferences()

        // Initialize SpeechManager with stored delay
        SpeechManager.stepIntroductionDelay = UserDefaults.standard.double(forKey: Keys.voiceIntroductionDelay)
    }

    // MARK: - Load Cached Preferences
    private func loadCachedPreferences() {
        if let cachedUnit = UserDefaults.standard.string(forKey: Keys.unitSystem) {
            unitSystem = cachedUnit
        }
        if let cachedPrep = UserDefaults.standard.string(forKey: Keys.prepStyle) {
            prepStyle = cachedPrep
        }
    }

    // MARK: - Cache Preferences Locally
    private func cachePreferences() {
        UserDefaults.standard.set(unitSystem, forKey: Keys.unitSystem)
        UserDefaults.standard.set(prepStyle, forKey: Keys.prepStyle)
    }

    // MARK: - Sync with Backend
    func syncPreferences() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id.uuidString

            // Check if we've already synced for this user
            let lastSyncedUserId = UserDefaults.standard.string(forKey: Keys.lastSyncedUserId)

            await MainActor.run { isLoading = true }

            let prefs = try await VoiceCompanionService.shared.getPreferences(userId: userId)

            await MainActor.run {
                self.unitSystem = prefs.unitSystem
                self.prepStyle = prefs.prepStyle
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

    // MARK: - Save to Backend
    private func saveToBackend() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id.uuidString

            let prefs = UserPreferences(
                userId: userId,
                unitSystem: unitSystem,
                prepStyle: prepStyle
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
            prepStyle: prepStyle
        )
    }
}

import SwiftUI
import Supabase

struct UserPreferencesView: View {
    @State private var preferences: UserPreferences = .default
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showSavedAlert = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            // Cooking Preferences Section
            Section {
                // Unit System Picker
                Picker("Measurement Units", selection: $preferences.unitSystem) {
                    Text("Imperial (cups, °F)").tag("imperial")
                    Text("Metric (grams, °C)").tag("metric")
                }
                .onChange(of: preferences.unitSystem) { _, _ in
                    savePreferences()
                }
                
                // Prep Style Picker
                Picker("Cooking Style", selection: $preferences.prepStyle) {
                    Text("Step by Step").tag("just_in_time")
                    Text("Prep Everything First").tag("prep_first")
                }
                .onChange(of: preferences.prepStyle) { _, _ in
                    savePreferences()
                }
            } header: {
                Label("Cooking Preferences", systemImage: "frying.pan")
            } footer: {
                Text("These preferences customize how your sous chef guides you through recipes.")
            }
            
            // Voice Settings Section
            Section {
                HStack {
                    Text("Voice Introduction Delay")
                    Spacer()
                    Text("\(Int(SpeechManager.stepIntroductionDelay * 1000))ms")
                        .foregroundColor(.clipCookTextSecondary)
                }
                
                Slider(
                    value: Binding(
                        get: { SpeechManager.stepIntroductionDelay },
                        set: { SpeechManager.stepIntroductionDelay = $0 }
                    ),
                    in: 0...1,
                    step: 0.1
                )
            } header: {
                Label("Voice Settings", systemImage: "speaker.wave.2")
            } footer: {
                Text("Adjust how quickly the sous chef starts speaking when you move to a new step.")
            }
            
            // Coming Soon Section
            Section {
                HStack {
                    Image(systemName: "heart")
                        .foregroundColor(.clipCookSecondary)
                    Text("Dietary Restrictions")
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.clipCookTextSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.clipCookSurface)
                        .cornerRadius(8)
                }
                
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.clipCookPrimary)
                    Text("Default Servings")
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.clipCookTextSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.clipCookSurface)
                        .cornerRadius(8)
                }
            } header: {
                Label("More Options", systemImage: "sparkles")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clipCookBackground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                LiquidGlassBackButton()
            }
        }
        .overlay {
            if isLoading {
                ProgressView("Loading...")
            }
        }
        .task {
            await loadPreferences()
        }
    }
    
    private func loadPreferences() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id.uuidString
            
            let loadedPrefs = try await VoiceCompanionService.shared.getPreferences(userId: userId)
            
            await MainActor.run {
                preferences = loadedPrefs
                isLoading = false
            }
        } catch {
            print("Error loading preferences: \(error)")
            isLoading = false
        }
    }
    
    private func savePreferences() {
        guard !isSaving else { return }
        isSaving = true
        
        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                let userId = session.user.id.uuidString
                
                _ = try await VoiceCompanionService.shared.updatePreferences(
                    userId: userId,
                    preferences: preferences
                )
                
                await MainActor.run {
                    isSaving = false
                }
            } catch {
                print("Error saving preferences: \(error)")
                isSaving = false
            }
        }
    }
}

#Preview {
    UserPreferencesView()
}

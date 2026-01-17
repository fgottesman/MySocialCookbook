import SwiftUI
import Supabase

struct UserPreferencesView: View {
    @StateObject private var preferencesManager = UserPreferencesManager.shared
    @State private var voiceDelay: Double = UserPreferencesManager.shared.voiceIntroductionDelay
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Cooking Preferences Section
                SettingsSection(
                    title: "Cooking Preferences",
                    icon: "frying.pan"
                ) {
                    VStack(spacing: 0) {
                        // Measurement Units
                        SettingsPickerRow(
                            title: "Measurement Units",
                            selection: Binding(
                                get: { preferencesManager.unitSystem },
                                set: { newValue in
                                    Task { await preferencesManager.updateUnitSystem(newValue) }
                                }
                            ),
                            options: [
                                ("imperial", "Imperial (cups, \u{00B0}F)"),
                                ("metric", "Metric (grams, \u{00B0}C)")
                            ]
                        )

                        Divider()
                            .background(Color.clipCookBackground)
                            .padding(.leading, 16)

                        // Cooking Style
                        SettingsPickerRow(
                            title: "Cooking Style",
                            selection: Binding(
                                get: { preferencesManager.prepStyle },
                                set: { newValue in
                                    Task { await preferencesManager.updatePrepStyle(newValue) }
                                }
                            ),
                            options: [
                                ("just_in_time", "Step by Step"),
                                ("prep_first", "Prep Everything First")
                            ]
                        )
                    }
                } footer: {
                    Text("These preferences customize how your sous chef guides you through recipes.")
                }

                // Voice Settings Section
                SettingsSection(
                    title: "Voice Settings",
                    icon: "speaker.wave.2"
                ) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Voice Introduction Delay")
                                .foregroundColor(.clipCookTextPrimary)
                            Spacer()
                            Text("\(Int(voiceDelay * 1000))ms")
                                .foregroundColor(.clipCookPrimary)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Slider(
                            value: $voiceDelay,
                            in: 0...1,
                            step: 0.1
                        )
                        .tint(.clipCookPrimary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .onChange(of: voiceDelay) { _, newValue in
                            preferencesManager.voiceIntroductionDelay = newValue
                        }
                    }
                } footer: {
                    Text("Adjust how quickly the sous chef starts speaking when you move to a new step.")
                }

                // More Options Section
                SettingsSection(
                    title: "More Options",
                    icon: "sparkles"
                ) {
                    VStack(spacing: 0) {
                        // Dietary Restrictions
                        SettingsComingSoonRow(
                            icon: "heart",
                            iconColor: .clipCookSecondary,
                            title: "Dietary Restrictions"
                        )

                        Divider()
                            .background(Color.clipCookBackground)
                            .padding(.leading, 56)

                        // Default Servings
                        SettingsComingSoonRow(
                            icon: "person.2",
                            iconColor: .clipCookPrimary,
                            title: "Default Servings"
                        )
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color.clipCookBackground.ignoresSafeArea())
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
                    .tint(.clipCookPrimary)
            }
        }
        .task {
            await loadPreferences()
        }
    }

    private func loadPreferences() async {
        await preferencesManager.syncPreferences()

        await MainActor.run {
            voiceDelay = preferencesManager.voiceIntroductionDelay
            isLoading = false
        }
    }
}

// MARK: - Settings Section Container
struct SettingsSection<Content: View, Footer: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(LinearGradient.roseGold)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(LinearGradient.roseGold)
            }
            .padding(.leading, 4)

            // Card Content
            content
                .background(Color.white)
                .cornerRadius(12)

            // Footer
            footer
                .font(.caption)
                .foregroundColor(.clipCookTextSecondary)
                .padding(.horizontal, 4)
                .padding(.top, 4)
        }
    }
}

// MARK: - Settings Picker Row
struct SettingsPickerRow: View {
    let title: String
    @Binding var selection: String
    let options: [(value: String, label: String)]

    var body: some View {
        Menu {
            ForEach(options, id: \.value) { option in
                Button {
                    selection = option.value
                } label: {
                    HStack {
                        Text(option.label)
                        if selection == option.value {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(title)
                    .foregroundColor(.black)

                Spacer()

                HStack(spacing: 4) {
                    Text(selectedLabel)
                        .foregroundColor(.clipCookPrimary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.clipCookPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }

    private var selectedLabel: String {
        options.first(where: { $0.value == selection })?.label ?? selection
    }
}

// MARK: - Settings Coming Soon Row
struct SettingsComingSoonRow: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.black)

            Spacer()

            Text("Coming Soon")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.clipCookTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.clipCookSurface)
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    NavigationStack {
        UserPreferencesView()
    }
}

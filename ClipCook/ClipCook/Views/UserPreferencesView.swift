import SwiftUI
import Supabase

struct UserPreferencesView: View {
    @StateObject private var preferencesManager = UserPreferencesManager.shared
    @State private var otherPreferencesText: String = ""
    @State private var isLoading = true
    @FocusState private var isOtherPreferencesFocused: Bool
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

                        Divider()
                            .background(Color.clipCookBackground)
                            .padding(.leading, 16)

                        // Default Servings
                        SettingsPickerRow(
                            title: "Default Servings",
                            selection: Binding(
                                get: { String(preferencesManager.defaultServings) },
                                set: { newValue in
                                    if let intValue = Int(newValue) {
                                        Task { await preferencesManager.updateDefaultServings(intValue) }
                                    }
                                }
                            ),
                            options: (1...12).map { ("\($0)", "\($0) \($0 == 1 ? "serving" : "servings")") }
                        )
                    }
                } footer: {
                    Text("These preferences customize how recipes are generated for you.")
                }

                // Dietary Restrictions Section
                SettingsSection(
                    title: "Dietary Restrictions",
                    icon: "heart"
                ) {
                    VStack(spacing: 0) {
                        ForEach(Array(UserPreferencesManager.availableDietaryRestrictions.enumerated()), id: \.element) { index, restriction in
                            DietaryRestrictionRow(
                                title: restriction,
                                isSelected: preferencesManager.dietaryRestrictions.contains(restriction),
                                onToggle: {
                                    Task { await preferencesManager.toggleDietaryRestriction(restriction) }
                                }
                            )

                            if index < UserPreferencesManager.availableDietaryRestrictions.count - 1 {
                                Divider()
                                    .background(Color.clipCookBackground)
                                    .padding(.leading, 52)
                            }
                        }
                    }
                } footer: {
                    Text("Recipes will be adapted to meet these dietary requirements.")
                }

                // Other Preferences Section
                SettingsSection(
                    title: "Other Preferences",
                    icon: "sparkles"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tell us about any other dietary needs or cooking preferences")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        TextEditor(text: $otherPreferencesText)
                            .frame(minHeight: 80, maxHeight: 120)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .scrollContentBackground(.hidden)
                            .background(Color.clipCookBackground.opacity(0.5))
                            .cornerRadius(8)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                            .focused($isOtherPreferencesFocused)
                            .onChange(of: otherPreferencesText) { _, newValue in
                                // Debounce the save
                                Task {
                                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
                                    if otherPreferencesText == newValue {
                                        await preferencesManager.updateOtherPreferences(newValue)
                                    }
                                }
                            }
                    }
                } footer: {
                    Text("e.g., \"No cilantro, prefer less spicy food, allergic to shellfish\"")
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
            ToolbarItem(placement: .keyboard) {
                Button("Done") {
                    isOtherPreferencesFocused = false
                }
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
            otherPreferencesText = preferencesManager.otherPreferences
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

// MARK: - Dietary Restriction Row
struct DietaryRestrictionRow: View {
    let title: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .clipCookPrimary : .gray.opacity(0.4))

                Text(title)
                    .foregroundColor(.black)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        UserPreferencesView()
    }
}

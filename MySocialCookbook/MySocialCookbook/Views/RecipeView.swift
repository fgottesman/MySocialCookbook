import SwiftUI
import AVKit

struct RecipeView: View {
    // We use State to allow the recipe to be modified by the Remix engine
    @State private var recipe: Recipe
    
    // State for interactive checklists
    @State private var checkedIngredients: Set<String> = []
    
    // State for Remix
    @State private var showingRemix = false
    @State private var remixPrompt = ""
    @State private var isRemixing = false
    @State private var showingVoiceCompanion = false
    
    init(recipe: Recipe) {
        _recipe = State(initialValue: recipe)
    }
    
    var body: some View {
        ZStack {
            Color.clipCookBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: - Source Card Header
                    SourceCardHeader(recipe: recipe)
                    
                    // MARK: - Title
                    Text(recipe.title)
                        .modifier(UtilityHeadline())
                        .padding(.horizontal)
                    
                    // MARK: - Chef's Note (Only if Remixed)
                    if let note = recipe.chefsNote {
                        HStack(alignment: .top) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(LinearGradient.sizzle)
                            VStack(alignment: .leading) {
                                Text("Chef's Note")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(LinearGradient.sizzle)
                                Text(note)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .italic()
                            }
                        }
                        .padding()
                        .background(Color.clipCookSurface)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Ingredients Checklist
                    if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Ingredients")
                                .font(.headline)
                                .foregroundColor(.clipCookAccent)
                            
                            VStack(spacing: 12) {
                                ForEach(ingredients, id: \.self) { ingredient in
                                    IngredientRow(
                                        ingredient: ingredient,
                                        isChecked: checkedIngredients.contains(ingredient.name)
                                    ) {
                                        toggleIngredient(ingredient.name)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider().background(Color.clipCookSurface)
                    
                    // MARK: - Instructions Steps
                    if let instructions = recipe.instructions, !instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Instructions")
                                .font(.headline)
                                .foregroundColor(.clipCookAccent)
                            
                            ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
                                StepCard(index: index + 1, text: step)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Bottom padding for Float Button
                    Color.clear.frame(height: 100)
                }
                .padding(.top)
            }
            
            // MARK: - Floating Action Buttons
            VStack {
                Spacer()
                HStack(spacing: 20) {
                    // Remix Button
                    Button(action: { showingRemix = true }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Remix")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .background(Color.clipCookSurface)
                        .foregroundColor(.clipCookSizzleStart)
                        .cornerRadius(30)
                        .shadow(radius: 10)
                    }
                    
                    // Start Cooking (Voice) Button
                    Button(action: { showingVoiceCompanion = true }) {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("Start Cooking")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .padding(.horizontal, 4)
                        .background(LinearGradient.sizzle)
                        .foregroundColor(.white)
                        .cornerRadius(30)
                        .shadow(radius: 10)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingRemix) {
            RemixSheet(prompt: $remixPrompt, isRemixing: $isRemixing) {
                performRemix()
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showingVoiceCompanion) {
            VoiceCompanionView(recipe: recipe)
        }
    }
    
    private func toggleIngredient(_ name: String) {
        if checkedIngredients.contains(name) {
            checkedIngredients.remove(name)
        } else {
            checkedIngredients.insert(name)
        }
    }
    
    private func performRemix() {
        guard !remixPrompt.isEmpty else { return }
        isRemixing = true
        
        Task {
            do {
                let newRecipe = try await RemixService.shared.remixRecipe(originalRecipe: recipe, prompt: remixPrompt)
                await MainActor.run {
                    self.recipe = newRecipe
                    self.remixPrompt = "" // Clear prompt
                    self.showingRemix = false // Dismiss sheet
                    self.isRemixing = false
                    // Reset checked state as ingredients changed
                    self.checkedIngredients.removeAll()
                }
            } catch {
                print("Remix error: \(error)")
                await MainActor.run {
                    isRemixing = false
                    // Ideally show error toast
                }
            }
        }
    }
}

// MARK: - NEW SUBVIEWS

struct RemixSheet: View {
    @Binding var prompt: String
    @Binding var isRemixing: Bool
    let onRemix: () -> Void
    
    var body: some View {
        ZStack {
            Color.clipCookBackground.ignoresSafeArea()
            
            if isRemixing {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .clipCookAccent))
                        .scaleEffect(2)
                    Text("Asking the Chef...")
                        .modifier(UtilityHeadline())
                    Text("Rewriting ingredients and steps...")
                        .modifier(UtilitySubhead())
                }
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    Text("AI Remix")
                        .modifier(UtilityHeadline())
                    
                    Text("Tell the chef how to change this recipe.")
                        .modifier(UtilitySubhead())
                    
                    TextField("Make it vegan, spicy, etc...", text: $prompt, axis: .vertical)
                        .padding()
                        .background(Color.clipCookSurface)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .lineLimit(3...6)
                    
                    Button(action: onRemix) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Remix It")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(prompt.isEmpty ? Color.gray : Color.clipCookAccent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(prompt.isEmpty)
                    
                    Spacer()
                }
                .padding(24)
            }
        }
    }
}

// MARK: - Subviews

struct SourceCardHeader: View {
    let recipe: Recipe
    
    var body: some View {
        HStack {
            // Placeholder Thumbnail
            Rectangle()
                .fill(Color.clipCookSurface)
                .frame(width: 60, height: 80)
                .cornerRadius(8)
                .overlay(Image(systemName: "play.circle").foregroundColor(.white))
            
            VStack(alignment: .leading) {
                Text("Original via TikTok")
                    .font(.caption)
                    .foregroundColor(.clipCookTextSecondary)
                
                if let profile = recipe.profile {
                    Text(profile.username ?? "Unknown Chef")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                // Deep Link Button
                Link(destination: URL(string: recipe.videoUrl ?? "https://tiktok.com")!) {
                    Text("Open Original")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.clipCookSizzleStart)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.clipCookSurface.opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct IngredientRow: View {
    let ingredient: Ingredient
    let isChecked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .clipCookSuccess : .clipCookTextSecondary)
                    .font(.title3)
                
                Text("\(ingredient.amount) \(ingredient.unit) \(ingredient.name)")
                    .font(.body)
                    .foregroundColor(isChecked ? .clipCookTextSecondary : .clipCookTextPrimary)
                    .strikethrough(isChecked)
                
                Spacer()
            }
            .padding()
            .background(Color.clipCookSurface)
            .cornerRadius(8)
        }
    }
}

struct StepCard: View {
    let index: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(index)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.gray.opacity(0.3))
            
            Text(text)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.clipCookTextPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clipCookSurface)
        .cornerRadius(12)
    }
}

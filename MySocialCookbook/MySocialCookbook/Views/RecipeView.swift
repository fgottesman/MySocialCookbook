import SwiftUI
import AVKit

struct RecipeView: View {
    let recipe: Recipe
    
    // State for interactive checklists
    @State private var checkedIngredients: Set<String> = []
    
    // State for Remix / Help
    @State private var showingRemix = false
    
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
                    Color.clear.frame(height: 80)
                }
                .padding(.top)
            }
        }
    }
    
    private func toggleIngredient(_ name: String) {
        if checkedIngredients.contains(name) {
            checkedIngredients.remove(name)
        } else {
            checkedIngredients.insert(name)
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

import SwiftUI

    @StateObject private var apiService = APIService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(apiService.recipes) { recipe in
                        NavigationLink(destination: RecipeView(recipe: recipe)) {
                            RecipeCard(recipe: recipe)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("My Social Cookbook")
            .onAppear {
                apiService.fetchRecipes()
            }
        }
    }
    
    // Removed local loadRecipes function as we use apiService now
}

struct RecipeCard: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(9/16, contentMode: .fit)
                .cornerRadius(12)
                .overlay(Text("Video").foregroundColor(.gray))
            
            Text(recipe.title ?? "Untitled Recipe")
                .font(.headline)
                .lineLimit(1)
            
            Text(recipe.creatorHandle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

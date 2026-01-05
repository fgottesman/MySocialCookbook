import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.recipes.isEmpty {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text("Error loading recipes")
                        Text(error).font(.caption).foregroundColor(.red)
                        Button("Retry") {
                            Task { await viewModel.fetchRecipes() }
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(viewModel.recipes) { recipe in
                                NavigationLink(destination: RecipeView(recipe: recipe)) {
                                    RecipeCard(recipe: recipe)
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.fetchRecipes()
                    }
                }
            }
            .navigationTitle("My Social Cookbook")
            .task {
                await viewModel.fetchRecipes()
            }
        }
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading) {
            // Video Thumbnail Placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(9/16, contentMode: .fit)
                .cornerRadius(12)
                .overlay(
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.white)
                        .font(.largeTitle)
                )
            
            Text(recipe.title)
                .font(.headline)
                .lineLimit(1)
                .foregroundColor(.primary)
            
            if let profile = recipe.profile {
                Text(profile.username ?? profile.fullName ?? "Unknown Chef")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

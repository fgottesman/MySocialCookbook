import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.clipCookBackground.ignoresSafeArea()
                
                Group {
                    if viewModel.isLoading && viewModel.recipes.isEmpty {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .clipCookSizzleStart))
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.clipCookSizzleEnd)
                            Text("Kitchen Error")
                                .modifier(UtilityHeadline())
                            Text(error)
                                .modifier(UtilitySubhead())
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task { await viewModel.fetchRecipes() }
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.clipCookSurface)
                            .cornerRadius(8)
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ClipCook")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient.sizzle)
                }
            }
            .task {
                await viewModel.fetchRecipes()
            }
        }
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Video Thumbnail
            ZStack {
                Rectangle()
                    .fill(Color.clipCookBackground)
                    .aspectRatio(9/16, contentMode: .fit)
                    .cornerRadius(12)
                
                if let thumbnailUrl = recipe.thumbnailUrl, let url = URL(string: thumbnailUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(9/16, contentMode: .fit)
                    .cornerRadius(12)
                    .clipped()
                } else {
                    // Fallback Placeholder
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(LinearGradient.sizzle)
                        .font(.largeTitle)
                }
            }
            .overlay(
                // Play icon overlay for video indication
                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
                    .padding(8),
                alignment: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline)
                    .foregroundColor(.clipCookTextPrimary)
                    .fixedSize(horizontal: false, vertical: true) // Allow full expansion
                    .multilineTextAlignment(.leading)
                
                if let profile = recipe.profile {
                    Text(profile.username ?? profile.fullName ?? "Unknown Chef")
                        .font(.caption)
                        .foregroundColor(.clipCookTextSecondary)
                }
            }
        }
        .padding(12)
        .background(Color.clipCookSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

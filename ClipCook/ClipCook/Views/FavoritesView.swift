import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        } else {
            return [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.clipCookBackground.ignoresSafeArea()
                
                Group {
                    if viewModel.isLoading && viewModel.favorites.isEmpty {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .clipCookPrimary))
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.clipCookSecondary)
                            Text("Kitchen Error")
                                .modifier(UtilityHeadline())
                            Text(error)
                                .modifier(UtilitySubhead())
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task { await viewModel.fetchFavorites() }
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.clipCookSurface)
                            .cornerRadius(8)
                        }
                    } else if viewModel.favorites.isEmpty {
                        EmptyFavoritesView()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(viewModel.favorites) { recipe in
                                    NavigationLink(destination: RecipeView(recipe: recipe)) {
                                        RecipeCard(recipe: recipe)
                                    }
                                }
                            }
                            .padding()
                        }
                        .refreshable {
                            await viewModel.fetchFavorites()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Favorites")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient.roseGold)
                }
            }
            .task {
                await viewModel.fetchFavorites()
            }
        }
    }
}

struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundStyle(LinearGradient.roseGold)
            
            Text("No Favorites Yet")
                .font(.title2.bold())
                .foregroundColor(.clipCookTextPrimary)
            
            Text("Star your favorite recipes to find them here")
                .font(.body)
                .foregroundColor(.clipCookTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

#Preview {
    FavoritesView()
}

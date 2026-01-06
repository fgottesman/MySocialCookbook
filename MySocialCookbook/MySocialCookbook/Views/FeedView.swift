import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var isSearching = false
    @State private var showingAddRecipe = false
    
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
                            Image(systemName: "flame")
                                .font(.largeTitle)
                                .foregroundColor(.clipCookSizzleEnd)
                            Text("The stove's not lighting")
                                .modifier(UtilityHeadline())
                            Text("Let's try again! 🧊")
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
                    } else if viewModel.recipes.isEmpty {
                        NUXView(showingAddRecipe: $showingAddRecipe)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(viewModel.filteredRecipes) { recipe in
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
                    if isSearching {
                        SearchBar(text: $viewModel.searchQuery, onCancel: {
                            withAnimation {
                                isSearching = false
                                viewModel.searchQuery = ""
                            }
                        })
                        .transition(.opacity)
                    } else {
                        Text("ClipCook")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient.sizzle)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isSearching {
                        Button {
                            showingAddRecipe = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(LinearGradient.sizzle)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation {
                            isSearching.toggle()
                            if !isSearching {
                                viewModel.searchQuery = ""
                            }
                        }
                    } label: {
                        Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                            .foregroundStyle(LinearGradient.sizzle)
                    }
                }
            }
            .task {
                await viewModel.fetchRecipes()
            }
            .sheet(isPresented: $showingAddRecipe) {
                AddRecipeView()
                    .onDisappear {
                        Task { await viewModel.fetchRecipes() }
                    }
            }
        }
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Video Thumbnail
            // Video Thumbnail
            Color.clear
                .aspectRatio(9/16, contentMode: .fit)
                .background(Color.clipCookBackground)
                .cornerRadius(12)
                .overlay(
                    Group {
                        if let thumbnailUrl = recipe.thumbnailUrl, let url = URL(string: thumbnailUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                        } else {
                            // Fallback Placeholder for recipes without video
                            ZStack {
                                LinearGradient.sizzle.opacity(0.1)
                                VStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.largeTitle)
                                        .foregroundStyle(LinearGradient.sizzle)
                                    Text("AI Recipe")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.clipCookSizzleStart)
                                }
                            }
                        }
                    }
                )
                .clipped()
                .cornerRadius(12)
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
            .opacity(recipe.videoUrl == nil ? 0 : 1) // Only show play icon if video exists
            
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
        .shadow(color: Color.clipCookSizzleStart.opacity(0.1), radius: 10, x: 0, y: 0) // Very subtle glow
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onCancel: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.clipCookTextSecondary)
                .font(.system(size: 16))
            
            TextField("Search recipes...", text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(.clipCookTextPrimary)
                .focused($isFocused)
                .autocorrectionDisabled()
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.clipCookTextSecondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.clipCookSurface)
        .cornerRadius(10)
        .onAppear {
            isFocused = true
        }
    }
}

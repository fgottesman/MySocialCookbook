import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var isSearching = false
    @State private var showingAddRecipe = false
    @Environment(\.scenePhase) private var scenePhase
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
                DesignTokens.Colors.background.ignoresSafeArea()
                
                Group {
                    if viewModel.isLoading && viewModel.recipes.isEmpty {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.primary))
                    } else if viewModel.errorMessage != nil && viewModel.recipes.isEmpty {
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
                                Task { await viewModel.fetchRecipes(isUserInitiated: true) }
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
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(viewModel.filteredRecipes) { recipe in
                                    NavigationLink(destination: RecipeView(recipe: recipe)) {
                                        RecipeCard(recipe: recipe)
                                    }
                                    .buttonStyle(PremiumButtonStyle())
                                }
                            }
                            .padding()
                        }
                        .refreshable {
                            await viewModel.fetchRecipes(isUserInitiated: true)
                        }
                    }
                }
                
                if let toastMessage = viewModel.toastMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            if toastMessage.contains("cooking") {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.white)
                            }
                            
                            Text(toastMessage)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.clipCookSurface.opacity(0.95))
                        .cornerRadius(30)
                        .shadow(radius: 10)
                        .padding(.bottom, 20)
                        .padding(.horizontal)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                viewModel.toastMessage = nil
                            }
                        }
                    }
                    .zIndex(100)
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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await viewModel.fetchRecipes()
                    }
                }
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
                .background(DesignTokens.Colors.background)
                .cornerRadius(DesignTokens.Layout.cornerRadius / 2)
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
                    .font(DesignTokens.Typography.headerFont(size: 18))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .premiumText()
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    if recipe.isAIRecipe {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(LinearGradient.sizzle)
                        Text("AI Creation")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(LinearGradient.sizzle)
                        
                        if let profile = recipe.profile {
                            Text("by \(profile.username ?? "You")")
                                .font(.caption)
                                .foregroundColor(.clipCookTextSecondary)
                        }
                    } else {
                        if let profile = recipe.profile {
                            Text(profile.username ?? profile.fullName ?? "Unknown Chef")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.clipCookTextSecondary)
                        }
                        
                        Text("on \(recipe.sourcePlatform)")
                            .font(.caption)
                            .foregroundColor(.clipCookTextSecondary)
                    }
                }
            }
        }
        .padding(DesignTokens.Layout.cardPadding)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.Layout.cornerRadius)
        .shadow(color: DesignTokens.Colors.primary.opacity(0.1), radius: 10)
        .shadow(color: DesignTokens.Effects.softShadowColor, radius: DesignTokens.Effects.softShadowRadius, y: 4)
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

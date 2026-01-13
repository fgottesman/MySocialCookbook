import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var isSearching = false
    @State private var showingAddRecipe = false
    @State private var isProcessingRecipe = false
    @State private var isTakingLonger = false
    @State private var recipeCountBeforeProcessing = 0
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
                                // Show loading card at top when processing
                                if isProcessingRecipe {
                                    LoadingRecipeCard(isTakingLonger: isTakingLonger) {
                                        withAnimation {
                                            isProcessingRecipe = false
                                            isTakingLonger = false
                                        }
                                    }
                                        .transition(.opacity)
                                }
                                
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
                AddRecipeView(
                    onProcessingStarted: {
                        recipeCountBeforeProcessing = viewModel.recipes.count
                        isProcessingRecipe = true
                        
                        // Start timeout timer - show "Taking longer..." after 60 seconds
                        Task {
                            try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                            await MainActor.run {
                                if isProcessingRecipe {
                                    withAnimation {
                                        isTakingLonger = true
                                    }
                                }
                            }
                        }
                    },
                    onProcessingFailed: { errorMessage in
                        withAnimation {
                            isProcessingRecipe = false
                        }
                        viewModel.toastMessage = errorMessage
                    }
                )
                .onDisappear {
                    Task {
                        await viewModel.fetchRecipes()
                    }
                }
            }
            .onChange(of: viewModel.recipes.count) { oldCount, newCount in
                // Hide loading card when new recipe appears
                if isProcessingRecipe && newCount > recipeCountBeforeProcessing {
                    withAnimation {
                        isProcessingRecipe = false
                        isTakingLonger = false
                    }
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
                                    Image(systemName: recipe.isAIRecipe ? "sparkles" : "fork.knife")
                                        .font(.largeTitle)
                                        .foregroundStyle(LinearGradient.sizzle)
                                    Text(recipe.isAIRecipe ? "AI Recipe" : "ClipCook")
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
            .overlay(
                // "New" Badge for recipes < 24 hours old
                Group {
                    if Calendar.current.dateComponents([.hour], from: recipe.createdAt, to: Date()).hour ?? 25 < 24 {
                        Text("NEW")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(LinearGradient.sizzle)
                            .cornerRadius(4)
                            .padding(8)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                },
                alignment: .topLeading
            )
            
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
                    } else {
                        // Show creator name if available, otherwise just show platform
                        // Show creator name if available, otherwise just show platform
                        if let handle = recipe.creatorUsername, !handle.isEmpty {
                            Text(handle.hasPrefix("@") ? handle : "@\(handle)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.clipCookTextSecondary)
                        } else if let profile = recipe.profile, let username = profile.username, !username.isEmpty {
                            Text(username.hasPrefix("@") ? username : "@\(username)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.clipCookTextSecondary)
                        } else if let name = recipe.displayCreatorName, !name.isEmpty {
                            Text(name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.clipCookTextSecondary)
                        }
                        
                        Text("via \(recipe.sourcePlatform)")
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

/// Loading placeholder card shown when a recipe is being processed
struct LoadingRecipeCard: View {
    @State private var shimmerOffset: CGFloat = -1.0
    var isTakingLonger: Bool = false
    var onDismiss: () -> Void = {}
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Shimmer thumbnail placeholder
            Color.clear
                .aspectRatio(9/16, contentMode: .fit)
                .background(
                    ZStack {
                        DesignTokens.Colors.background
                        
                        // Shimmer effect
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .offset(x: shimmerOffset * 200)
                    }
                )
                .cornerRadius(12)
                .overlay(
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.primary))
                            .scaleEffect(1.2)
                        
                        Text(isTakingLonger ? "Taking longer than expected..." : "Cooking...")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(LinearGradient.sizzle)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if isTakingLonger {
                            Button(action: onDismiss) {
                                Text("Dismiss")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(LinearGradient.sizzle)
                                    .cornerRadius(12)
                            }
                        }
                    }
                )
            
            // Title placeholder
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignTokens.Colors.background)
                    .frame(height: 18)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .offset(x: shimmerOffset * 200)
                    )
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignTokens.Colors.background)
                    .frame(width: 100, height: 12)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .offset(x: shimmerOffset * 200)
                    )
            }
        }
        .padding(DesignTokens.Layout.cardPadding)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.Layout.cornerRadius)
        .shadow(color: DesignTokens.Colors.primary.opacity(0.1), radius: 10)
        .shadow(color: DesignTokens.Effects.softShadowColor, radius: DesignTokens.Effects.softShadowRadius, y: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.0
            }
        }
    }
}

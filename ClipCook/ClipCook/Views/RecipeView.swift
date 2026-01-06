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
    @State private var originalRecipe: Recipe? // Store original for revert
    
    // State for Favorite/Delete
    // State for Favorite/Delete
    @State private var isFavorite: Bool
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    // State for Share
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isSavingRemix = false
    
    init(recipe: Recipe) {
        _recipe = State(initialValue: recipe)
        _isFavorite = State(initialValue: recipe.isFavorite ?? false)
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
                    
                    // MARK: - Revert Button (Only if Remixed)
                    if originalRecipe != nil {
                        Button(action: revertRecipe) {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.uturn.backward")
                                Text("Revert to Original")
                            }
                            .foregroundColor(.clipCookTextSecondary)
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Ingredients Checklist
                    if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Ingredients")
                                .font(.headline)
                                .foregroundColor(.clipCookSizzleStart)
                            
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
                                .foregroundColor(.clipCookSizzleStart)
                            
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
            
            // MARK: - Top-Right Action Buttons
            VStack {
                HStack {
                    Spacer()
                    // More Menu
                    Menu {
                        Section {
                            Button(action: shareLink) {
                                Label("Share Link", systemImage: "link")
                            }
                            Button(action: copyIngredientsAndSteps) {
                                Label("Copy Recipe", systemImage: "doc.on.doc")
                            }
                        }
                        
                        Divider()
                        
                        Section {
                            Button(action: toggleFavorite) {
                                Label(isFavorite ? "Unfavorite" : "Favorite", systemImage: isFavorite ? "star.fill" : "star")
                            }
                            
                            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 32))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
            
            // Loading Overlay for Remix Save
            if isSavingRemix {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView("Saving Remix...")
                    .padding()
                    .background(Color.clipCookSurface)
                    .cornerRadius(12)
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
        .confirmationDialog("Delete Recipe?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteRecipe()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This recipe will be permanently deleted. This action cannot be undone.")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
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
        
        let currentRecipe = recipe
        
        Task {
            do {
                let remixedPart = try await RemixService.shared.remixRecipe(originalRecipe: currentRecipe, prompt: remixPrompt)
                
                await MainActor.run {
                    // Save original if not already saved
                    if self.originalRecipe == nil {
                        self.originalRecipe = currentRecipe
                    }
                    
                    // Merge new data with existing recipe
                    // We keep ID, UserId, VideoUrl, etc. from the original
                    // We update Title, Description, Ingredients, Instructions, ChefsNote from Remix
                    let newRecipe = Recipe(
                        id: currentRecipe.id,
                        userId: currentRecipe.userId,
                        title: remixedPart.title ?? currentRecipe.title,
                        description: remixedPart.description ?? currentRecipe.description,
                        videoUrl: currentRecipe.videoUrl,
                        thumbnailUrl: currentRecipe.thumbnailUrl,
                        ingredients: remixedPart.ingredients ?? currentRecipe.ingredients,
                        instructions: remixedPart.instructions ?? currentRecipe.instructions,
                        createdAt: currentRecipe.createdAt,
                        chefsNote: remixedPart.chefsNote,
                        profile: currentRecipe.profile,
                        isFavorite: currentRecipe.isFavorite
                    )
                    
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
    
    private func revertRecipe() {
        if let original = originalRecipe {
            withAnimation {
                self.recipe = original
                self.originalRecipe = nil
                self.checkedIngredients.removeAll()
            }
        }
    }
    
    private func toggleFavorite() {
        isFavorite.toggle()
        
        Task {
            do {
                try await RecipeService.shared.toggleFavorite(
                    recipeId: recipe.id,
                    isFavorite: isFavorite
                )
            } catch {
                // Revert on error
                await MainActor.run {
                    isFavorite.toggle()
                }
                print("Error toggling favorite: \(error)")
            }
        }
    }
    
    private func deleteRecipe() {
        Task {
            do {
                try await RecipeService.shared.deleteRecipe(recipeId: recipe.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error deleting recipe: \(error)")
                // Could show error toast here
            }
        }
    }
    
    private func shareLink() {
        Task {
            // Check if it's an unsaved remix (exists locally but ID is reused for display)
            // Ideally we should track "isUnsavedRemix", but checking if originalRecipe != nil is a good proxy in this specific view logic
            if let original = originalRecipe {
                // It is a remix, save it first
                await MainActor.run { isSavingRemix = true }
                do {
                    let savedRecipe = try await RecipeService.shared.saveRemixedRecipe(recipe, originalId: original.id)
                    await MainActor.run {
                        self.recipe = savedRecipe
                        self.originalRecipe = nil // No longer transient
                        self.isSavingRemix = false
                        
                        // Now share the new link
                        let link = URL(string: "https://clipcook.app/recipe/\(savedRecipe.id)")!
                        self.shareItems = [link]
                        self.showingShareSheet = true
                    }
                } catch {
                    print("Error saving remix: \(error)")
                    await MainActor.run { isSavingRemix = false }
                }
            } else {
                // Standard recipe
                if let link = URL(string: "https://clipcook.app/recipe/\(recipe.id)") {
                    self.shareItems = [link]
                    self.showingShareSheet = true
                }
            }
        }
    }
    
    private func copyIngredientsAndSteps() {
        var text = "\(recipe.title)\n\n"
        if let desc = recipe.description {
            text += "\(desc)\n\n"
        }
        
        if let ingredients = recipe.ingredients {
            text += "Ingredients:\n"
            for ing in ingredients {
                text += "• \(ing.amount) \(ing.unit) \(ing.name)\n"
            }
            text += "\n"
        }
        
        if let instructions = recipe.instructions {
            text += "Instructions:\n"
            for (index, step) in instructions.enumerated() {
                text += "\(index + 1). \(step)\n"
            }
            text += "\n"
        }
        
        text += "Sent from ClipCook"
        
        shareItems = [text]
        showingShareSheet = true
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
                        .progressViewStyle(CircularProgressViewStyle(tint: .clipCookSizzleStart))
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
                        .background(prompt.isEmpty ? Color.gray : Color.clipCookSizzleStart)
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
            // Video Thumbnail
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
                    // Fallback Placeholder
                    ZStack {
                        Color.clipCookSurface
                        Image(systemName: "sparkles")
                            .foregroundColor(.clipCookSizzleStart)
                    }
                }
            }
            .frame(width: 60, height: 80)
            .cornerRadius(8)
            .clipped()
            
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
                if let videoUrl = recipe.videoUrl, let _ = URL(string: videoUrl) {
                    Link(destination: URL(string: videoUrl)!) {
                        Text("Open Original")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.clipCookSizzleStart)
                    }
                } else {
                    Text("AI Crafted")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.clipCookTextSecondary)
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

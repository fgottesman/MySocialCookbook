import SwiftUI
import AVKit
import UIKit

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
    
    // Version history - stores all versions including original
    @State private var recipeVersions: [RecipeVersion] = []
    @State private var currentVersionIndex: Int = 0
    @State private var changedIngredients: Set<String> = [] // Track remixed ingredients
    
    // State for Favorite/Delete
    // State for Favorite/Delete
    @State private var isFavorite: Bool
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    // State for Share
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isSavingRemix = false
    @State private var hasPendingRemixSave = false  // Track if a remix version is being saved to DB
    
    // State for Measurement Conversion
    @State private var measurementSystem: MeasurementSystem = .us
    
    // Toast for pending save warning
    @State private var showRemixSaveToast = false
    
    /// Original recipe for detecting if in remix mode
    private var originalRecipe: Recipe? {
        guard recipeVersions.count > 1 else { return nil }
        return recipeVersions.first?.recipe
    }
    
    init(recipe: Recipe, savedVersions: [RecipeVersion] = []) {
        _recipe = State(initialValue: recipe)
        _isFavorite = State(initialValue: recipe.isFavorite ?? false)
        // Initialize with passed versions or just the current recipe
        if savedVersions.isEmpty {
            _recipeVersions = State(initialValue: [RecipeVersion(title: "Original", recipe: recipe)])
        } else {
            _recipeVersions = State(initialValue: savedVersions)
            _currentVersionIndex = State(initialValue: savedVersions.count - 1)
        }
    }
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        ZStack {
            DesignTokens.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: - Source Card Header
                    SourceCardHeader(recipe: recipe)
                    
                    // MARK: - Metrics (AI Generated)
                    if let difficulty = recipe.difficulty, let time = recipe.cookingTime {
                        HStack(spacing: 16) {
                            Label(difficulty, systemImage: "chart.bar.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(LinearGradient.sizzle)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.clipCookSurface)
                                .cornerRadius(8)
                            
                            Label(time, systemImage: "clock.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(LinearGradient.sizzle)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.clipCookSurface)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Title
                    Text(recipe.title)
                        .font(DesignTokens.Typography.headerFont(size: 28))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .premiumText()
                        .padding(.horizontal)
                    
                    // MARK: - Chef's Note (Only if Remixed)
                    if let note = recipe.chefsNote {
                        HStack(alignment: .top) {
                            Image(systemName: "sparkles")
                            .foregroundStyle(LinearGradient.sizzle)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Chef's Note")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(LinearGradient.sizzle)
                                
                                Text(note)
                                    .font(DesignTokens.Typography.bodyFont())
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                    .italic()
                                    .premiumText()
                            }
                        }
                        .padding()
                        .background(DesignTokens.Colors.surface)
                        .cornerRadius(DesignTokens.Layout.cornerRadius)
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Version History (Only if Remixed)
                    if recipeVersions.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Versions")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.clipCookTextSecondary)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(recipeVersions.enumerated()), id: \.element.id) { index, version in
                                        Button(action: { selectVersion(at: index) }) {
                                            HStack(spacing: 4) {
                                                if index == 0 {
                                                    Image(systemName: "arrow.uturn.backward")
                                                        .font(.caption2)
                                                }
                                                Text(version.title)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .lineLimit(1)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                currentVersionIndex == index
                                                    ? AnyView(LinearGradient.sizzle)
                                                    : AnyView(Color.clipCookSurface)
                                            )
                                            .foregroundColor(currentVersionIndex == index ? .white : .clipCookTextSecondary)
                                            .cornerRadius(16)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // MARK: - Ingredients Checklist
                    if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Ingredients")
                                    .font(.headline)
                                    .foregroundColor(.clipCookSizzleStart)
                                
                                Spacer()
                                
                                Picker("System", selection: $measurementSystem) {
                                    ForEach(MeasurementSystem.allCases) { system in
                                        Text(system.rawValue).tag(system)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 150)
                            }
                            
                            VStack(spacing: 12) {
                                ForEach(ingredients, id: \.self) { ingredient in
                                    IngredientRow(
                                        ingredient: ingredient,
                                        isChecked: checkedIngredients.contains(ingredient.name),
                                        isRemixed: isIngredientChanged(ingredient.name),
                                        measurementSystem: measurementSystem
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
                .frame(maxWidth: horizontalSizeClass == .regular ? 800 : .infinity)
                .frame(maxWidth: .infinity)
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
                                Label {
                                    Text("Delete")
                                } icon: {
                                    Image(systemName: "trash")
                                }
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
                    .confirmationDialog("Delete Recipe?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                        Button("Delete", role: .destructive) {
                            deleteRecipe()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This recipe will be permanently deleted. This action cannot be undone.")
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
            
            // Loading Overlay for Remixing Generation
            if isRemixing {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 40))
                        .foregroundStyle(LinearGradient.sizzle)
                        .symbolEffect(.bounce.up.byLayer, options: .repeating)
                    
                    Text("Chef is Remixing...")
                        .font(DesignTokens.Typography.headerFont(size: 20))
                        .foregroundColor(.white)
                    
                    Text("Writing new instructions for you")
                        .font(.caption)
                        .foregroundColor(.clipCookTextSecondary)
                }
                .padding(30)
                .background(DesignTokens.Colors.surface)
                .cornerRadius(20)
                .shadow(radius: 20)
            }
            
            // Toast for pending remix save
            if showRemixSaveToast {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.white)
                        Text("Saving your remix in the background...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.clipCookSizzleStart.opacity(0.95))
                    .cornerRadius(25)
                    .shadow(radius: 8)
                    .padding(.bottom, 80)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showRemixSaveToast)
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
                            Text(hasPendingRemixSave ? "Saving..." : "Start Cooking")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .padding(.horizontal, 4)
                        .background(hasPendingRemixSave ? AnyView(Color.gray) : AnyView(LinearGradient.sizzle))
                        .foregroundColor(.white)
                        .cornerRadius(30)
                        .shadow(radius: 10)
                    }
                    .disabled(hasPendingRemixSave)
                }
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingRemix) {
            RemixSheet(prompt: $remixPrompt, isRemixing: $isRemixing, recipe: recipe) {
                performRemix()
            }
            .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showingVoiceCompanion) {
            VoiceCompanionView(recipe: recipe)
        }

        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .task {
            // Start concurrent loading
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadSavedVersions() }
                group.addTask { await self.downloadStep0Audio() }
            }
        }
        .onDisappear {
            // Show toast if navigating away with pending save
            if hasPendingRemixSave {
                withAnimation {
                    showRemixSaveToast = true
                }
                // Auto-hide after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showRemixSaveToast = false
                    }
                }
            }
        }
    }
    
    // Download Step 0 Audio if available
    private func downloadStep0Audio() async {
        guard let urlString = recipe.step0AudioUrl, let url = URL(string: urlString) else { return }
        
        // Use a stable local URL based on recipe ID
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let localUrl = tempDir.appendingPathComponent("step0_\(recipe.id).mp3")
        
        // If file already exists, use it
        if fileManager.fileExists(atPath: localUrl.path) {
            await MainActor.run {
                var updatedRecipe = recipe
                updatedRecipe.localStep0AudioUrl = localUrl
                self.recipe = updatedRecipe
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: localUrl)
            
            await MainActor.run {
                var updatedRecipe = recipe
                updatedRecipe.localStep0AudioUrl = localUrl
                self.recipe = updatedRecipe
                print("Step 0 Audio downloaded to: \(localUrl.path)")
            }
        } catch {
            print("Error downloading Step 0 Audio: \(error)")
        }
    }
    
    /// Load saved versions from the database
    private func loadSavedVersions() async {
        do {
            let savedVersions = try await VersionService.shared.fetchVersions(for: recipe.id)
            
            if !savedVersions.isEmpty {
                await MainActor.run {
                    // Create RecipeVersion objects from saved versions
                    var versions: [RecipeVersion] = [RecipeVersion(title: "Original", recipe: recipe)]
                    
                    for saved in savedVersions {
                        let versionRecipe = Recipe(
                            id: recipe.id,
                            userId: recipe.userId,
                            title: saved.title,
                            description: saved.description ?? recipe.description,
                            videoUrl: recipe.videoUrl,
                            thumbnailUrl: recipe.thumbnailUrl,
                            ingredients: saved.ingredients ?? recipe.ingredients,
                            instructions: saved.instructions ?? recipe.instructions,
                            createdAt: recipe.createdAt,
                            chefsNote: saved.chefsNote,
                            profile: recipe.profile,
                            isFavorite: recipe.isFavorite,
                            difficulty: saved.difficulty ?? recipe.difficulty,
                            cookingTime: saved.cookingTime ?? recipe.cookingTime,
                            versionId: saved.id
                        )
                        versions.append(RecipeVersion(
                            title: saved.title,
                            recipe: versionRecipe,
                            changedIngredients: Set(saved.changedIngredients ?? [])
                        ))
                    }
                    
                    self.recipeVersions = versions
                    
                    // Auto-select the latest (most recent) version so returning to the recipe shows the remix
                    let latestIndex = versions.count - 1
                    self.currentVersionIndex = latestIndex
                    
                    // Update the displayed recipe to the latest version
                    let latestVersion = versions[latestIndex]
                    self.recipe = latestVersion.recipe
                    self.changedIngredients = latestVersion.changedIngredients
                    
                    // Reset checked ingredients since we're viewing a different version
                    self.checkedIngredients.removeAll()
                }
            }
        } catch {
            print("Failed to load versions: \(error)")
            // Non-blocking - versions just won't load from DB
        }
    }
    
    /// Check if an ingredient was changed (case-insensitive matching)
    private func isIngredientChanged(_ ingredientName: String) -> Bool {
        let lowerName = ingredientName.lowercased()
        return changedIngredients.contains { $0.lowercased() == lowerName || lowerName.contains($0.lowercased()) || $0.lowercased().contains(lowerName) }
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
        
        // 1. Immediate UI Feedback
        showingRemix = false // Dismiss sheet instantly
        isRemixing = true    // Show loading overlay on RecipeView
        
        let currentRecipe = recipe
        let originalRecipeId = recipeVersions.first?.recipe.id ?? recipe.id
        
        Task {
            do {
                let remixedPart = try await RemixService.shared.remixRecipe(originalRecipe: currentRecipe, prompt: remixPrompt)
                
                // Merge new data with existing recipe
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
                    isFavorite: currentRecipe.isFavorite,
                    difficulty: remixedPart.difficulty ?? currentRecipe.difficulty,
                    cookingTime: remixedPart.cookingTime ?? currentRecipe.cookingTime
                )
                
                // Compute changed ingredients
                let newChangedIngredients = Set(remixedPart.changedIngredients ?? [])
                
                // Create version entry
                let versionTitle = newRecipe.title
                let newVersion = RecipeVersion(
                    title: versionTitle,
                    recipe: newRecipe,
                    changedIngredients: newChangedIngredients
                )
                
                // OPTIMISTIC UPDATE: Update UI immediately
                // We assume success to make the UI feel instant
                await MainActor.run {
                    // Add to version history locally first
                    self.recipeVersions.append(newVersion)
                    self.currentVersionIndex = self.recipeVersions.count - 1
                    
                    self.recipe = newRecipe
                    self.changedIngredients = newChangedIngredients
                    self.remixPrompt = "" // Clear prompt
                    self.isRemixing = false // Hide loading overlay
                    // Reset checked state as ingredients changed
                    self.checkedIngredients.removeAll()
                }
                
                // Set pending flag before background save
                await MainActor.run { self.hasPendingRemixSave = true }
                
                // BACKGROUND SAVE: Persist to DB asynchronously
                Task.detached(priority: .userInitiated) {
                    do {
                         let savedVersion = try await VersionService.shared.saveVersion(for: originalRecipeId, version: newVersion)
                         print("✅ Version saved to database: \(savedVersion.id)")
                         
                         // Update the local model with the real ID once confirmed
                         await MainActor.run {
                             if let index = self.recipeVersions.firstIndex(where: { $0.title == newVersion.title }) {
                                 // Create updated recipe with versionId
                                 var updatedRecipe = self.recipeVersions[index].recipe
                                 updatedRecipe.versionId = savedVersion.id
                                 
                                 // Create new RecipeVersion with updated recipe
                                 let updatedVersion = RecipeVersion(
                                     title: self.recipeVersions[index].title,
                                     recipe: updatedRecipe,
                                     changedIngredients: self.recipeVersions[index].changedIngredients
                                 )
                                 self.recipeVersions[index] = updatedVersion
                                 
                                 if self.currentVersionIndex == index {
                                     self.recipe.versionId = savedVersion.id
                                 }
                                 self.hasPendingRemixSave = false
                             }
                         }
                    } catch {
                         print("❌ Failed to save version to database: \(error)")
                         
                         // ROLLBACK UI on failure
                         await MainActor.run {
                             // Remove the optimistically added version
                             if let index = self.recipeVersions.firstIndex(where: { $0.title == newVersion.title }) {
                                 self.recipeVersions.remove(at: index)
                                 // Revert to original if we were on the failed version
                                 if self.currentVersionIndex == index {
                                     self.currentVersionIndex = 0
                                     self.recipe = currentRecipe
                                     self.changedIngredients.removeAll()
                                 }
                                 // Show error alert (using a simple print for now, ideally an AlertItem)
                                 print("Showing error for failed save")
                             }
                             self.hasPendingRemixSave = false
                         }
                    }
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
    
    private func selectVersion(at index: Int) {
        guard index >= 0, index < recipeVersions.count else { return }
        withAnimation {
            currentVersionIndex = index
            let version = recipeVersions[index]
            recipe = version.recipe
            changedIngredients = version.changedIngredients
            checkedIngredients.removeAll()
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
            // Check if it's an unsaved remix (has versions beyond the original)
            if recipeVersions.count > 1, let original = recipeVersions.first?.recipe {
                // It is a remix, save it first
                await MainActor.run { isSavingRemix = true }
                do {
                    let savedRecipe = try await RecipeService.shared.saveRemixedRecipe(recipe, originalId: original.id)
                    await MainActor.run {
                        self.recipe = savedRecipe
                        // Reset versions to just the saved recipe (no longer transient)
                        self.recipeVersions = [RecipeVersion(title: "Original", recipe: savedRecipe)]
                        self.currentVersionIndex = 0
                        self.changedIngredients.removeAll()
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

// MARK: - Subviews


struct SourceCardHeader: View {
    let recipe: Recipe
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Video Thumbnail or AI Placeholder
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
                            .font(.title2)
                            .foregroundColor(.clipCookSizzleStart)
                    }
                }
            }
            .frame(width: 60, height: 80)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .clipped()
            
            VStack(alignment: .leading, spacing: 6) {
                if recipe.isAIRecipe {
                    // AI-generated recipe attribution
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(LinearGradient.sizzle)
                            .font(.caption)
                        Text("AI Creation")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(LinearGradient.sizzle)
                    }
                    
                    if let prompt = recipe.sourcePrompt {
                        Text("\"\(prompt)\"")
                            .font(.caption)
                            .foregroundColor(.clipCookTextSecondary)
                            .lineLimit(2)
                            .italic()
                    }
                    
                    if let profile = recipe.profile {
                         Text("Generated by \(profile.username ?? "You")")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.clipCookTextPrimary)
                    }
                } else {
                    // Video-based recipe attribution
                    VStack(alignment: .leading, spacing: 2) {
                        // Only show creator name if available
                        if let profile = recipe.profile,
                           let name = profile.username ?? profile.fullName,
                           !name.isEmpty {
                            Text(name)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Text("via \(recipe.sourcePlatform)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.clipCookSizzleStart)
                    }
                    
                    // Deep Link Button
                    if let videoUrl = recipe.videoUrl, let _ = URL(string: videoUrl) {
                        Link(destination: URL(string: videoUrl)!) {
                            HStack(spacing: 4) {
                                Text("Open Original")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.clipCookSizzleStart)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.clipCookSurface)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}


struct IngredientRow: View {
    let ingredient: Ingredient
    let isChecked: Bool
    var isRemixed: Bool = false
    var measurementSystem: MeasurementSystem = .us
    let action: () -> Void
    
    private var displayValues: (amount: String, unit: String) {
        MeasurementConverter.shared.convert(
            amount: ingredient.amount,
            unit: ingredient.unit,
            to: measurementSystem
        )
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .clipCookSuccess : .clipCookTextSecondary)
                    .font(.title3)
                
                Text("\(displayValues.amount) \(displayValues.unit) \(ingredient.name)")
                    .font(.body)
                    .foregroundColor(isChecked ? .clipCookTextSecondary : .clipCookTextPrimary)
                    .strikethrough(isChecked)
                
                if isRemixed {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                        .foregroundStyle(LinearGradient.sizzle)
                }
                
                Spacer()
            }
            .padding()
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.Layout.cornerRadius / 2)
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
                .font(DesignTokens.Typography.bodyFont())
                .lineSpacing(4)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .premiumText()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.Layout.cornerRadius)
    }
}

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
    
    // State for Measurement Conversion
    @State private var measurementSystem: MeasurementSystem = .us
    
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
                            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                                Label {
                                    Text("Delete")
                                } icon: {
                                    Image(systemName: "trash")
                                }
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
            RemixSheet(prompt: $remixPrompt, isRemixing: $isRemixing, recipe: recipe) {
                performRemix()
            }
            .presentationDetents([.medium, .large])
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
                            isFavorite: recipe.isFavorite
                        )
                        versions.append(RecipeVersion(
                            title: saved.title,
                            recipe: versionRecipe,
                            changedIngredients: Set(saved.changedIngredients ?? [])
                        ))
                    }
                    
                    self.recipeVersions = versions
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
        isRemixing = true
        
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
                    isFavorite: currentRecipe.isFavorite
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
                
                // Save version to database (fire and forget)
                Task {
                    do {
                        _ = try await VersionService.shared.saveVersion(for: originalRecipeId, version: newVersion)
                        print("Version saved to database")
                    } catch {
                        print("Failed to save version to database: \(error)")
                    }
                }
                
                await MainActor.run {
                    // Add to version history
                    self.recipeVersions.append(newVersion)
                    self.currentVersionIndex = self.recipeVersions.count - 1
                    
                    self.recipe = newRecipe
                    self.changedIngredients = newChangedIngredients
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

// MARK: - NEW SUBVIEWS

struct RemixSheet: View {
    @Binding var prompt: String
    @Binding var isRemixing: Bool
    var recipe: Recipe // Passed in to access ID/Title for context if needed
    let onRemix: () -> Void
    
    @State private var chatHistory: [RemixService.ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var lastConsultation: RemixService.RemixConsultation?
    @FocusState private var isInputFocused: Bool
    
    // Rotating status messages
    private let statusMessages = [
        "Analyzing flavor profile...",
        "Checking ingredient compatibility...",
        "Consulting the flavor bible...",
        "Predicting cooking time...",
        "Reviewing techniques...",
        "Calculating difficulty..."
    ]
    @State private var currentStatusIndex = 0
    @State private var statusTimer: Timer?
    
    var body: some View {
        ZStack {
            Color.clipCookBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Remix Chef")
                        .modifier(UtilityHeadline())
                    Spacer()
                    Button(action: {
                        stopStatusRotation()
                        // Dismiss logic handles by parent if needed, but here we just close?
                        // Actually parent controls presentation.
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                .padding()
                .background(Color.clipCookSurface)
                
                // Chat ScrollView
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // Initial Greeting
                            HStack {
                                Image(systemName: "chef.hat.fill")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(LinearGradient.sizzle)
                                    .clipShape(Circle())
                                
                                Text("Hi! I'm your AI Sous Chef. How would you like to tweak this recipe? I can make it vegan, spicier, easier, you name it!")
                                    .padding()
                                    .background(Color.clipCookSurface)
                                    .foregroundColor(.white)
                                    .cornerRadius(12, corners: [.topRight, .bottomLeft, .bottomRight])
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            // History
                            ForEach(Array(chatHistory.enumerated()), id: \.offset) { index, msg in
                                MessageBubble(message: msg)
                            }
                            
                            // Loading Indicator
                            if isLoading {
                                HStack {
                                    Image(systemName: "chef.hat.fill")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(LinearGradient.sizzle)
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(statusMessages[currentStatusIndex])
                                            .font(.caption)
                                            .foregroundColor(.clipCookTextSecondary)
                                            .animation(.easeInOut, value: currentStatusIndex)
                                        
                                        HStack(spacing: 4) {
                                            Circle().frame(width: 6, height: 6).foregroundColor(.clipCookSizzleStart)
                                                .opacity(0.5)
                                            Circle().frame(width: 6, height: 6).foregroundColor(.clipCookSizzleStart)
                                                .opacity(0.8)
                                            Circle().frame(width: 6, height: 6).foregroundColor(.clipCookSizzleStart)
                                        }
                                    }
                                    .padding()
                                    .background(Color.clipCookSurface)
                                    .cornerRadius(12, corners: [.topRight, .bottomLeft, .bottomRight])
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("loading")
                            }
                            
                            Color.clear.frame(height: 20)
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: chatHistory.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(chatHistory.count - 1, anchor: .bottom)
                        }
                    }
                    .onChange(of: isLoading) { _, loading in
                        if loading {
                            withAnimation {
                                proxy.scrollTo("loading", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Consultation Card (if available)
                if let consult = lastConsultation, !isLoading {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 20) {
                            // Difficulty Metric
                            VStack {
                                Text("DIFFICULTY")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                
                                Text(consult.difficultyImpact.uppercased())
                                    .font(.caption)
                                    .fontWeight(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(difficultyColor(consult.difficultyImpact))
                                    .cornerRadius(6)
                                    .foregroundColor(.white)
                            }
                            
                            Divider().frame(height: 30)
                            
                            // Quality Metric
                            VStack {
                                Text("QUALITY")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                
                                Text(consult.qualityImpact.uppercased())
                                    .font(.caption)
                                    .fontWeight(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(qualityColor(consult.qualityImpact))
                                    .cornerRadius(6)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // ACTION BUTTON
                            Button(action: {
                                confirmRemix()
                            }) {
                                HStack {
                                    Text("Let's Make It")
                                        .fontWeight(.bold)
                                    Image(systemName: "arrow.right")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(LinearGradient.sizzle)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .shadow(radius: 4)
                            }
                        }
                        
                        // Explanations
                        if !consult.difficultyExplanation.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "info.circle").font(.caption).foregroundColor(.gray)
                                Text(consult.difficultyExplanation)
                                    .font(.caption)
                                    .foregroundColor(.clipCookTextSecondary)
                            }
                        }
                        if !consult.qualityExplanation.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "star").font(.caption).foregroundColor(.gray)
                                Text(consult.qualityExplanation)
                                    .font(.caption)
                                    .foregroundColor(.clipCookTextSecondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.clipCookSurface.opacity(0.9))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Input Area
                HStack(spacing: 12) {
                    TextField("E.g. Make it gluten free...", text: $inputText)
                        .padding(12)
                        .background(Color.clipCookSurface)
                        .cornerRadius(20)
                        .foregroundColor(.white)
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            submitConsultation()
                        }
                    
                    Button(action: submitConsultation) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(inputText.isEmpty ? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom) : LinearGradient.sizzle)
                    }
                    .disabled(inputText.isEmpty || isLoading)
                }
                .padding()
                .background(Color.black.opacity(0.2))
            }
        }
        .onAppear {
            if prompt.isEmpty {
                isInputFocused = true
            }
        }
    }
    
    // MARK: - Logic
    
    private func submitConsultation() {
        guard !inputText.isEmpty else { return }
        
        let userMsg = RemixService.ChatMessage(role: "user", content: inputText)
        chatHistory.append(userMsg)
        
        // Optimistic UI updates
        let currentInput = inputText
        inputText = ""
        isLoading = true
        startStatusRotation()
        lastConsultation = nil // Hide card while thinking
        
        Task {
            do {
                let consultation = try await RemixService.shared.remixConsult(
                    originalRecipe: recipe,
                    chatHistory: chatHistory,
                    prompt: currentInput
                )
                
                await MainActor.run {
                    stopStatusRotation()
                    isLoading = false
                    lastConsultation = consultation
                    
                    // Add AI response to chat
                    let aiMsg = RemixService.ChatMessage(role: "assistant", content: consultation.reply)
                    chatHistory.append(aiMsg)
                }
            } catch {
                print("Consultation error: \(error)")
                await MainActor.run {
                    stopStatusRotation()
                    isLoading = false
                    // Show error message in chat
                    chatHistory.append(RemixService.ChatMessage(role: "assistant", content: "I'm having a bit of trouble connecting to the kitchen. Can you try again?"))
                }
            }
        }
    }
    
    private func confirmRemix() {
        // Construct final prompt from history to preserve context
        let conversationLog = chatHistory.map { "\($0.role.uppercased()): \($0.content)" }.joined(separator: "\n")
        let finalPrompt = "Apply the changes discussed in this conversation:\n\n\(conversationLog)"
        
        prompt = finalPrompt
        onRemix()
    }
    
    private func difficultyColor(_ impact: String) -> Color {
        switch impact.lowercased() {
        case "easier": return .green
        case "harder": return .orange
        case "same": return .blue
        default: return .gray
        }
    }
    
    private func qualityColor(_ impact: String) -> Color {
        switch impact.lowercased() {
        case "better": return .green
        case "worse": return .red
        case "different": return .purple
        default: return .gray
        }
    }
    
    private func startStatusRotation() {
        currentStatusIndex = 0
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            withAnimation {
                currentStatusIndex = (currentStatusIndex + 1) % statusMessages.count
            }
        }
    }
    
    private func stopStatusRotation() {
        statusTimer?.invalidate()
        statusTimer = nil
    }
}

struct MessageBubble: View {
    let message: RemixService.ChatMessage
    
    var isUser: Bool { message.role == "user" }
    
    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer() }
            
            if !isUser {
                Image(systemName: "chef.hat.fill")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(LinearGradient.sizzle)
                    .clipShape(Circle())
            }
            
            Text(message.content)
                .padding()
                .background(isUser ? Color.clipCookSizzleStart.opacity(0.8) : Color.clipCookSurface)
                .foregroundColor(.white)
                .cornerRadius(12, corners: isUser ? [.topLeft, .topRight, .bottomLeft] : [.topRight, .bottomLeft, .bottomRight])
                .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
            
            if !isUser { Spacer() }
        }
        .padding(.horizontal)
    }
}

// Helper for corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
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
                        if let profile = recipe.profile {
                            Text(profile.username ?? "Unknown Chef")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Text("on \(recipe.sourcePlatform)")
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

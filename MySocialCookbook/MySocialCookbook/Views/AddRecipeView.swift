import SwiftUI

struct AddRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0 // 0 for Link, 1 for Describe
    @State private var urlString = ""
    @State private var promptText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clipCookBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Segmented Control
                        Picker("Method", selection: $selectedTab) {
                            Text("Share Link").tag(0)
                            Text("Describe").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        if selectedTab == 0 {
                            linkView
                        } else {
                            describeView
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                        
                        if let success = successMessage {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.clipCookSuccess)
                                    .font(.largeTitle)
                                Text(success)
                                    .modifier(UtilitySubhead())
                            }
                            .padding()
                            .transition(.scale)
                        }
                        
                        Spacer()
                    }
                }
                
                if isLoading {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .clipCookSizzleStart))
                            .scaleEffect(1.5)
                        Text(selectedTab == 0 ? "Analyzing Video..." : "Asking the Chef...")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                    .padding(32)
                    .background(Color.clipCookSurface)
                    .cornerRadius(20)
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.clipCookTextSecondary)
                }
            }
            .onAppear {
                // Setup for TextEditor background clearing on older iOS if needed
                // UITextView.appearance().backgroundColor = .clear
            }
        }
    }
    
    private var linkView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Paste a link from TikTok, Instagram, YouTube, or Pinterest.")
                .modifier(UtilitySubhead())
                .padding(.horizontal)
            
            TextField("https://...", text: $urlString)
                .padding()
                .background(Color.clipCookSurface)
                .cornerRadius(12)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal)
            
            Button(action: handleAddByLink) {
                HStack {
                    Image(systemName: "link")
                    Text("Extract Recipe")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(urlString.isEmpty ? Color.gray : Color.clipCookSizzleStart)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(urlString.isEmpty || isLoading)
            .padding(.horizontal)
            
            Text("We'll analyze the video and notify you once the recipe is ready!")
                .font(.caption)
                .foregroundColor(.clipCookTextSecondary)
                .padding(.horizontal)
        }
    }
    
    private var describeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tell the chef what you're thinking of making.")
                .modifier(UtilitySubhead())
                .padding(.horizontal)
            
            ZStack(alignment: .topLeading) {
                if #available(iOS 16.0, *) {
                    TextEditor(text: $promptText)
                        .scrollContentBackground(.hidden) // Critical for dark mode background
                        .background(Color.clipCookSurface)
                        .foregroundColor(.white)
                        .frame(height: 150)
                        .cornerRadius(12)
                } else {
                    TextEditor(text: $promptText)
                        .background(Color.clipCookSurface)
                        .foregroundColor(.white)
                        .frame(height: 150)
                        .cornerRadius(12)
                }
                
                if promptText.isEmpty {
                    Text("A simple grilled cheese sandwich with sourdough...")
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal)
            
            Button(action: handleGenerateRecipe) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Recipe")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(promptText.isEmpty ? Color.gray : Color.clipCookSizzleStart)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(promptText.isEmpty || isLoading)
            .padding(.horizontal)
        }
    }
    
    private func handleAddByLink() {
        guard !urlString.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        let userId = AuthViewModel.shared.userId ?? ""
        
        Task {
            do {
                try await RecipeService.shared.processRecipe(url: urlString, userId: userId)
                await MainActor.run {
                    isLoading = false
                    successMessage = "Processing started!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Something went wrong. Please check the URL."
                }
            }
        }
    }
    
    private func handleGenerateRecipe() {
        guard !promptText.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        let userId = AuthViewModel.shared.userId ?? ""
        
        Task {
            do {
                _ = try await RecipeService.shared.createRecipeFromPrompt(prompt: promptText, userId: userId)
                await MainActor.run {
                    isLoading = false
                    successMessage = "Recipe created!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "The chef couldn't understand that. Try again!"
                }
            }
        }
    }
}

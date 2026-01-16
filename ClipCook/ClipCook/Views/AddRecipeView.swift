import SwiftUI
import UIKit

struct AddRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0 // 0 for Link, 1 for Describe
    @State private var urlString = ""
    @State private var promptText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Callbacks to notify parent of processing state
    var onProcessingStarted: (() -> Void)?
    var onProcessingFailed: ((String) -> Void)?
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
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
                        
                        Spacer()
                    }
                    .frame(maxWidth: horizontalSizeClass == .regular ? 600 : .infinity)
                    .frame(maxWidth: .infinity)
                }
                
                // Brief loading indicator while initiating request
                if isLoading {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .clipCookPrimary))
                        .scaleEffect(1.5)
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
                // Check clipboard for URL and auto-populate
                checkClipboardForURL()
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
                .cornerRadius(DesignTokens.Layout.cornerRadiusMedium)
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
                .background(urlString.isEmpty ? Color.gray : Color.clipCookPrimary)
                .foregroundColor(.white)
                .cornerRadius(DesignTokens.Layout.cornerRadiusMedium)
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
                        .cornerRadius(DesignTokens.Layout.cornerRadiusMedium)
                } else {
                    TextEditor(text: $promptText)
                        .background(Color.clipCookSurface)
                        .foregroundColor(.white)
                        .frame(height: 150)
                        .cornerRadius(DesignTokens.Layout.cornerRadiusMedium)
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
                .background(promptText.isEmpty ? Color.gray : Color.clipCookPrimary)
                .foregroundColor(.white)
                .cornerRadius(DesignTokens.Layout.cornerRadiusMedium)
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
        let url = urlString
        
        Task {
            do {
                try await RecipeService.shared.processRecipe(url: url, userId: userId)
                await MainActor.run {
                    onProcessingStarted?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    onProcessingFailed?("Something went wrong. Please check the URL.")
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
        let prompt = promptText
        
        Task {
            do {
                _ = try await RecipeService.shared.createRecipeFromPrompt(prompt: prompt, userId: userId)
                await MainActor.run {
                    onProcessingStarted?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    onProcessingFailed?("The chef couldn't understand that. Try again!")
                    errorMessage = "The chef couldn't understand that. Try again!"
                }
            }
        }
    }
    
    private func checkClipboardForURL() {
        guard let clipboardString = UIPasteboard.general.string else { return }
        
        // Check if it's a valid URL
        guard let url = URL(string: clipboardString),
              url.scheme == "http" || url.scheme == "https" else {
            return
        }
        
        // Check if it's from a supported platform
        let supportedDomains = ["tiktok.com", "instagram.com", "youtube.com", "youtu.be", "pinterest.com"]
        let host = url.host?.lowercased() ?? ""
        
        let isSupported = supportedDomains.contains { domain in
            host.contains(domain)
        }
        
        if isSupported {
            urlString = clipboardString
            selectedTab = 0 // Switch to Link tab
        }
    }
}

import SwiftUI

struct LegalDocumentView: View {
    let title: String
    let content: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(.init(content))
                    .font(.body)
                    .foregroundColor(.clipCookTextPrimary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
        }
        .background(Color.clipCookBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                LiquidGlassBackButton()
            }
        }
    }
}

#Preview {
    LegalDocumentView(
        title: "Privacy Policy",
        content: """
        # Privacy Policy
        
        Last updated: January 1, 2026
        
        This is a placeholder for the Privacy Policy.
        
        ## 1. Introduction
        We respect your privacy...
        """
    )
}

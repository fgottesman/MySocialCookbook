import SwiftUI

struct LegalDocumentView: View {
    let title: String
    let content: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
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

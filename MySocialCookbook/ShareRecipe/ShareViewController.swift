import UIKit
import Social
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // 1. Extract URL
        if let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem {
            if let attachments = extensionItem.attachments {
                for provider in attachments {
                    if provider.hasItemConformingToTypeIdentifier("public.url") {
                        provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (item, error) in
                            if let url = item as? URL {
                                self?.sendToBackend(url: url)
                            } else if let urlString = item as? String, let url = URL(string: urlString) {
                                self?.sendToBackend(url: url)
                            }
                        }
                    }
                }
            }
        }
        
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }
    
    private func sendToBackend(url: URL) {
        // IMPORTANT: In a real Share Extension, you must use a shared Container (App Groups) or independent networking.
        // We'll use a direct URLSession here for simplicity.
        guard let endpoint = URL(string: "http://localhost:8080/api/share") else { return }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // TODO: Replace with real authenticated User ID
        let userId = "user_123"
        
        let body: [String: String] = ["url": url.absoluteString, "userId": userId]
        request.httpBody = try? JSONEncoder().encode(body)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sharing: \(error)")
            } else {
                print("Successfully shared to backend")
            }
        }
        task.resume()
    }

}

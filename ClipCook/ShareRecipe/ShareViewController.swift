import UIKit
import SwiftUI
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Make the view background clear so it overlays nicely if needed,
        // although we'll present a full screen SwiftUI view.
        self.view.backgroundColor = .clear
        
        extractAndShare()
    }
    
    private func extractAndShare() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            showResult(success: false, message: "Nothing to share")
            return
        }
        
        let contentTypeURL = UTType.url.identifier
        let contentTypeText = UTType.plainText.identifier
        
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(contentTypeURL) {
                provider.loadItem(forTypeIdentifier: contentTypeURL, options: nil) { [weak self] (item, error) in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            self?.sendToBackend(url: url)
                        } else if let urlString = item as? String, let url = URL(string: urlString) {
                            self?.sendToBackend(url: url)
                        } else {
                            self?.showResult(success: false, message: "Could not extract URL")
                        }
                    }
                }
                return
            } else if provider.hasItemConformingToTypeIdentifier(contentTypeText) {
                provider.loadItem(forTypeIdentifier: contentTypeText, options: nil) { [weak self] (item, error) in
                    DispatchQueue.main.async {
                        if let text = item as? String,
                           let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
                            if let firstMatch = matches.first, let url = firstMatch.url {
                                self?.sendToBackend(url: url)
                                return
                            }
                        }
                        self?.showResult(success: false, message: "No URL found in text")
                    }
                }
                return
            }
        }
        
        showResult(success: false, message: "No shareable content found")
    }
    
    private func sendToBackend(url: URL) {
        guard let endpoint = URL(string: "https://mysocialcookbook-production.up.railway.app/api/process-recipe") else {
            showResult(success: false, message: "Invalid backend URL")
            return
        }
        
        let suiteName = "group.com.mysocialcookbook"
        guard let sharedDefaults = UserDefaults(suiteName: suiteName),
              let userId = sharedDefaults.string(forKey: "shared_user_id") else {
            showResult(success: false, message: "Please log in first")
            return
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["url": url.absoluteString, "userId": userId]
        request.httpBody = try? JSONEncoder().encode(body)
        
        let task = URLSession.shared.dataTask(with: request) { _, _, _ in
            // Silently ignore response for fire-and-forget
        }
        task.resume()
        
        // Show success confirmation
        showResult(success: true, message: "")
    }
    
    private func showResult(success: Bool, message: String) {
        if success {
            // Present the SwiftUI Success View
            let successView = ShareSuccessView { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
            
            let host = UIHostingController(rootView: successView)
            host.view.backgroundColor = .clear
            host.modalPresentationStyle = .fullScreen
            
            // Add as child view controller to ensure it fills the space
            addChild(host)
            view.addSubview(host.view)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                host.view.topAnchor.constraint(equalTo: view.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            host.didMove(toParent: self)
            
        } else {
            // Fallback for error - just show an alert or close
            // For now, let's just close after a brief delay if it fails, or show a simple alert.
            // But to keep it simple and given the task focus is on success:
             self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareError", code: 0, userInfo: [NSLocalizedDescriptionKey: message]))
        }
    }
}

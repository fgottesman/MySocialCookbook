import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    private let containerView = UIView()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractAndShare()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        // Container card
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Activity Indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        containerView.addSubview(activityIndicator)
        
        // Status Label
        statusLabel.text = "Saving recipe..."
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 200),
            containerView.heightAnchor.constraint(equalToConstant: 120),
            
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            
            statusLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8)
        ])
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
        guard let endpoint = URL(string: "http://192.168.7.161:8083/api/process-recipe") else {
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
        
        // FIRE AND FORGET: Send request but don't wait for response
        // This avoids Share Extension timeout issues
        let task = URLSession.shared.dataTask(with: request) { _, _, _ in
            // Silently ignore response - recipe will appear in feed when ready
        }
        task.resume()
        
        // Immediately show success and dismiss
        showResult(success: true, message: "Processing...")
    }
    
    private func showResult(success: Bool, message: String) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        
        statusLabel.text = message
        statusLabel.textColor = success ? .systemGreen : .systemRed
        
        // Auto-dismiss after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}

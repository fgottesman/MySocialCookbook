import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    private let containerView = UIView()
    private let statusLabel = UILabel()
    private let iconImageView = UIImageView()
    private let loadingLayer = CAShapeLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractAndShare()
    }
    
    private func setupUI() {
        // Blur background
        let blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)
        
        // Container
        containerView.backgroundColor = .clear
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // App Icon
        iconImageView.image = UIImage(named: "AppIcon")
        if iconImageView.image == nil {
            // Fallback to a system icon and a background color if AppIcon isn't available
            iconImageView.image = UIImage(systemName: "fork.knife.circle.fill")
            iconImageView.tintColor = .systemOrange
        }
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 24
        iconImageView.clipsToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconImageView)
        
        // Loading Circle Layer
        let circularPath = UIBezierPath(arcCenter: .zero, radius: 30, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        
        loadingLayer.path = circularPath.cgPath
        loadingLayer.strokeColor = UIColor.systemOrange.cgColor
        loadingLayer.lineWidth = 3
        loadingLayer.fillColor = UIColor.clear.cgColor
        loadingLayer.lineCap = .round
        loadingLayer.strokeEnd = 0.25
        
        iconImageView.layer.addSublayer(loadingLayer)
        
        // Add rotation animation
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.toValue = 2 * Double.pi
        rotationAnimation.duration = 1.2
        rotationAnimation.repeatCount = .infinity
        iconImageView.layer.add(rotationAnimation, forKey: "rotate")
        
        // Status Label
        statusLabel.text = "Analysing recipe..."
        statusLabel.textAlignment = .center
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            
            statusLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Adjust loading layer position
        loadingLayer.position = CGPoint(x: 24, y: 24)
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
        showResult(success: true, message: "We'll let you know when the recipe is ready to cook")
    }
    
    private func showResult(success: Bool, message: String) {
        if success {
            loadingLayer.strokeEnd = 1.0
            loadingLayer.strokeColor = UIColor.systemGreen.cgColor
            iconImageView.layer.removeAnimation(forKey: "rotate")
        } else {
            loadingLayer.isHidden = true
            iconImageView.layer.removeAnimation(forKey: "rotate")
            statusLabel.textColor = .systemRed
        }
        
        statusLabel.text = message
        
        // Auto-dismiss after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}

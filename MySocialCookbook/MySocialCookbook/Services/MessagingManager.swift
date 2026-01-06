
import Foundation
import UserNotifications
import UIKit

class MessagingManager: NSObject, ObservableObject {
    static let shared = MessagingManager()
    
    @Published var isRegistered = false
    @Published var deviceToken: String?
    
    private let backendUrl = "https://mysocialcookbook-production.up.railway.app/api/register-device"
    
    override init() {
        super.init()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("Permission granted: \(granted)")
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func registerDevice(token: Data, userId: String) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        
        print("Device Token: \(tokenString)")
        
        // Send to backend
        sendTokenToBackend(token: tokenString, userId: userId)
    }
    
    private func sendTokenToBackend(token: String, userId: String) {
        guard let url = URL(string: backendUrl) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "deviceToken": token,
            "platform": "ios"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error registering device: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("Device successfully registered with backend")
                    DispatchQueue.main.async {
                        self.isRegistered = true
                    }
                } else {
                    print("Backend registration failed: \(String(describing: response))")
                }
            }.resume()
        } catch {
            print("Error encoding JSON: \(error)")
        }
    }
}

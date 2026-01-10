
import Foundation

struct AppConfig {
    static let apiBaseUrl = "https://mysocialcookbook-production.up.railway.app"
    
    static var apiEndpoint: String {
        "\(apiBaseUrl)/api/v1"
    }
    
    // Legacy endpoint for backward compatibility during transition
    static var legacyApiEndpoint: String {
        "\(apiBaseUrl)/api"
    }
    
    // WebSocket endpoint - aligned with backend routes
    static var wsEndpoint: String {
        "wss://mysocialcookbook-production.up.railway.app/api/ws"
    }
}

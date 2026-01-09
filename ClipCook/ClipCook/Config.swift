
import Foundation

struct AppConfig {
    static let apiBaseUrl = "https://mysocialcookbook-production.up.railway.app"
    
    static var apiEndpoint: String {
        "\(apiBaseUrl)/api"
    }
    
    // WebSocket requires wss:// scheme, not https://
    static var wsEndpoint: String {
        "wss://mysocialcookbook-production.up.railway.app/ws"
    }
}

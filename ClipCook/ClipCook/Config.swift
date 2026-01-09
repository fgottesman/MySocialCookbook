
import Foundation

struct AppConfig {
    static let apiBaseUrl = "https://mysocialcookbook-production.up.railway.app"
    
    static var apiEndpoint: String {
        "\(apiBaseUrl)/api"
    }
    
    static var wsEndpoint: String {
        "\(apiBaseUrl)/ws"
    }
}

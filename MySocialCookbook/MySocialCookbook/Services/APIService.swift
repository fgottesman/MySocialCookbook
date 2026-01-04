import Foundation

class APIService: ObservableObject {
    static let shared = APIService()
    private let baseURL = "http://localhost:8080/api" // Use your Cloud Run URL in production
    
    @Published var recipes: [Recipe] = []
    
    func fetchRecipes() {
        guard let url = URL(string: "\(baseURL)/recipes") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decodedRecipes = try JSONDecoder().decode([Recipe].self, from: data)
                    DispatchQueue.main.async {
                        self.recipes = decodedRecipes
                    }
                } catch {
                    print("Error decoding recipes: \(error)")
                }
            }
        }.resume()
    }
    
    func shareVideo(url: String, userId: String, completion: @escaping (Bool) -> Void) {
        guard let endpoint = URL(string: "\(baseURL)/share") else { return }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["url": url, "userId": userId]
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sharing video: \(error)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
}

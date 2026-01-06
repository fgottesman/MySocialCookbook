import Foundation
import Supabase
import Auth

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        // Configuration
        let supabaseUrl = URL(string: "https://xbclhuikdmcarifsugru.supabase.co")!
        // It is generally safe to expose the ANON key in the client, but ensure RLS is on.
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhiY2xodWlrZG1jYXJpZnN1Z3J1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2MzMsImV4cCI6MjA4MzEzOTYzM30.LvWqu4Ub4bHoCJv0Jolq-oDVemNk7wO4y3prgB3Mv4E"
        
        self.client = SupabaseClient(
            supabaseURL: supabaseUrl,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }
}

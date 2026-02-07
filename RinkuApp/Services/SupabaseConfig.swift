import Foundation

/// Supabase Configuration
/// Reads credentials from Secrets.plist (which is gitignored)
struct SupabaseConfig {
    
    private static var secrets: [String: Any]? = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("⚠️ Secrets.plist not found. Copy Secrets.template.plist to Secrets.plist and add your credentials.")
            return nil
        }
        return dict
    }()
    
    static var projectURL: URL {
        let urlString = secrets?["SUPABASE_URL"] as? String ?? "https://example.supabase.co"
        return URL(string: urlString)!
    }
    
    static var anonKey: String {
        secrets?["SUPABASE_ANON_KEY"] as? String ?? ""
    }
    
    // API endpoints
    static var authURL: URL { projectURL.appendingPathComponent("auth/v1") }
    static var restURL: URL { projectURL.appendingPathComponent("rest/v1") }
    static var storageURL: URL { projectURL.appendingPathComponent("storage/v1") }
    
    // Storage bucket
    static let photosBucket = "face-photos"
    
    /// Check if credentials are configured
    static var isConfigured: Bool {
        !anonKey.isEmpty &&
        anonKey != "YOUR_SUPABASE_ANON_KEY"
    }
}

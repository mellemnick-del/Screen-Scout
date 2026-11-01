import Foundation

enum Config {
    #if DEBUG
    /// The backend running on your Mac (`uvicorn app.main:app` in the backend folder).
    /// Works in the iOS Simulator. For a real iPhone on your Wi-Fi, use your Mac's
    /// local IP instead, e.g. http://192.168.1.20:8000
    static let baseURL = URL(string: "http://127.0.0.1:8000")!
    #else
    /// Your deployed backend. Must be https for the App Store.
    static let baseURL = URL(string: "https://YOUR-BACKEND-HOST.example.com")!
    #endif

    /// Must match SCOUT_APP_TOKEN on the server. Leave both empty while developing.
    static let appToken = ""
}

import Foundation

enum Config {
    #if DEBUG
    /// The server running on Nick's Mac (backend/start.sh). Works for the
    /// Simulator and for iPhones on the same Wi-Fi. If the Mac's address
    /// changes, update it here.
    static let baseURL = URL(string: "http://192.168.4.109:8000")!
    #else
    /// Your deployed backend. Must be https for the App Store.
    static let baseURL = URL(string: "https://YOUR-BACKEND-HOST.example.com")!
    #endif
}

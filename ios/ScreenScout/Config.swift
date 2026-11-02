import Foundation

enum Config {
    /// The Screen Scout server, hosted on Render.
    /// To test against the server on your Mac instead (backend/start.sh),
    /// swap in: URL(string: "http://192.168.4.109:8000")!
    static let baseURL = URL(string: "https://screen-scout-pz4e.onrender.com")!
}

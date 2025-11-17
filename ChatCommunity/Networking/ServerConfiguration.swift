import Foundation

struct ServerConfiguration {
    let baseURL: URL?
    let messagePath: String

    static let live = ServerConfiguration()

    var components: URLComponents? {
        guard let baseURL else { return nil }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = messagePath
        return components
    }

    init(baseURL: URL? = URL(string: Bundle.main.infoDictionary?["ChatServerURL"] as? String ?? "http://localhost:8080"),
         messagePath: String = "/messages") {
        self.baseURL = baseURL
        self.messagePath = messagePath
    }
}

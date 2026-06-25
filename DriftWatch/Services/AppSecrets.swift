import Foundation

/// App configuration read from a bundled, gitignored `Secrets.plist`.
///
/// Keeping the key out of source keeps it out of git. A client key still ships
/// inside the app binary, so this protects the repository, not the key itself;
/// a truly secret key would live behind a server proxy. User-provided secrets
/// (a login token) would go to the Keychain instead.
enum AppSecrets {
    /// NewsData.io API key, or nil when `Secrets.plist` is absent (a fresh clone
    /// without the file). The news tab degrades to a clear message in that case.
    static let newsDataAPIKey: String? = value(for: "NewsDataAPIKey")

    private static func value(for key: String) -> String? {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dict = plist as? [String: Any],
            let raw = dict[key] as? String,
            !raw.isEmpty
        else {
            return nil
        }
        return raw
    }
}

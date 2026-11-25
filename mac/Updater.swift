import Cocoa
import CryptoKit
import Security

/// Keeps an installed copy current from the GitHub releases. latest-mac.json (written by mac/package.sh)
/// names the newest build and its zip's SHA-256; the zip is downloaded and unpacked in the background, and
/// the new app is swapped in when KeyCat quits or the user picks 重启并更新.
///
/// The unpacked app must satisfy this app's own designated requirement (the certificate in signing/), so
/// only builds signed with that certificate are accepted. The same requirement is what keeps the Input
/// Monitoring grant across the swap.
@MainActor
final class Updater {
    enum State: Equatable {
        case idle, checking, current, failed
        case downloading(String)
        case ready(String)
    }

    struct Manifest: Decodable {
        let version: String
        let build: Int
        let url: URL
        let sha256: String
    }

    struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ text: String) { errorDescription = text }
    }

    /// `KEYCAT_UPDATE_URL=<manifest>` checks somewhere else and lifts the Applications-folder rule; for testing.
    static let testManifest = ProcessInfo.processInfo.environment["KEYCAT_UPDATE_URL"].flatMap(URL.init(string:))
    let manifestURL = testManifest
        ?? URL(string: "https://github.com/ElloboDK/KeyCat/releases/latest/download/latest-mac.json")!
    let bundle = Bundle.main.bundleURL
    let build = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    weak var app: AppDelegate?
    private(set) var state = State.idle
    /// The verified new KeyCat.app, next to the installed one's volume so the swap is a rename.
    private var staged: URL?
    private var timer: Timer?

    init(app: AppDelegate) { self.app = app }

    /// Only copies installed in an Applications folder update themselves: a build in build/ is the
    /// developer's, and a copy run from Downloads is translocated to a read-only path by Gatekeeper.
    var enabled: Bool {
        if Self.testManifest != nil { return true }
        let parent = bundle.deletingLastPathComponent().path
        return [ "/Applications", NSHomeDirectory() + "/Applications" ].contains(parent)
            && FileManager.default.isWritableFile(atPath: parent)
    }

    /// First check 15 s after launch, then every 6 hours, like the Windows build.
    func start() {
        guard enabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in self?.check() }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    func check() {
        switch state {
        case .checking, .downloading: return
        case .ready: if let staged, FileManager.default.fileExists(atPath: staged.path) { return }
        default: break
        }
        set(.checking)
        Task {
            do {
                if let version = try await fetch() {
                    app?.log("update \(version) ready")
                    set(.ready(version))
                } else {
                    set(.current)
                }
            } catch {
                app?.log("update failed: \(error.localizedDescription)")
                set(.failed)
            }
        }
    }

    /// Downloads and verifies a newer build if there is one; returns its version, or nil when current.
    private func fetch() async throws -> String? {
        var request = URLRequest(url: manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 200 == 200 else { throw Failure("manifest HTTP error") }
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        guard manifest.build > build else { return nil }
        app?.log("update \(manifest.version) (build \(manifest.build)) available")
        set(.downloading(manifest.version))

        let (zip, zipResponse) = try await URLSession.shared.download(from: manifest.url)
        defer { try? FileManager.default.removeItem(at: zip) }
        guard (zipResponse as? HTTPURLResponse)?.statusCode ?? 200 == 200 else { throw Failure("download HTTP error") }
        let digest = SHA256.hash(data: try Data(contentsOf: zip)).map { String(format: "%02x", $0) }.joined()
        guard digest == manifest.sha256.lowercased() else { throw Failure("zip SHA-256 does not match latest-mac.json") }

        let dir = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                              appropriateFor: bundle, create: true)
        let fresh = try await Task.detached { try Self.unpack(zip, into: dir) }.value
        let info = NSDictionary(contentsOf: fresh.appendingPathComponent("Contents/Info.plist"))
        guard info?["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              info?["CFBundleVersion"] as? String == String(manifest.build)
        else { throw Failure("unpacked app is not build \(manifest.build) of KeyCat") }
        try Self.verifySignature(fresh)
        if let old = staged { try? FileManager.default.removeItem(at: old.deletingLastPathComponent()) }
        staged = fresh
        return manifest.version
    }

    nonisolated static func unpack(_ zip: URL, into dir: URL) throws -> URL {
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, dir.path]
        try ditto.run()
        ditto.waitUntilExit()
        let app = dir.appendingPathComponent("KeyCat.app")
        guard ditto.terminationStatus == 0, FileManager.default.fileExists(atPath: app.path)
        else { throw Failure("could not unpack the zip") }
        return app
    }

    /// The new app must be signed by the same certificate as this one. An ad-hoc signed copy has a
    /// requirement no other build meets, so it never updates rather than accepting anything.
    static func verifySignature(_ app: URL) throws {
        var running: SecCode?
        var me: SecStaticCode?
        var requirement: SecRequirement?
        var code: SecStaticCode?
        guard SecCodeCopySelf([], &running) == errSecSuccess, let running,
              SecCodeCopyStaticCode(running, [], &me) == errSecSuccess, let me,
              SecCodeCopyDesignatedRequirement(me, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code
        else { throw Failure("could not read code signatures") }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
        let status = SecStaticCodeCheckValidity(code, flags, requirement)
        guard status == errSecSuccess else { throw Failure("new app's signature is not ours (\(status))") }
    }

    /// Puts the staged app in place of the installed one. Called as KeyCat quits, so the next launch
    /// (or the relaunch after 重启并更新) is the new version.
    func install() {
        guard let staged, FileManager.default.fileExists(atPath: staged.path) else { return }
        self.staged = nil
        do {
            _ = try FileManager.default.replaceItemAt(bundle, withItemAt: staged)
            app?.log("installed update into \(bundle.path)")
        } catch {
            app?.log("update install failed: \(error.localizedDescription)")
        }
        try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
    }

    private func set(_ new: State) {
        state = new
        if case .ready(let version) = new {
            app?.statusItem?.button?.toolTip = "KeyCat：v\(version) 已下载，退出时自动更新，也可从菜单重启更新"
        }
    }
}

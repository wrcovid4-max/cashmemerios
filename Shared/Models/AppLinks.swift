import Foundation

/// The public site, in one place.
///
/// Every page hangs off a single base, so if the site ever moves — a custom
/// domain instead of GitHub Pages, say — one line changes and every link in the
/// app follows. The path is `Cash-Meter`, not `Cash-Memer`; that is how the
/// repository is actually named and it is easy to "correct" by mistake.
enum AppLinks {
    private static let base = "https://wrcovid4-max.github.io/Cash-Meter/"

    /// Shown rather than the full URL, which is too long for a footer row.
    static let displayHost = "wrcovid4-max.github.io/Cash-Meter"

    private static func page(_ file: String) -> URL? {
        URL(string: base + file)
    }

    // Main
    static let home = page("index.html")
    static let download = page("download.html")
    static let news = page("news.html")

    // Platforms
    static let mobile = page("mobile.html")
    static let wearables = page("wearables.html")
    static let spatial = page("spatial.html")
    static let driving = page("driving.html")
    static let languages = page("languages.html")
    static let webApp = page("web-app.html")

    // Support and legal
    static let support = page("support.html")
    static let privacy = page("privacy.html")
    static let terms = page("terms.html")
    static let trademarks = page("trademarks.html")

    /// Machine-readable, so it is not linked from the UI — kept here because it
    /// is part of the site and the next person will look for it.
    static let rss = page("rss.xml")
    static let sitemap = page("sitemap.xml")
}

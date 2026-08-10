import SwiftUI

/// The launch splash, shown over the app for a beat and then faded out.
///
/// Sized per platform rather than scaled from one number: what reads as a
/// confident logo on iPad is overbearing on iPhone and simply will not fit a
/// 40mm watch. `Metrics` picks a set once, from the idiom, and everything else
/// follows from it.
struct SplashView: View {
    /// Nothing about the splash is localised. It is the wordmark and a copyright
    /// line, both of which stay as they are in Urdu.
    private static let title = "Cash Memer"
    private static let credit = "© WR COVID YT 2026"

    private struct Metrics {
        let logo: CGFloat
        let corner: CGFloat
        let titleSize: CGFloat
        let creditSize: CGFloat
        let gap: CGFloat

        #if os(watchOS)
        static let current = Metrics(logo: 54, corner: 12, titleSize: 17, creditSize: 9, gap: 14)
        #else
        static var current: Metrics {
            // Regular width alone would catch a Max iPhone in landscape, so this
            // asks the idiom directly.
            if UIDevice.current.userInterfaceIdiom == .pad {
                return Metrics(logo: 208, corner: 46, titleSize: 52, creditSize: 21, gap: 52)
            }
            return Metrics(logo: 124, corner: 28, titleSize: 34, creditSize: 15, gap: 34)
        }
        #endif
    }

    private let metrics = Metrics.current

    var body: some View {
        ZStack {
            SplashPalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: metrics.logo, height: metrics.logo)
                    .clipShape(RoundedRectangle(cornerRadius: metrics.corner, style: .continuous))

                Spacer().frame(height: metrics.gap)

                Text(Self.title)
                    .font(.system(size: metrics.titleSize, weight: .bold, design: .default))
                    .foregroundColor(SplashPalette.title)

                Spacer().frame(height: metrics.gap * 0.28)

                Text(Self.credit)
                    .font(.system(size: metrics.creditSize, weight: .regular))
                    .foregroundColor(SplashPalette.credit)
            }
            .padding(.horizontal, 16)
            .multilineTextAlignment(.center)
        }
    }
}

/// Fixed colours, sampled from the supplied artwork. Deliberately not theme-aware:
/// the splash is the same in light and dark, as a launch screen has to be — the
/// system draws it before the app can know anything.
enum SplashPalette {
    static let background = Color(red: 0x16 / 255, green: 0x1B / 255, blue: 0x10 / 255)
    static let title = Color(red: 0x3E / 255, green: 0xFF / 255, blue: 0x3E / 255)
    static let credit = Color(red: 0xD2 / 255, green: 0xD2 / 255, blue: 0xD2 / 255)
}

/// Presents `SplashView` over its content until `duration` has passed.
///
/// A modifier rather than a branch in each app's root so iOS, iPadOS and watchOS
/// share one timing and one fade.
struct SplashOverlay: ViewModifier {
    var duration: Double = 1.4

    @State private var isFinished = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if !isFinished {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.35), value: isFinished)
            .task {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                isFinished = true
            }
    }
}

extension View {
    func splashScreen(duration: Double = 1.4) -> some View {
        modifier(SplashOverlay(duration: duration))
    }
}

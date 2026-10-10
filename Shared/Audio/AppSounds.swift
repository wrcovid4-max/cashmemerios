import AVFoundation

/// Spooky sound effects and the background track. Turned on and off by the App sounds setting.
final class AppSounds {
    static let shared = AppSounds()

    enum Kind: String {
        case whoosh = "ghost_whoosh"
        case sting = "scare_sting"
        case chime = "bat_chime"
    }

    private(set) var enabled = true
    private var effects: [Kind: AVAudioPlayer] = [:]
    private var music: AVAudioPlayer?

    private init() {
        // Mix with other audio rather than interrupting it.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    func setEnabled(_ on: Bool) {
        enabled = on && Holiday.halloween
        if !on { stopMusic() }
    }

    func play(_ kind: Kind) {
        guard enabled else { return }
        let player: AVAudioPlayer?
        if let existing = effects[kind] {
            player = existing
        } else {
            player = load(kind.rawValue, ext: "wav")
            effects[kind] = player
        }
        player?.currentTime = 0
        player?.play()
    }

    func startMusic() {
        guard enabled else { return }
        if music == nil {
            music = load("the_cellar_stairs", ext: "mp3")
            music?.numberOfLoops = -1
            music?.volume = 0.35
        }
        if music?.isPlaying == false { music?.play() }
    }

    func pauseMusic() {
        music?.pause()
    }

    func resumeMusic() {
        if enabled { music?.play() }
    }

    func stopMusic() {
        music?.stop()
        music = nil
    }

    private func load(_ name: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }
}

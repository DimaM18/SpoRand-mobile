import AVFoundation
import Foundation

/// Scheduled clip playback on the playback device (brief §5, scheduled
/// source): `AVAudioPlayer.play(atTime:)` mapped through `deviceCurrentTime`.
///
/// Threading: Pigeon invokes the async methods from a main-actor task and the
/// sync ones on the platform (main) thread. Player state is only touched on
/// the main actor.
final class ClipPlayerHost: ClipPlayerApi {
  private var player: AVAudioPlayer?
  private var snippetDuration: TimeInterval = 0
  private var stopWork: DispatchWorkItem?
  private let session = URLSession(configuration: .ephemeral)
  private let cacheDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("sporand_clips", isDirectory: true)

  func prefetch(clipRef: String, clipUrl: String) async throws -> PreloadResultMessage {
    let started = ProcessInfo.processInfo.systemUptime
    do {
      let data = try await download(clipUrl)
      try FileManager.default.createDirectory(
        at: cacheDirectory, withIntermediateDirectories: true)
      try data.write(to: cacheFile(clipRef), options: [.atomic, .completeFileProtection])
      return PreloadResultMessage(ok: true, preloadMs: elapsedMs(since: started))
    } catch {
      return PreloadResultMessage(
        ok: false, preloadMs: elapsedMs(since: started), errorCode: "clip_load_failed")
    }
  }

  func prepare(clip: ClipSourceMessage) async throws -> PreloadResultMessage {
    let started = ProcessInfo.processInfo.systemUptime
    let data: Data
    do {
      if let ref = clip.clipRef, let cached = try? Data(contentsOf: cacheFile(ref)) {
        data = cached
      } else {
        data = try await download(clip.clipUrl)
      }
    } catch {
      return PreloadResultMessage(
        ok: false, preloadMs: elapsedMs(since: started), errorCode: "clip_load_failed")
    }
    let errorCode = await MainActor.run { () -> String? in
      self.releasePlayer()
      do {
        let audio = AVAudioSession.sharedInstance()
        // .playback: audible with the silent switch on; the host phone is the
        // room's speaker.
        try audio.setCategory(.playback, mode: .default, options: [])
        try audio.setActive(true)
        let player = try AVAudioPlayer(data: data)
        player.currentTime = Double(clip.snippetStartMs) / 1000
        guard player.prepareToPlay() else { return "player_error" }
        self.player = player
        self.snippetDuration = Double(clip.snippetDurationMs) / 1000
        return nil
      } catch {
        return "player_error"
      }
    }
    return PreloadResultMessage(
      ok: errorCode == nil, preloadMs: elapsedMs(since: started), errorCode: errorCode)
  }

  func playAt(startAtMonoUs: Int64) async throws -> PlaybackStartedMessage {
    let (startUs, lead) = try await MainActor.run { () throws -> (Int64, TimeInterval) in
      guard let player = self.player else {
        throw NativeBridgeError(code: "not_prepared", message: "prepare() was not called", details: nil)
      }
      // systemUptime (the input clock) and the player's deviceCurrentTime
      // advance at the same rate, so the remaining delay maps 1:1.
      let now = ProcessInfo.processInfo.systemUptime
      let delay = Double(startAtMonoUs) / 1_000_000 - now
      let lead = max(delay, 0)
      guard player.play(atTime: player.deviceCurrentTime + lead) else {
        throw NativeBridgeError(code: "player_error", message: "play(atTime:) failed", details: nil)
      }
      self.scheduleStop(after: lead + self.snippetDuration)
      // A late call starts immediately; report the real start.
      let startUs = delay >= 0 ? startAtMonoUs : Int64((now * 1_000_000).rounded())
      return (startUs, lead)
    }
    if lead > 0 {
      try await Task.sleep(nanoseconds: UInt64(lead * 1_000_000_000))
    }
    return await MainActor.run { () -> PlaybackStartedMessage in
      PlaybackStartedMessage(
        audioStartMonoUs: startUs,
        // Under-reports Bluetooth latency (brief §5); common to all players.
        outputLatencyMs: Int64((AVAudioSession.sharedInstance().outputLatency * 1000).rounded()),
        outputRoute: self.currentRoute())
    }
  }

  func stop() throws {
    releasePlayer()
  }

  func dispose() throws {
    releasePlayer()
    try? FileManager.default.removeItem(at: cacheDirectory)
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func releasePlayer() {
    stopWork?.cancel()
    stopWork = nil
    player?.stop()
    player = nil
  }

  private func scheduleStop(after seconds: TimeInterval) {
    stopWork?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.releasePlayer() }
    stopWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
  }

  private func currentRoute() -> OutputRouteMessage {
    guard let port = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portType else {
      return .other
    }
    switch port {
    case .builtInSpeaker: return .speaker
    case .headphones, .lineOut, .usbAudio: return .wired
    case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP: return .bluetooth
    case .airPlay: return .airplay
    default: return .other
    }
  }

  private func download(_ url: String) async throws -> Data {
    guard let parsed = URL(string: url), parsed.scheme == "https" else {
      throw NativeBridgeError(code: "clip_load_failed", message: "invalid clip url", details: nil)
    }
    let (data, response) = try await session.data(from: parsed)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw NativeBridgeError(code: "clip_load_failed", message: "bad status", details: nil)
    }
    return data
  }

  private func cacheFile(_ clipRef: String) -> URL {
    // clip_ref is an opaque URL-safe token, so it is a safe file name.
    let safe = clipRef.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    return cacheDirectory.appendingPathComponent(safe).appendingPathExtension("clip")
  }

  private func elapsedMs(since start: TimeInterval) -> Int64 {
    return Int64(((ProcessInfo.processInfo.systemUptime - start) * 1000).rounded())
  }
}

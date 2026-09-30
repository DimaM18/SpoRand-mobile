import Foundation

/// iOS has no system "play from search" intent that reaches third-party
/// music apps, so this always answers false and the Dart side opens the
/// cue's `hint_url` instead (addendum A2.2). The app never plays the song.
final class MusicAppHost: MusicAppApi {
  func playFromSearch(search: MusicSearchMessage) throws -> Bool {
    false
  }
}

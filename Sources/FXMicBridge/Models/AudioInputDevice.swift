import CoreAudio

struct AudioInputDevice: Identifiable, Equatable {
    let id: String // Core Audio device UID, stable across reconnects.
    let objectID: AudioDeviceID
    let name: String
    let channelCount: Int
}

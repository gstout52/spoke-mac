import AVFoundation

/// Records the microphone to a small AAC file suitable for upload.
final class Recorder {
    private var recorder: AVAudioRecorder?
    private let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("spoke-dictation.m4a")
    private(set) var startedAt: Date?

    static let maxDuration: TimeInterval = 10 * 60

    func start() throws {
        try? FileManager.default.removeItem(at: fileURL)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
        ]
        let r = try AVAudioRecorder(url: fileURL, settings: settings)
        r.isMeteringEnabled = true
        guard r.record(forDuration: Recorder.maxDuration) else {
            throw SpokeError("Couldn't start the microphone")
        }
        recorder = r
        startedAt = Date()
    }

    /// Stops recording and returns the file, plus how long it ran.
    func stop() -> (URL, TimeInterval)? {
        guard let r = recorder, let started = startedAt else { return nil }
        r.stop()
        recorder = nil
        startedAt = nil
        return (fileURL, Date().timeIntervalSince(started))
    }

    /// Input level from 0 to 1, for the on-screen meter.
    var level: Float {
        guard let r = recorder else { return 0 }
        r.updateMeters()
        let db = r.averagePower(forChannel: 0)  // -160...0
        return max(0, min(1, (db + 50) / 50))
    }

    var elapsed: TimeInterval {
        startedAt.map { Date().timeIntervalSince($0) } ?? 0
    }
}

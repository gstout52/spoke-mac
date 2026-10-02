import Foundation

struct SpokeError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Speech-to-text via a Whisper-style /audio/transcriptions endpoint (Groq or OpenAI).
enum Transcriber {
    static func transcribe(_ audio: URL, settings: Settings) async throws -> String {
        let (endpoint, model): (String, String) = switch settings.provider {
        case .groq: ("https://api.groq.com/openai/v1/audio/transcriptions", "whisper-large-v3-turbo")
        case .openai: ("https://api.openai.com/v1/audio/transcriptions", "gpt-4o-mini-transcribe")
        }
        let key = settings.transcriptionKey
        guard !key.isEmpty else { throw SpokeError("Add a speech-to-text API key in Spoke Settings") }

        let boundary = "spoke-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        field("model", model)
        field("language", "en")
        field("response_format", "json")
        let terms = settings.vocabularyTerms
        if !terms.isEmpty {
            // Whisper uses the prompt as spelling context for names and jargon.
            field("prompt", String(terms.joined(separator: ", ").prefix(800)))
        }
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"dictation.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n")
        body.append(try Data(contentsOf: audio))
        body.append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: URL(string: endpoint)!, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let detail = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw SpokeError("Transcription failed (\(status)): \(detail)")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Data {
    mutating func append(_ string: String) { append(Data(string.utf8)) }
}

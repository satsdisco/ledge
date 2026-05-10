import Foundation
import Vision
import AppKit

/// Runs Vision text recognition on a saved clipboard image off the main
/// thread. The completion fires on the main thread with the recognized
/// text (joined with newlines) or nil if nothing was detected.
enum ClipboardOCR {
    static let queue = DispatchQueue(label: "app.ledge.clipboard.ocr", qos: .utility)

    static func recognize(at url: URL, completion: @escaping (String?) -> Void) {
        queue.async {
            guard let ciImage = CIImage(contentsOf: url) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let request = VNRecognizeTextRequest { req, _ in
                let observations = req.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let joined = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    completion(joined.isEmpty ? nil : joined)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                Log.module.error("Clipboard OCR failed: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}

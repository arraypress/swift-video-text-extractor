//
//  ExtractionProgress.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Progress information reported during video text extraction.
///
/// Sent via the progress callback in ``VideoTextExtractor/extract(from:options:progress:)``.
///
/// ```swift
/// let result = try await VideoTextExtractor.extract(from: url) { progress in
///     print(progress.statusText)  // "Recognizing text: 12/45 frames"
///     progressBar.progress = progress.fraction  // 0.0–1.0
/// }
/// ```
public struct ExtractionProgress: Sendable {

    /// The current processing phase.
    public enum Phase: String, Sendable {
        /// Loading the video asset and inspecting tracks.
        case loading = "Loading"
        /// Setting up the video processor and requests.
        case preparingAnalysis = "Preparing analysis"
        /// Running recognition on extracted frames.
        case recognizingText = "Recognizing text"
        /// Deduplicating and building the timeline.
        case deduplicating = "Deduplicating"
        /// Extraction complete.
        case complete = "Complete"
    }

    /// The current processing phase.
    public let phase: Phase

    /// The number of frames processed so far.
    public let framesProcessed: Int

    /// The total number of frames to process (estimated).
    public let totalFrames: Int

    /// The number of frames skipped (e.g., duplicate timestamps).
    public let framesSkipped: Int

    /// Progress as a fraction (0.0–1.0).
    ///
    /// Based on ``framesProcessed`` relative to ``totalFrames``.
    /// Returns `0` when ``totalFrames`` is zero.
    public var fraction: Double {
        guard totalFrames > 0 else { return 0 }
        return Double(framesProcessed) / Double(totalFrames)
    }

    /// A human-readable status string suitable for display in UI.
    public var statusText: String {
        switch phase {
        case .loading:
            return "Loading video..."
        case .preparingAnalysis:
            return "Preparing analysis..."
        case .recognizingText:
            if totalFrames > 0 {
                return "Recognizing text: \(framesProcessed)/\(totalFrames) frames"
            }
            return "Recognizing text..."
        case .deduplicating:
            return "Deduplicating text..."
        case .complete:
            return "Complete (\(framesProcessed) frames, \(framesSkipped) skipped)"
        }
    }

}

//
//  ExtractionError.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Errors that can occur during video text extraction.
///
/// All errors include a human-readable ``errorDescription`` suitable for
/// display in UI or logging.
///
/// ```swift
/// do {
///     let result = try await VideoTextExtractor.extract(from: videoUrl)
/// } catch ExtractionError.invalidFile {
///     print("Not a valid video file")
/// } catch ExtractionError.noVideoTrack {
///     print("File contains no video track")
/// } catch {
///     print(error.localizedDescription)
/// }
/// ```
public enum ExtractionError: Error, LocalizedError, Equatable, Sendable {

    /// The provided URL does not point to a valid or accessible file.
    case invalidFile

    /// The file contains no video track.
    case noVideoTrack

    /// Could not generate frames from the video.
    ///
    /// The associated string contains a description of the underlying failure.
    case frameGenerationFailed(String)

    /// Text recognition failed during processing.
    ///
    /// The associated string contains a description of the underlying failure.
    case recognitionFailed(String)

    /// The extraction operation was cancelled.
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "Invalid or missing video file."
        case .noVideoTrack:
            return "The file contains no video track."
        case .frameGenerationFailed(let message):
            return "Frame generation failed: \(message)"
        case .recognitionFailed(let message):
            return "Text recognition failed: \(message)"
        case .cancelled:
            return "Extraction was cancelled."
        }
    }

}

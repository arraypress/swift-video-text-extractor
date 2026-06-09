//
//  ExtractionOptions.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import CoreMedia
import Foundation

/// Configuration options for video text extraction.
///
/// Controls frame sampling rate, recognition parameters, deduplication,
/// language settings, barcode detection, and document recognition.
///
/// All options have sensible defaults — you can extract text with no
/// configuration at all:
///
/// ```swift
/// let result = try await VideoTextExtractor.extract(from: url)
/// ```
///
/// Or customise for your use case:
///
/// ```swift
/// let options = ExtractionOptions(
///     frameInterval: 0.5,
///     minimumConfidence: 0.7,
///     languages: ["en-US", "ja-JP"],
///     detectBarcodes: true,
///     enableDocumentRecognition: true
/// )
/// let result = try await VideoTextExtractor.extract(from: url, options: options)
/// ```
public struct ExtractionOptions: Sendable {

    // MARK: - Frame Sampling

    /// The interval in seconds between sampled frames.
    ///
    /// Controls the `VideoProcessor.Cadence` for frame sampling.
    /// Lower values capture more text but take longer to process.
    /// Higher values are faster but may miss text that appears briefly.
    ///
    /// Ignored when ``cadenceMode`` is set to ``CadenceMode/frameInterval(_:)``.
    ///
    /// - `0.5` — Dense sampling, good for fast-changing slides or code demos.
    /// - `1.0` — Default. Balanced for most educational content.
    /// - `2.0` — Sparse sampling, good for slow-paced lectures.
    /// - `5.0` — Very sparse, only for near-static content.
    public var frameInterval: Double

    /// The cadence mode for frame sampling.
    ///
    /// Controls how `VideoProcessor` selects frames to analyse.
    ///
    /// Default is ``CadenceMode/timeInterval`` which uses ``frameInterval``.
    public var cadenceMode: CadenceMode

    /// Maximum number of frames to process.
    ///
    /// Set to `nil` for no limit (process entire video). Useful for
    /// limiting processing time on very long videos.
    ///
    /// Default is `nil`.
    public var maxFrames: Int?

    /// An optional time range to analyse within the video.
    ///
    /// When set, only frames within this range are processed. Useful for
    /// extracting text from a specific segment of a longer video.
    ///
    /// Default is `nil` (analyse the entire video).
    ///
    /// ```swift
    /// // Analyse only from 30s to 90s
    /// let range = CMTimeRange(
    ///     start: CMTime(seconds: 30, preferredTimescale: 600),
    ///     duration: CMTime(seconds: 60, preferredTimescale: 600)
    /// )
    /// let options = ExtractionOptions(timeRange: range)
    /// ```
    public var timeRange: CMTimeRange?

    // MARK: - Text Recognition

    /// Minimum confidence threshold for text recognition (0.0–1.0).
    ///
    /// Text observations below this confidence are discarded. Higher values
    /// reduce noise but may miss faint or stylised text.
    ///
    /// Default is `0.5`.
    public var minimumConfidence: Float

    /// Recognition languages in order of priority.
    ///
    /// Uses BCP 47 language tags. The recogniser will prioritise earlier
    /// languages in the array.
    ///
    /// Default is `["en-US"]`.
    public var languages: [String]

    /// Whether to use accurate (slower) or fast recognition.
    ///
    /// Accurate mode produces better results for small or stylised text
    /// but takes significantly longer per frame. Fast mode is suitable
    /// for large, clear text like slide titles and code.
    ///
    /// Default is `true` (accurate).
    public var useAccurateRecognition: Bool

    /// The similarity threshold for text deduplication (0.0–1.0).
    ///
    /// Text strings with a normalised similarity above this threshold
    /// are merged as duplicates. Accounts for minor OCR variations
    /// across frames (e.g., "Hello World" vs "Hello Worid").
    ///
    /// Default is `0.85`.
    public var textSimilarityThreshold: Double

    // MARK: - Barcode Detection

    /// Whether to detect barcodes and QR codes in video frames.
    ///
    /// When enabled, a `DetectBarcodesRequest` runs in parallel with text
    /// recognition on the same frames via `VideoProcessor`. Detected barcodes
    /// are available via ``VideoTextResult/allBarcodes`` and per-frame via
    /// ``FrameText/barcodes``.
    ///
    /// Default is `false`.
    public var detectBarcodes: Bool

    // MARK: - Document Recognition

    /// Whether to enable structured document recognition.
    ///
    /// When enabled, a `RecognizeDocumentsRequest` runs in parallel with text
    /// recognition on the same frames via `VideoProcessor`. This extracts
    /// tables, lists, paragraphs, titles, and detected data types (URLs,
    /// emails, phone numbers, etc.).
    ///
    /// Results are available via ``VideoTextResult/allTables``,
    /// ``VideoTextResult/allLists``, ``VideoTextResult/uniqueDetectedData``,
    /// and per-frame via ``FrameText/documentContent``.
    ///
    /// Best suited for video content showing physical documents (receipts,
    /// forms, printed tables). Screen-recorded slides may have limited
    /// table/list detection.
    ///
    /// Default is `false`.
    public var enableDocumentRecognition: Bool

    /// Minimum text height relative to image height for document recognition.
    ///
    /// Only used when ``enableDocumentRecognition`` is `true`.
    /// Lower values detect smaller text but may increase false positives.
    ///
    /// Default is `1/32` (0.03125).
    public var minimumTextHeightFraction: Float

    // MARK: - Initialisation

    /// Creates extraction options with the specified parameters.
    ///
    /// All parameters have sensible defaults for general video text extraction.
    ///
    /// - Parameters:
    ///   - frameInterval: Seconds between sampled frames. Default `1.0`.
    ///   - cadenceMode: Frame sampling mode. Default `.timeInterval`.
    ///   - maxFrames: Maximum frames to process. Default `nil`.
    ///   - timeRange: Time range to analyse. Default `nil` (entire video).
    ///   - minimumConfidence: Minimum OCR confidence (0–1). Default `0.5`.
    ///   - languages: Recognition languages. Default `["en-US"]`.
    ///   - useAccurateRecognition: Use accurate mode. Default `true`.
    ///   - textSimilarityThreshold: Text dedup threshold. Default `0.85`.
    ///   - detectBarcodes: Enable barcode/QR detection. Default `false`.
    ///   - enableDocumentRecognition: Enable document structure recognition. Default `false`.
    ///   - minimumTextHeightFraction: Min text height for document mode. Default `1/32`.
    public init(
        frameInterval: Double = 1.0,
        cadenceMode: CadenceMode = .timeInterval,
        maxFrames: Int? = nil,
        timeRange: CMTimeRange? = nil,
        minimumConfidence: Float = 0.5,
        languages: [String] = ["en-US"],
        useAccurateRecognition: Bool = true,
        textSimilarityThreshold: Double = 0.85,
        detectBarcodes: Bool = false,
        enableDocumentRecognition: Bool = false,
        minimumTextHeightFraction: Float = 1.0 / 32.0
    ) {
        self.frameInterval = max(0.1, frameInterval)
        self.cadenceMode = cadenceMode
        self.maxFrames = maxFrames
        self.timeRange = timeRange
        self.minimumConfidence = min(max(minimumConfidence, 0), 1)
        self.languages = languages
        self.useAccurateRecognition = useAccurateRecognition
        self.textSimilarityThreshold = min(max(textSimilarityThreshold, 0), 1)
        self.detectBarcodes = detectBarcodes
        self.enableDocumentRecognition = enableDocumentRecognition
        self.minimumTextHeightFraction = minimumTextHeightFraction
    }

}

// MARK: - Cadence Mode

/// The frame sampling strategy for `VideoProcessor`.
///
/// Controls how frames are selected from the video for analysis.
///
/// ```swift
/// // Time-based: one frame every 0.5 seconds
/// let options = ExtractionOptions(frameInterval: 0.5, cadenceMode: .timeInterval)
///
/// // Frame-based: every 30th frame
/// let options = ExtractionOptions(cadenceMode: .frameInterval(30))
/// ```
public enum CadenceMode: Sendable {

    /// Sample frames at regular time intervals.
    ///
    /// Uses ``ExtractionOptions/frameInterval`` to determine the interval.
    /// This is the default mode and provides consistent sampling regardless
    /// of the video's frame rate.
    case timeInterval

    /// Process every Nth video frame.
    ///
    /// The associated value specifies the frame interval. For example,
    /// `.frameInterval(30)` processes every 30th frame. Useful when you
    /// want sampling tied to the video's actual frame rate.
    ///
    /// - Parameter every: Process every Nth frame. Must be >= 1.
    case frameInterval(_ every: Int)

}

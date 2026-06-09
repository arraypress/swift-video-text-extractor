//
//  VideoTextResult.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The result of extracting text from a video.
///
/// Contains per-frame text data, deduplicated unique texts, a timeline
/// showing when each text appeared and disappeared, and optional barcodes
/// and structured document content.
///
/// ```swift
/// let result = try await VideoTextExtractor.extract(from: videoUrl)
///
/// // All unique text found in the video
/// for text in result.uniqueTexts {
///     print(text)
/// }
///
/// // Timeline of text appearances
/// for appearance in result.timeline {
///     print("[\(appearance.formattedFirstSeen)–\(appearance.formattedLastSeen)] \(appearance.text)")
/// }
///
/// // Plain text dump (great for LLM input)
/// print(result.plainText)
/// ```
public struct VideoTextResult: Sendable {

    /// The video duration in seconds.
    public let videoDuration: Double

    /// Per-frame recognition results.
    ///
    /// Includes all sampled frames in chronological order. Each frame
    /// contains text blocks, optional barcodes, and optional document content.
    public let frames: [FrameText]

    /// All unique text strings found across all frames.
    ///
    /// Deduplicated using the similarity threshold from ``ExtractionOptions``.
    /// Ordered by first appearance time.
    public let uniqueTexts: [String]

    /// Timeline of text appearances in the video.
    ///
    /// Each entry shows when a unique text first appeared, when it was last
    /// seen, how many frames it appeared in, and its average confidence.
    /// Ordered by first appearance time.
    public let timeline: [TextAppearance]

    /// The options used for this extraction.
    public let options: ExtractionOptions

    // MARK: - Frame Statistics

    /// Total number of frames sampled from the video.
    public var totalFrames: Int { frames.count }

    /// Number of frames that were processed (not skipped).
    public var processedFrames: Int { frames.filter { !$0.skipped }.count }

    /// Number of frames skipped (e.g., duplicate timestamps).
    public var skippedFrames: Int { frames.filter(\.skipped).count }

    /// Total number of text blocks across all frames.
    public var totalTextBlocks: Int { frames.flatMap(\.blocks).count }

    // MARK: - Formatted Output

    /// The video duration formatted as `"M:SS"` or `"H:MM:SS"`.
    public var formattedDuration: String {
        let total = Int(videoDuration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// All unique text joined as a single string, separated by newlines.
    ///
    /// Convenient for copying to clipboard or passing to an LLM.
    public var plainText: String {
        uniqueTexts.joined(separator: "\n")
    }

    // MARK: - Barcode Aggregates

    /// All barcodes detected across all frames.
    ///
    /// Only populated when ``ExtractionOptions/detectBarcodes`` is `true`.
    /// Includes duplicates from multiple frames.
    public var allBarcodes: [DetectedBarcode] {
        frames.flatMap(\.barcodes)
    }

    /// Unique barcodes detected across all frames, deduplicated by payload.
    ///
    /// Only populated when ``ExtractionOptions/detectBarcodes`` is `true`.
    public var uniqueBarcodes: [DetectedBarcode] {
        var seen = Set<String>()
        return allBarcodes.filter { barcode in
            let key = "\(barcode.symbology):\(barcode.payload ?? "")"
            return seen.insert(key).inserted
        }
    }

    // MARK: - Document Recognition Aggregates

    /// All tables detected across all frames.
    ///
    /// Only populated when ``ExtractionOptions/enableDocumentRecognition`` is `true`.
    public var allTables: [DocumentTable] {
        frames.compactMap(\.documentContent).flatMap(\.tables)
    }

    /// All lists detected across all frames.
    ///
    /// Only populated when ``ExtractionOptions/enableDocumentRecognition`` is `true`.
    public var allLists: [DocumentList] {
        frames.compactMap(\.documentContent).flatMap(\.lists)
    }

    /// All detected data items (URLs, emails, phone numbers, etc.) across all frames.
    ///
    /// Includes duplicates from multiple frames. Use ``uniqueDetectedData``
    /// for a deduplicated list.
    public var allDetectedData: [DetectedDataItem] {
        frames.compactMap(\.documentContent).flatMap(\.detectedData)
    }

    /// Unique detected data items across all frames, deduplicated by kind and value.
    ///
    /// Only populated when ``ExtractionOptions/enableDocumentRecognition`` is `true`.
    public var uniqueDetectedData: [DetectedDataItem] {
        var seen = Set<String>()
        return allDetectedData.filter { item in
            let key = "\(item.kind.rawValue):\(item.value)"
            return seen.insert(key).inserted
        }
    }

    // MARK: - JSON Export

    /// A compact, JSON-friendly summary of the extraction result.
    ///
    /// Designed for passing to LLMs, APIs, or saving to disk. Contains only
    /// the useful data: plain text, timeline with formatted timestamps,
    /// detected data, barcodes, tables (as 2D string arrays), and lists.
    ///
    /// Excludes bounding boxes, confidence scores, and per-frame detail —
    /// access those directly via ``frames`` if needed.
    struct JSONSummary: Codable, Sendable {

        /// Formatted video duration (e.g., "1:23:45").
        let duration: String

        /// Number of frames processed.
        let frames: Int

        /// All unique text joined with newlines.
        let plainText: String

        /// Timeline showing when each text appeared and disappeared.
        let timeline: [TimelineEntry]

        /// Unique detected data items — URLs, emails, phone numbers, etc.
        let detectedData: [DataEntry]

        /// Unique barcode payloads.
        let barcodes: [String]

        /// Tables as 2D string arrays (rows of cells).
        let tables: [[[String]]]

        /// Lists as arrays of item strings.
        let lists: [[String]]

        /// A single timeline entry with formatted timestamps.
        struct TimelineEntry: Codable, Sendable {
            let text: String
            let from: String
            let to: String
        }

        /// A detected data entry.
        struct DataEntry: Codable, Sendable {
            let type: String
            let value: String
        }
    }

    /// Encodes the result as compact JSON `Data`.
    ///
    /// The output is optimised for LLM consumption — no bounding boxes,
    /// no confidence scores, tables as simple 2D arrays, timestamps
    /// formatted as human-readable strings.
    ///
    /// ```swift
    /// let result = try await VideoTextExtractor.extract(from: url)
    /// let data = try result.jsonData()
    /// ```
    ///
    /// - Parameter prettyPrinted: Whether to format with indentation. Default `true`.
    /// - Returns: UTF-8 encoded JSON data.
    /// - Throws: `EncodingError` if encoding fails.
    public func jsonData(prettyPrinted: Bool = true) throws -> Data {
        let summary = JSONSummary(
            duration: formattedDuration,
            frames: processedFrames,
            plainText: plainText,
            timeline: timeline.map { entry in
                JSONSummary.TimelineEntry(
                    text: entry.text,
                    from: entry.formattedFirstSeen,
                    to: entry.formattedLastSeen
                )
            },
            detectedData: uniqueDetectedData.map { item in
                JSONSummary.DataEntry(type: item.kind.rawValue, value: item.value)
            },
            barcodes: uniqueBarcodes.compactMap(\.payload),
            tables: allTables.map { table in
                table.rows.map { row in row.map(\.text) }
            },
            lists: allLists.map(\.items)
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(summary)
    }

    /// Encodes the result as a compact JSON string.
    ///
    /// ```swift
    /// let result = try await VideoTextExtractor.extract(from: url)
    /// let json = try result.jsonString()
    /// // Send to LLM, save to file, etc.
    /// ```
    ///
    /// - Parameter prettyPrinted: Whether to format with indentation. Default `true`.
    /// - Returns: A JSON string.
    /// - Throws: `EncodingError` if encoding fails.
    public func jsonString(prettyPrinted: Bool = true) throws -> String {
        let data = try jsonData(prettyPrinted: prettyPrinted)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

}

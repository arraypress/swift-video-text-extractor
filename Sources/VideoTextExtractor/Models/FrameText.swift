//
//  FrameText.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// All recognised content from a single video frame.
///
/// Contains the timestamp of the frame within the video, text blocks detected
/// in the frame, optional barcodes, and optional structured document content.
///
/// ```swift
/// for frame in result.frames where !frame.skipped {
///     print("[\(frame.formattedTimestamp)] \(frame.combinedText)")
///     for barcode in frame.barcodes {
///         print("  Barcode: \(barcode.payload ?? "no payload")")
///     }
/// }
/// ```
public struct FrameText: Sendable, Codable {

    /// The timestamp of this frame in seconds from the start of the video.
    public let timestamp: Double

    /// The text blocks recognised in this frame.
    ///
    /// Ordered roughly top-to-bottom, left-to-right based on bounding box
    /// position to approximate natural reading order.
    public let blocks: [TextBlock]

    /// Whether this frame was skipped (e.g., duplicate timestamp).
    ///
    /// When `true`, ``blocks``, ``barcodes``, and ``documentContent``
    /// will be empty/nil.
    public let skipped: Bool

    /// Barcodes and QR codes detected in this frame.
    ///
    /// Only populated when ``ExtractionOptions/detectBarcodes`` is `true`.
    /// Empty array when barcode detection is disabled or no barcodes were found.
    public let barcodes: [DetectedBarcode]

    /// Structured document content recognised in this frame.
    ///
    /// Only populated when ``ExtractionOptions/enableDocumentRecognition`` is `true`.
    /// Contains tables, lists, paragraphs, titles, and detected data types.
    /// Will be `nil` when document recognition is disabled or the frame was skipped.
    public let documentContent: DocumentContent?

    /// Creates a frame text result.
    ///
    /// - Parameters:
    ///   - timestamp: The frame timestamp in seconds.
    ///   - blocks: The recognised text blocks.
    ///   - skipped: Whether this frame was skipped.
    ///   - barcodes: Detected barcodes. Default empty array.
    ///   - documentContent: Structured document content. Default `nil`.
    public init(
        timestamp: Double,
        blocks: [TextBlock],
        skipped: Bool,
        barcodes: [DetectedBarcode] = [],
        documentContent: DocumentContent? = nil
    ) {
        self.timestamp = timestamp
        self.blocks = blocks
        self.skipped = skipped
        self.barcodes = barcodes
        self.documentContent = documentContent
    }

    /// All text in this frame joined as a single string.
    ///
    /// Blocks are joined with newlines, preserving the spatial reading order.
    public var combinedText: String {
        blocks.map(\.text).joined(separator: "\n")
    }

    /// The timestamp formatted as `"M:SS"` or `"H:MM:SS"`.
    public var formattedTimestamp: String {
        let total = Int(timestamp)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

}

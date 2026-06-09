//
//  TextBlock.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A single recognised text region within a video frame.
///
/// Each block represents a contiguous piece of text detected by the OCR engine,
/// with its bounding box coordinates normalised to 0–1 range, a confidence score,
/// and the recognised string.
///
/// Text blocks within a ``FrameText`` are sorted top-to-bottom, left-to-right
/// to approximate natural reading order.
public struct TextBlock: Sendable, Codable {

    /// The recognised text string.
    public let text: String

    /// The recognition confidence (0.0–1.0).
    public let confidence: Float

    /// The bounding box in normalised coordinates (0–1).
    ///
    /// Uses Vision framework conventions with the origin at the bottom-left.
    /// - `x`: Left edge
    /// - `y`: Bottom edge
    /// - `width`: Horizontal extent
    /// - `height`: Vertical extent
    public let boundingBox: CGRect

    /// Creates a text block.
    ///
    /// - Parameters:
    ///   - text: The recognised text string.
    ///   - confidence: The recognition confidence (0.0–1.0).
    ///   - boundingBox: The bounding box in normalised coordinates.
    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case text, confidence, boundingBox
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        confidence = try container.decode(Float.self, forKey: .confidence)
        let rect = try container.decode([String: CGFloat].self, forKey: .boundingBox)
        boundingBox = CGRect(
            x: rect["x"] ?? 0, y: rect["y"] ?? 0,
            width: rect["width"] ?? 0, height: rect["height"] ?? 0
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(confidence, forKey: .confidence)
        try container.encode([
            "x": boundingBox.origin.x,
            "y": boundingBox.origin.y,
            "width": boundingBox.size.width,
            "height": boundingBox.size.height
        ], forKey: .boundingBox)
    }

}

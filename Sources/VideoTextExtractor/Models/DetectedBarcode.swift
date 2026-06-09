//
//  DetectedBarcode.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A barcode or QR code detected within a video frame.
///
/// Populated when ``ExtractionOptions/detectBarcodes`` is `true`. Each barcode
/// includes its symbology type and decoded payload string.
///
/// ```swift
/// let options = ExtractionOptions(detectBarcodes: true)
/// let result = try await VideoTextExtractor.extract(from: url, options: options)
///
/// for barcode in result.allBarcodes {
///     print("\(barcode.symbology): \(barcode.payload ?? "no payload")")
/// }
/// ```
public struct DetectedBarcode: Sendable, Codable {

    /// The barcode symbology (e.g., "qr", "ean13", "code128").
    public let symbology: String

    /// The decoded payload string, if available.
    ///
    /// Most barcodes contain a string payload (URL, product code, etc.).
    /// Some symbologies may not have a decodable string representation.
    public let payload: String?

    /// The bounding box in normalised coordinates (0–1).
    ///
    /// Uses Vision framework conventions with the origin at the bottom-left.
    public let boundingBox: CGRect

    /// Creates a detected barcode.
    ///
    /// - Parameters:
    ///   - symbology: The barcode symbology type.
    ///   - payload: The decoded payload string, if available.
    ///   - boundingBox: The bounding box in normalised coordinates.
    public init(symbology: String, payload: String?, boundingBox: CGRect) {
        self.symbology = symbology
        self.payload = payload
        self.boundingBox = boundingBox
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case symbology, payload, boundingBox
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbology = try container.decode(String.self, forKey: .symbology)
        payload = try container.decodeIfPresent(String.self, forKey: .payload)
        let rect = try container.decode([String: CGFloat].self, forKey: .boundingBox)
        boundingBox = CGRect(
            x: rect["x"] ?? 0, y: rect["y"] ?? 0,
            width: rect["width"] ?? 0, height: rect["height"] ?? 0
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(symbology, forKey: .symbology)
        try container.encodeIfPresent(payload, forKey: .payload)
        try container.encode([
            "x": boundingBox.origin.x,
            "y": boundingBox.origin.y,
            "width": boundingBox.size.width,
            "height": boundingBox.size.height
        ], forKey: .boundingBox)
    }

}

//
//  DocumentContent.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Structured content extracted from a video frame using document recognition.
///
/// Contains tables, lists, paragraphs, barcodes, and detected data types
/// (URLs, emails, phone numbers, etc.) recognised by `RecognizeDocumentsRequest`.
///
/// Only populated when ``ExtractionOptions/enableDocumentRecognition`` is `true`.
///
/// ```swift
/// let options = ExtractionOptions(enableDocumentRecognition: true)
/// let result = try await VideoTextExtractor.extract(from: url, options: options)
///
/// for frame in result.frames where !frame.skipped {
///     if let doc = frame.documentContent {
///         print("Title: \(doc.title ?? "none")")
///         print("Tables: \(doc.tables.count)")
///         print("Lists: \(doc.lists.count)")
///     }
/// }
/// ```
public struct DocumentContent: Sendable, Codable {

    /// The document title, if detected.
    public let title: String?

    /// The full recognised text transcript from the document recogniser.
    public let fullText: String

    /// Individual paragraphs detected in the document.
    ///
    /// Paragraphs group related lines of text together, preserving the
    /// document's logical structure better than raw line-by-line OCR.
    public let paragraphs: [String]

    /// Tables detected in the document.
    ///
    /// Each table contains rows of cells with their text content.
    /// Best suited for content showing physical documents with visible
    /// table structure (grid lines, aligned columns).
    public let tables: [DocumentTable]

    /// Lists detected in the document.
    ///
    /// Ordered or unordered lists with their item text.
    public let lists: [DocumentList]

    /// Barcodes detected by the document recogniser.
    ///
    /// Note: These are barcodes found by `RecognizeDocumentsRequest`, which
    /// may differ from those found by the standalone `DetectBarcodesRequest`
    /// (available via ``FrameText/barcodes``).
    public let barcodes: [DocumentBarcode]

    /// Detected data types found in the text (URLs, emails, phone numbers, etc.).
    ///
    /// The document recogniser automatically identifies structured data within
    /// the recognised text, including URLs, email addresses, phone numbers,
    /// postal addresses, monetary amounts, and more.
    public let detectedData: [DetectedDataItem]

    /// The recognition confidence for the overall document observation (0.0–1.0).
    ///
    /// Note: This value may be `0.0` in current implementations — the document
    /// recogniser reports confidence differently from the text recogniser.
    public let confidence: Float

}

// MARK: - Document Table

/// A table detected within a video frame by document recognition.
///
/// Contains rows of cells, where each cell holds its text content.
///
/// ```swift
/// for table in doc.tables {
///     print("Table (\(table.rowCount)×\(table.columnCount)):")
///     for row in table.rows {
///         let cells = row.map(\.text).joined(separator: " | ")
///         print("  \(cells)")
///     }
/// }
/// ```
public struct DocumentTable: Sendable, Codable {

    /// A single cell within a table row.
    public struct Cell: Sendable, Codable {

        /// The text content of the cell.
        public let text: String
    }

    /// The rows of the table, each containing an array of cells.
    public let rows: [[Cell]]

    /// The number of rows in the table.
    public var rowCount: Int { rows.count }

    /// The number of columns (based on the first row), or 0 if empty.
    public var columnCount: Int { rows.first?.count ?? 0 }

    /// All text in the table as a flat array of strings.
    public var allText: [String] {
        rows.flatMap { $0.map(\.text) }
    }

    /// The table rendered as a tab-separated string.
    ///
    /// Each row is joined by tabs, rows separated by newlines.
    /// Suitable for pasting into spreadsheets.
    public var tsvRepresentation: String {
        rows.map { row in
            row.map(\.text).joined(separator: "\t")
        }.joined(separator: "\n")
    }

}

// MARK: - Document List

/// A list detected within a video frame by document recognition.
///
/// Contains ordered items with their text content.
///
/// ```swift
/// for list in doc.lists {
///     for (index, item) in list.items.enumerated() {
///         print("\(index + 1). \(item)")
///     }
/// }
/// ```
public struct DocumentList: Sendable, Codable {

    /// The text items in the list, in order.
    public let items: [String]

    /// The number of items in the list.
    public var count: Int { items.count }

}

// MARK: - Document Barcode

/// A barcode detected within a video frame by document recognition.
///
/// These barcodes are found by `RecognizeDocumentsRequest` as part of
/// document analysis. For standalone barcode detection, see
/// ``DetectedBarcode`` and ``ExtractionOptions/detectBarcodes``.
public struct DocumentBarcode: Sendable, Codable {

    /// The barcode symbology (e.g., "qr", "ean13", "code128").
    public let symbology: String

    /// The decoded payload string, if available.
    public let payload: String?

}

// MARK: - Detected Data Item

/// A piece of structured data detected within recognised text.
///
/// The Vision document recogniser automatically identifies structured data
/// including URLs, email addresses, phone numbers, postal addresses,
/// monetary amounts, flight numbers, calendar events, tracking numbers,
/// and measurements.
///
/// ```swift
/// for item in result.uniqueDetectedData {
///     print("\(item.kind): \(item.value)")
/// }
/// // url: https://example.com
/// // email: hello@example.com
/// // phoneNumber: +1 (555) 123-4567
/// ```
public struct DetectedDataItem: Sendable, Codable {

    /// The category of detected data.
    public enum Kind: String, Sendable, Codable {

        /// A URL or web link.
        case url

        /// An email address.
        case email

        /// A phone number.
        case phoneNumber

        /// A postal/mailing address.
        case postalAddress

        /// A monetary amount with currency.
        case moneyAmount

        /// An airline flight number.
        case flightNumber

        /// A shipment tracking number.
        case shipmentTracking

        /// A calendar event with date/time.
        case calendarEvent

        /// A physical measurement.
        case measurement

        /// A payment identifier.
        case paymentIdentifier

        /// An unrecognised data type.
        case unknown
    }

    /// The category of this detected data.
    public let kind: Kind

    /// A human-readable string representation of the detected value.
    public let value: String

}

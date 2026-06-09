//
//  DocumentContentBuilder.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import DataDetection
import Vision

/// Converts `DocumentObservation` arrays from `RecognizeDocumentsRequest`
/// into the public ``DocumentContent`` model.
///
/// Aggregates tables, lists, barcodes, paragraphs, detected data, and
/// title across all observations for a single frame.
enum DocumentContentBuilder {

    /// Builds a ``DocumentContent`` from an array of document observations.
    ///
    /// - Parameter observations: The document observations for a single frame.
    /// - Returns: A ``DocumentContent`` containing all structured data.
    static func build(from observations: [DocumentObservation]) -> DocumentContent {
        var allTables: [DocumentTable] = []
        var allLists: [DocumentList] = []
        var allBarcodes: [DocumentBarcode] = []
        var allDetectedData: [DetectedDataItem] = []
        var allParagraphs: [String] = []
        var fullText = ""
        var title: String?
        var bestConfidence: Float = 0

        for observation in observations {
            let doc = observation.document
            bestConfidence = max(bestConfidence, observation.confidence)

            // Title (use first non-empty title found)
            if title == nil {
                let titleTranscript = doc.title?.transcript
                if let t = titleTranscript, !t.isEmpty {
                    title = t
                }
            }

            // Full text
            let textTranscript = doc.text.transcript
            if !textTranscript.isEmpty {
                if !fullText.isEmpty { fullText += "\n" }
                fullText += textTranscript
            }

            // Paragraphs
            for paragraph in doc.paragraphs {
                let pText = paragraph.transcript
                if !pText.isEmpty {
                    allParagraphs.append(pText)
                }
            }

            // Tables
            for table in doc.tables {
                let rows: [[DocumentTable.Cell]] = table.rows.map { row in
                    row.map { cell in
                        DocumentTable.Cell(text: cell.content.text.transcript)
                    }
                }
                if !rows.isEmpty {
                    allTables.append(DocumentTable(rows: rows))
                }
            }

            // Lists
            for list in doc.lists {
                let items = list.items.map { $0.content.text.transcript }
                if !items.isEmpty {
                    allLists.append(DocumentList(items: items))
                }
            }

            // Barcodes
            for barcode in doc.barcodes {
                allBarcodes.append(DocumentBarcode(
                    symbology: String(describing: barcode.symbology),
                    payload: barcode.payloadString
                ))
            }

            // Detected data from all text sources
            collectDetectedData(from: doc, into: &allDetectedData)
        }

        return DocumentContent(
            title: title,
            fullText: fullText,
            paragraphs: allParagraphs,
            tables: allTables,
            lists: allLists,
            barcodes: allBarcodes,
            detectedData: allDetectedData,
            confidence: bestConfidence
        )
    }

    // MARK: - Detected Data Collection

    /// Collects detected data items from all text sources in a document container.
    ///
    /// Scans text, paragraphs, title, table cells, and list items for
    /// structured data like URLs, emails, and phone numbers.
    private static func collectDetectedData(
        from doc: DocumentObservation.Container,
        into items: inout [DetectedDataItem]
    ) {
        let textSources: [DocumentObservation.Container.Text] =
            [doc.text] + doc.paragraphs + (doc.title.map { [$0] } ?? [])

        for textSource in textSources {
            for detected in textSource.detectedData {
                if let item = mapDetectedData(detected) {
                    items.append(item)
                }
            }
        }

        for table in doc.tables {
            for row in table.rows {
                for cell in row {
                    for detected in cell.content.text.detectedData {
                        if let item = mapDetectedData(detected) {
                            items.append(item)
                        }
                    }
                }
            }
        }

        for list in doc.lists {
            for listItem in list.items {
                for detected in listItem.content.text.detectedData {
                    if let item = mapDetectedData(detected) {
                        items.append(item)
                    }
                }
            }
        }
    }

    /// Maps a Vision `DataDetectorMatch` to a ``DetectedDataItem``.
    ///
    /// - Parameter detected: The data detector match from Vision.
    /// - Returns: A ``DetectedDataItem``, or `nil` for unrecognised types.
    private static func mapDetectedData(
        _ detected: DocumentObservation.Container.DataDetectorMatch
    ) -> DetectedDataItem? {
        let match = detected.match

        switch match.details {
        case .link(let link):
            return DetectedDataItem(kind: .url, value: link.url.absoluteString)
        case .emailAddress(let email):
            return DetectedDataItem(kind: .email, value: email.emailAddress)
        case .phoneNumber(let phone):
            return DetectedDataItem(kind: .phoneNumber, value: phone.phoneNumber)
        case .postalAddress(let postal):
            return DetectedDataItem(kind: .postalAddress, value: postal.fullAddress)
        case .moneyAmount(let money):
            return DetectedDataItem(kind: .moneyAmount, value: "\(money.amount) \(money.currency.identifier)")
        case .flightNumber(let flight):
            return DetectedDataItem(kind: .flightNumber, value: "\(flight.airlineCode) \(flight.flightNumber)")
        case .shipmentTrackingNumber(let tracking):
            return DetectedDataItem(kind: .shipmentTracking, value: "\(tracking.carrier) \(tracking.trackingNumber)")
        case .calendarEvent(let calendar):
            var parts: [String] = []
            if let start = calendar.startDate { parts.append("start: \(start)") }
            if let end = calendar.endDate { parts.append("end: \(end)") }
            parts.append("allDay: \(calendar.allDay)")
            return DetectedDataItem(kind: .calendarEvent, value: parts.joined(separator: ", "))
        case .measurement(let measurement):
            return DetectedDataItem(kind: .measurement, value: "\(measurement.value)")
        case .paymentIdentifier(let payment):
            return DetectedDataItem(kind: .paymentIdentifier, value: payment.identifier)
        @unknown default:
            return DetectedDataItem(kind: .unknown, value: "unknown")
        }
    }

}

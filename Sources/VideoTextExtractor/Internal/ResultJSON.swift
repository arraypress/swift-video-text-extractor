//
//  ResultJSON.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//
//  The LLM-friendly JSON shape and its assembly, out of the model. What a
//  result IS lives in VideoTextResult; what its compact export looks like
//  is an encoding rule, and encoding rules live where they can change
//  without touching the model.
//

import Foundation

/// The compact export `VideoTextResult.jsonData()` promises.
enum ResultJSON {

    /// A compact, JSON-friendly summary of an extraction result — plain
    /// text, timeline with formatted timestamps, detected data, barcodes,
    /// tables as 2D string arrays, and lists. No bounding boxes, no
    /// confidence scores.
    struct Summary: Codable, Sendable {
        let duration: String
        let frames: Int
        let plainText: String
        let timeline: [TimelineEntry]
        let detectedData: [DataEntry]
        let barcodes: [String]
        let tables: [[[String]]]
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

    /// The summary of `result`, encoded with snake_case keys and, when
    /// pretty, sorted keys so diffs mean something.
    static func data(for result: VideoTextResult, prettyPrinted: Bool) throws -> Data {
        let summary = Summary(
            duration: result.formattedDuration,
            frames: result.processedFrames,
            plainText: result.plainText,
            timeline: result.timeline.map { entry in
                Summary.TimelineEntry(
                    text: entry.text,
                    from: entry.formattedFirstSeen,
                    to: entry.formattedLastSeen
                )
            },
            detectedData: result.uniqueDetectedData.map { item in
                Summary.DataEntry(type: item.kind.rawValue, value: item.value)
            },
            barcodes: result.uniqueBarcodes.compactMap(\.payload),
            tables: result.allTables.map { table in
                table.rows.map { row in row.map(\.text) }
            },
            lists: result.allLists.map(\.items)
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(summary)
    }
}

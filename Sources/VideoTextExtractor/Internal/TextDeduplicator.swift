//
//  TextDeduplicator.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Deduplicates text strings across video frames using normalised string similarity.
///
/// Handles minor OCR variations between frames (e.g., "Hello World" vs "Hello Worid")
/// by comparing strings using Levenshtein distance normalised to the longer string's length.
enum TextDeduplicator {

    /// A tracked text occurrence across frames.
    struct TrackedText {
        let canonicalText: String
        var firstSeen: Double
        var lastSeen: Double
        var frameCount: Int
        var totalConfidence: Float
    }

    /// Builds a deduplicated timeline from per-frame text data.
    ///
    /// For each text block in each frame, checks if a sufficiently similar
    /// text has already been tracked. If so, updates its last-seen time.
    /// Otherwise, creates a new tracked entry.
    ///
    /// - Parameters:
    ///   - frames: The per-frame text data.
    ///   - threshold: Similarity threshold (0–1). Texts above this are merged.
    /// - Returns: A tuple of unique texts (ordered by first appearance) and
    ///   a timeline of ``TextAppearance`` entries.
    static func deduplicate(
        frames: [FrameText],
        threshold: Double
    ) -> (uniqueTexts: [String], timeline: [TextAppearance]) {
        var tracked: [TrackedText] = []

        for frame in frames where !frame.skipped {
            for block in frame.blocks {
                let normalized = block.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !normalized.isEmpty else { continue }

                if let index = findMatch(for: normalized, in: tracked, threshold: threshold) {
                    tracked[index].lastSeen = frame.timestamp
                    tracked[index].frameCount += 1
                    tracked[index].totalConfidence += block.confidence
                } else {
                    tracked.append(TrackedText(
                        canonicalText: normalized,
                        firstSeen: frame.timestamp,
                        lastSeen: frame.timestamp,
                        frameCount: 1,
                        totalConfidence: block.confidence
                    ))
                }
            }
        }

        let uniqueTexts = tracked.map(\.canonicalText)
        let timeline = tracked.map { entry in
            TextAppearance(
                text: entry.canonicalText,
                firstSeen: entry.firstSeen,
                lastSeen: entry.lastSeen,
                frameCount: entry.frameCount,
                averageConfidence: entry.totalConfidence / Float(entry.frameCount)
            )
        }

        return (uniqueTexts, timeline)
    }

    /// Finds a matching tracked text entry using normalised similarity.
    private static func findMatch(
        for text: String,
        in tracked: [TrackedText],
        threshold: Double
    ) -> Int? {
        var bestIndex: Int?
        var bestSimilarity: Double = 0

        for (index, entry) in tracked.enumerated() {
            let similarity = Self.similarity(text, entry.canonicalText)
            if similarity > bestSimilarity && similarity >= threshold {
                bestSimilarity = similarity
                bestIndex = index
            }
        }

        return bestIndex
    }

    /// Computes normalised similarity between two strings (0–1).
    ///
    /// Uses Levenshtein distance normalised to the length of the longer string.
    /// Returns 1.0 for identical strings, 0.0 for completely different strings.
    static func similarity(_ a: String, _ b: String) -> Double {
        let aChars = Array(a)
        let bChars = Array(b)
        let aLen = aChars.count
        let bLen = bChars.count

        guard aLen > 0 && bLen > 0 else { return 0 }
        if a == b { return 1.0 }

        var matrix = Array(repeating: Array(repeating: 0, count: bLen + 1), count: aLen + 1)
        for i in 0...aLen { matrix[i][0] = i }
        for j in 0...bLen { matrix[0][j] = j }

        for i in 1...aLen {
            for j in 1...bLen {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        let distance = matrix[aLen][bLen]
        let maxLen = max(aLen, bLen)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

}

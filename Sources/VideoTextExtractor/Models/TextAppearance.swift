//
//  TextAppearance.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A unique text string and the time range during which it was visible.
///
/// Tracks the first and last appearance of a deduplicated text string across
/// all processed frames. Useful for understanding when specific content
/// (formulas, code, slide titles) was on screen.
///
/// ```swift
/// for appearance in result.timeline {
///     print("[\(appearance.formattedFirstSeen)–\(appearance.formattedLastSeen)] \(appearance.text)")
/// }
/// // [0:05–0:32] E = mc²
/// // [0:33–1:15] def fibonacci(n):
/// ```
public struct TextAppearance: Sendable, Codable {

    /// The deduplicated text string.
    public let text: String

    /// The timestamp (in seconds) when this text first appeared.
    public let firstSeen: Double

    /// The timestamp (in seconds) when this text was last seen.
    public let lastSeen: Double

    /// The number of frames in which this text was detected.
    public let frameCount: Int

    /// The average recognition confidence across all appearances.
    public let averageConfidence: Float

    /// The duration this text was visible, in seconds.
    ///
    /// Based on the difference between ``lastSeen`` and ``firstSeen``.
    /// A value of `0` means the text was only seen in a single frame.
    public var duration: Double {
        lastSeen - firstSeen
    }

    /// The first-seen timestamp formatted as `"M:SS"` or `"H:MM:SS"`.
    public var formattedFirstSeen: String {
        Self.formatTime(firstSeen)
    }

    /// The last-seen timestamp formatted as `"M:SS"` or `"H:MM:SS"`.
    public var formattedLastSeen: String {
        Self.formatTime(lastSeen)
    }

    /// The duration formatted as `"M:SS"` or `"H:MM:SS"`.
    public var formattedDuration: String {
        Self.formatTime(duration)
    }

    /// Formats a time interval as a human-readable string.
    ///
    /// - Parameter seconds: Time in seconds.
    /// - Returns: Formatted string as `"M:SS"` or `"H:MM:SS"`.
    private static func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

}

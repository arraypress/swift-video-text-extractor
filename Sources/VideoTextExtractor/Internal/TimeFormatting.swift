//
//  TimeFormatting.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//
//  The one clock format every model shows — "M:SS" under an hour,
//  "H:MM:SS" over it. It existed three times, once per model that wanted
//  a readable timestamp, which is exactly how two of them drift apart.
//

import Foundation

/// Timestamps as people read them.
enum TimeFormatting {

    /// `seconds` as `"M:SS"`, or `"H:MM:SS"` from one hour up.
    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

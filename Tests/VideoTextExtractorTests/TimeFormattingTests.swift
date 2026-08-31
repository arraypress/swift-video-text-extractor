//
//  TimeFormattingTests.swift
//  VideoTextExtractorTests
//
//  Created by David Sherlock on 2026.
//
//  The clock format pinned directly. It used to exist three times, once
//  per model that wanted a readable timestamp; now it exists once, and a
//  test reaches it without constructing a frame.
//

import XCTest
@testable import VideoTextExtractor

final class TimeFormattingTests: XCTestCase {

    func testClockPinsBothFormats() {
        XCTAssertEqual(TimeFormatting.clock(0), "0:00")
        XCTAssertEqual(TimeFormatting.clock(5.9), "0:05")
        XCTAssertEqual(TimeFormatting.clock(61), "1:01")
        XCTAssertEqual(TimeFormatting.clock(3599), "59:59")
        XCTAssertEqual(TimeFormatting.clock(3600), "1:00:00")
        XCTAssertEqual(TimeFormatting.clock(7325), "2:02:05")
    }
}

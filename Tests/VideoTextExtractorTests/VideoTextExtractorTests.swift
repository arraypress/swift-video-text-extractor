//
//  VideoTextExtractorTests.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import XCTest
import os
@testable import VideoTextExtractor

final class VideoTextExtractorTests: XCTestCase {

    // MARK: - ExtractionOptions

    func testDefaultOptions() {
        let options = ExtractionOptions()
        XCTAssertEqual(options.frameInterval, 1.0)
        XCTAssertEqual(options.minimumConfidence, 0.5)
        XCTAssertEqual(options.languages, ["en-US"])
        XCTAssertTrue(options.useAccurateRecognition)
        XCTAssertEqual(options.textSimilarityThreshold, 0.85)
        XCTAssertNil(options.maxFrames)
        XCTAssertNil(options.timeRange)
        XCTAssertFalse(options.detectBarcodes)
        XCTAssertFalse(options.enableDocumentRecognition)
    }

    func testOptionsClamping() {
        let options = ExtractionOptions(
            frameInterval: -1,
            minimumConfidence: 1.5,
            textSimilarityThreshold: 2.0
        )
        XCTAssertEqual(options.frameInterval, 0.1)
        XCTAssertEqual(options.minimumConfidence, 1.0)
        XCTAssertEqual(options.textSimilarityThreshold, 1.0)
    }

    func testOptionsCustomValues() {
        let options = ExtractionOptions(
            frameInterval: 0.5,
            minimumConfidence: 0.7,
            languages: ["en-US", "ja-JP"],
            useAccurateRecognition: false,
            detectBarcodes: true,
            enableDocumentRecognition: true
        )
        XCTAssertEqual(options.frameInterval, 0.5)
        XCTAssertEqual(options.minimumConfidence, 0.7)
        XCTAssertEqual(options.languages, ["en-US", "ja-JP"])
        XCTAssertFalse(options.useAccurateRecognition)
        XCTAssertTrue(options.detectBarcodes)
        XCTAssertTrue(options.enableDocumentRecognition)
    }

    // MARK: - Text Deduplication

    func testExactDuplicateDedup() {
        let frames = [
            FrameText(timestamp: 0.0, blocks: [
                TextBlock(text: "Hello World", confidence: 0.9, boundingBox: .zero)
            ], skipped: false),
            FrameText(timestamp: 1.0, blocks: [
                TextBlock(text: "Hello World", confidence: 0.95, boundingBox: .zero)
            ], skipped: false),
            FrameText(timestamp: 2.0, blocks: [
                TextBlock(text: "Hello World", confidence: 0.85, boundingBox: .zero)
            ], skipped: false),
        ]
        let (uniqueTexts, timeline) = TextDeduplicator.deduplicate(frames: frames, threshold: 0.85)
        XCTAssertEqual(uniqueTexts.count, 1)
        XCTAssertEqual(uniqueTexts.first, "Hello World")
        XCTAssertEqual(timeline.first?.firstSeen, 0.0)
        XCTAssertEqual(timeline.first?.lastSeen, 2.0)
        XCTAssertEqual(timeline.first?.frameCount, 3)
    }

    func testNearDuplicateDedup() {
        let frames = [
            FrameText(timestamp: 0.0, blocks: [
                TextBlock(text: "Hello World", confidence: 0.9, boundingBox: .zero)
            ], skipped: false),
            FrameText(timestamp: 1.0, blocks: [
                TextBlock(text: "Hello Worid", confidence: 0.8, boundingBox: .zero)
            ], skipped: false),
        ]
        let (uniqueTexts, timeline) = TextDeduplicator.deduplicate(frames: frames, threshold: 0.85)
        XCTAssertEqual(uniqueTexts.count, 1, "Near-duplicates should be merged")
        XCTAssertEqual(timeline.first?.frameCount, 2)
    }

    func testDifferentTextsNotDeduped() {
        let frames = [
            FrameText(timestamp: 0.0, blocks: [
                TextBlock(text: "Chapter 1: Introduction", confidence: 0.9, boundingBox: .zero)
            ], skipped: false),
            FrameText(timestamp: 5.0, blocks: [
                TextBlock(text: "Chapter 2: Methods", confidence: 0.9, boundingBox: .zero)
            ], skipped: false),
        ]
        let (uniqueTexts, _) = TextDeduplicator.deduplicate(frames: frames, threshold: 0.85)
        XCTAssertEqual(uniqueTexts.count, 2)
    }

    func testSkippedFramesIgnored() {
        let frames = [
            FrameText(timestamp: 0.0, blocks: [
                TextBlock(text: "Hello", confidence: 0.9, boundingBox: .zero)
            ], skipped: false),
            FrameText(timestamp: 1.0, blocks: [], skipped: true),
            FrameText(timestamp: 2.0, blocks: [
                TextBlock(text: "World", confidence: 0.9, boundingBox: .zero)
            ], skipped: false),
        ]
        let (uniqueTexts, _) = TextDeduplicator.deduplicate(frames: frames, threshold: 0.85)
        XCTAssertEqual(uniqueTexts, ["Hello", "World"])
    }

    func testEmptyFrames() {
        let (uniqueTexts, timeline) = TextDeduplicator.deduplicate(frames: [], threshold: 0.85)
        XCTAssertTrue(uniqueTexts.isEmpty)
        XCTAssertTrue(timeline.isEmpty)
    }

    func testEmptyTextBlocksIgnored() {
        let frames = [
            FrameText(timestamp: 0.0, blocks: [
                TextBlock(text: "   ", confidence: 0.9, boundingBox: .zero),
                TextBlock(text: "", confidence: 0.9, boundingBox: .zero),
                TextBlock(text: "Hello", confidence: 0.9, boundingBox: .zero),
            ], skipped: false),
        ]
        let (uniqueTexts, _) = TextDeduplicator.deduplicate(frames: frames, threshold: 0.85)
        XCTAssertEqual(uniqueTexts, ["Hello"])
    }

    // MARK: - String Similarity

    func testSimilarityIdentical() {
        XCTAssertEqual(TextDeduplicator.similarity("Hello", "Hello"), 1.0)
    }

    func testSimilarityEmpty() {
        XCTAssertEqual(TextDeduplicator.similarity("", ""), 0.0)
        XCTAssertEqual(TextDeduplicator.similarity("Hello", ""), 0.0)
    }

    func testSimilarityOneCharDifference() {
        XCTAssertGreaterThan(TextDeduplicator.similarity("Hello World", "Hello Worid"), 0.85)
    }

    func testSimilarityCompleteDifference() {
        XCTAssertLessThan(TextDeduplicator.similarity("ABCDEF", "123456"), 0.2)
    }

    func testSimilarityPartialOverlap() {
        let sim = TextDeduplicator.similarity("Chapter 1: Introduction", "Chapter 2: Methods")
        XCTAssertGreaterThan(sim, 0.3)
        XCTAssertLessThan(sim, 0.85)
    }

    // MARK: - FrameText

    func testFrameTextCombinedText() {
        let frame = FrameText(timestamp: 5.0, blocks: [
            TextBlock(text: "Line 1", confidence: 0.9, boundingBox: .zero),
            TextBlock(text: "Line 2", confidence: 0.85, boundingBox: .zero),
            TextBlock(text: "Line 3", confidence: 0.8, boundingBox: .zero),
        ], skipped: false)
        XCTAssertEqual(frame.combinedText, "Line 1\nLine 2\nLine 3")
    }

    func testFrameTextFormattedTimestamp() {
        XCTAssertEqual(FrameText(timestamp: 0, blocks: [], skipped: false).formattedTimestamp, "0:00")
        XCTAssertEqual(FrameText(timestamp: 65, blocks: [], skipped: false).formattedTimestamp, "1:05")
        XCTAssertEqual(FrameText(timestamp: 3661, blocks: [], skipped: false).formattedTimestamp, "1:01:01")
    }

    func testFrameTextDefaults() {
        let frame = FrameText(timestamp: 0, blocks: [], skipped: false)
        XCTAssertNil(frame.documentContent)
        XCTAssertTrue(frame.barcodes.isEmpty)
    }

    // MARK: - TextAppearance

    func testTextAppearanceDuration() {
        let a = TextAppearance(text: "Hello", firstSeen: 5.0, lastSeen: 15.0, frameCount: 10, averageConfidence: 0.9)
        XCTAssertEqual(a.duration, 10.0)
        XCTAssertEqual(a.formattedFirstSeen, "0:05")
        XCTAssertEqual(a.formattedLastSeen, "0:15")
        XCTAssertEqual(a.formattedDuration, "0:10")
    }

    func testTextAppearanceSingleFrame() {
        let a = TextAppearance(text: "Flash", firstSeen: 3.0, lastSeen: 3.0, frameCount: 1, averageConfidence: 0.95)
        XCTAssertEqual(a.duration, 0.0)
    }

    // MARK: - VideoTextResult

    func testResultStatistics() {
        let frames = [
            FrameText(timestamp: 0.0, blocks: [
                TextBlock(text: "A", confidence: 0.9, boundingBox: .zero),
                TextBlock(text: "B", confidence: 0.8, boundingBox: .zero),
            ], skipped: false),
            FrameText(timestamp: 1.0, blocks: [], skipped: true),
            FrameText(timestamp: 2.0, blocks: [
                TextBlock(text: "C", confidence: 0.9, boundingBox: .zero),
            ], skipped: false),
        ]
        let result = VideoTextResult(videoDuration: 3.0, frames: frames, uniqueTexts: ["A", "B", "C"], timeline: [], options: ExtractionOptions())
        XCTAssertEqual(result.totalFrames, 3)
        XCTAssertEqual(result.processedFrames, 2)
        XCTAssertEqual(result.skippedFrames, 1)
        XCTAssertEqual(result.totalTextBlocks, 3)
        XCTAssertEqual(result.formattedDuration, "0:03")
        XCTAssertEqual(result.plainText, "A\nB\nC")
    }

    func testResultFormattedDurationHours() {
        let result = VideoTextResult(videoDuration: 7261, frames: [], uniqueTexts: [], timeline: [], options: ExtractionOptions())
        XCTAssertEqual(result.formattedDuration, "2:01:01")
    }

    // MARK: - ExtractionProgress

    func testProgressFraction() {
        let p = ExtractionProgress(phase: .recognizingText, framesProcessed: 5, totalFrames: 10, framesSkipped: 2)
        XCTAssertEqual(p.fraction, 0.5, accuracy: 0.001)
    }

    func testProgressFractionZeroTotal() {
        let p = ExtractionProgress(phase: .loading, framesProcessed: 0, totalFrames: 0, framesSkipped: 0)
        XCTAssertEqual(p.fraction, 0.0)
    }

    func testProgressStatusTexts() {
        XCTAssertEqual(ExtractionProgress(phase: .loading, framesProcessed: 0, totalFrames: 0, framesSkipped: 0).statusText, "Loading video...")
        XCTAssertEqual(ExtractionProgress(phase: .preparingAnalysis, framesProcessed: 0, totalFrames: 30, framesSkipped: 0).statusText, "Preparing analysis...")
        XCTAssertEqual(ExtractionProgress(phase: .recognizingText, framesProcessed: 12, totalFrames: 45, framesSkipped: 3).statusText, "Recognizing text: 12/45 frames")
        XCTAssertEqual(ExtractionProgress(phase: .deduplicating, framesProcessed: 45, totalFrames: 45, framesSkipped: 10).statusText, "Deduplicating text...")
        XCTAssertEqual(ExtractionProgress(phase: .complete, framesProcessed: 45, totalFrames: 45, framesSkipped: 10).statusText, "Complete (45 frames, 10 skipped)")
    }

    // MARK: - Error Descriptions

    func testAllErrorsHaveDescriptions() {
        let errors: [ExtractionError] = [.invalidFile, .noVideoTrack, .frameGenerationFailed("timeout"), .recognitionFailed("bad image"), .cancelled]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testErrorEquatable() {
        XCTAssertEqual(ExtractionError.invalidFile, .invalidFile)
        XCTAssertNotEqual(ExtractionError.invalidFile, .noVideoTrack)
    }

    // MARK: - Extract Validation

    func testExtractInvalidFileThrows() async {
        let fakeUrl = URL(fileURLWithPath: "/tmp/nonexistent_video_\(UUID().uuidString).mp4")
        do {
            _ = try await VideoTextExtractor.extract(from: fakeUrl)
            XCTFail("Should have thrown")
        } catch let error as ExtractionError {
            XCTAssertEqual(error, .invalidFile)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Integration (requires example.mov in Resources)

    func testExtractFromVideo() async throws {
        guard let url = Bundle.module.url(forResource: "example", withExtension: "mov", subdirectory: "Resources") else {
            print("Skipping: example.mov not found in test resources")
            return
        }

        let options = ExtractionOptions(frameInterval: 1.0, minimumConfidence: 0.5)
        let progressCount = OSAllocatedUnfairLock(initialState: 0)
        let lastPhase = OSAllocatedUnfairLock<ExtractionProgress.Phase?>(initialState: nil)

        let result = try await VideoTextExtractor.extract(from: url, options: options) { progress in
            progressCount.withLock { $0 += 1 }
            lastPhase.withLock { $0 = progress.phase }
        }

        XCTAssertGreaterThan(result.videoDuration, 0)
        XCTAssertGreaterThan(result.totalFrames, 0)
        XCTAssertGreaterThanOrEqual(result.processedFrames, 1)
        XCTAssertGreaterThan(result.uniqueTexts.count, 0)
        XCTAssertFalse(result.plainText.isEmpty)
        XCTAssertEqual(result.timeline.count, result.uniqueTexts.count)
        XCTAssertGreaterThan(progressCount.withLock { $0 }, 0)
        XCTAssertEqual(lastPhase.withLock { $0 }, .complete)

        print("\n=== TEXT EXTRACTION RESULTS ===")
        print("Duration: \(result.formattedDuration)")
        print("Frames: \(result.totalFrames) total, \(result.processedFrames) processed, \(result.skippedFrames) skipped")
        print("Unique texts: \(result.uniqueTexts.count)")
        print("\n--- TIMELINE ---")
        for entry in result.timeline {
            print("[\(entry.formattedFirstSeen)-\(entry.formattedLastSeen)] (\(entry.frameCount)x, \(String(format: "%.0f%%", entry.averageConfidence * 100))) \(entry.text)")
        }
        print("\n--- PLAIN TEXT ---")
        print(result.plainText)
        print("====================================\n")
    }

    func testExtractWithAllFeatures() async throws {
        guard let url = Bundle.module.url(forResource: "example", withExtension: "mov", subdirectory: "Resources") else {
            print("Skipping: example.mov not found in test resources")
            return
        }

        let options = ExtractionOptions(
            frameInterval: 1.0, minimumConfidence: 0.5,
            detectBarcodes: true, enableDocumentRecognition: true,
            minimumTextHeightFraction: 1.0 / 64.0
        )

        let result = try await VideoTextExtractor.extract(from: url, options: options)

        XCTAssertGreaterThan(result.videoDuration, 0)
        XCTAssertGreaterThan(result.totalFrames, 0)
        XCTAssertGreaterThan(result.uniqueTexts.count, 0)

        let framesWithDocs = result.frames.filter { $0.documentContent != nil }
        XCTAssertGreaterThan(framesWithDocs.count, 0, "Should have documentContent")

        print("\n=== FULL FEATURE RESULTS ===")
        print("Duration: \(result.formattedDuration)")
        print("Frames: \(result.totalFrames), Processed: \(result.processedFrames), Skipped: \(result.skippedFrames)")
        print("Unique texts: \(result.uniqueTexts.count)")
        print("Frames with documentContent: \(framesWithDocs.count)")

        print("\n--- PER-FRAME ---")
        for frame in result.frames where !frame.skipped {
            var parts = ["[\(frame.formattedTimestamp)]"]
            if !frame.barcodes.isEmpty { parts.append("Barcodes: \(frame.barcodes.count)") }
            if let doc = frame.documentContent {
                if let title = doc.title { parts.append("Title: \(title)") }
                parts.append("P:\(doc.paragraphs.count) T:\(doc.tables.count) L:\(doc.lists.count) D:\(doc.detectedData.count)")
            }
            print(parts.joined(separator: " | "))
        }

        print("\n--- BARCODES (\(result.uniqueBarcodes.count) unique) ---")
        for b in result.uniqueBarcodes { print("  \(b.symbology): \(b.payload ?? "")") }

        print("\n--- TABLES (\(result.allTables.count)) ---")
        for (i, t) in result.allTables.enumerated() { print("  Table \(i+1): \(t.rowCount)x\(t.columnCount)") }

        print("\n--- LISTS (\(result.allLists.count)) ---")
        for (i, l) in result.allLists.enumerated() { print("  List \(i+1): \(l.items.joined(separator: " | "))") }

        print("\n--- DETECTED DATA (\(result.uniqueDetectedData.count) unique) ---")
        for item in result.uniqueDetectedData { print("  [\(item.kind.rawValue)] \(item.value)") }

        print("\n--- PLAIN TEXT ---")
        print(result.plainText)

        // Test JSON export
        let jsonData = try result.jsonData()
        XCTAssertGreaterThan(jsonData.count, 0, "JSON data should not be empty")

        let jsonString = try result.jsonString()
        XCTAssertTrue(jsonString.contains("plain_text"), "JSON should contain plain_text key")
        XCTAssertTrue(jsonString.contains("timeline"), "JSON should contain timeline key")
        XCTAssertTrue(jsonString.contains("detected_data"), "JSON should contain detected_data key")
        XCTAssertFalse(jsonString.contains("bounding_box"), "JSON should NOT contain bounding boxes")

        // Write JSON to Desktop for inspection
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let jsonFile = desktop.appendingPathComponent("extraction_result.json")
        try jsonData.write(to: jsonFile)
        print("\n--- JSON written to: \(jsonFile.path) (\(jsonData.count) bytes) ---")
        print("====================================\n")
    }

}

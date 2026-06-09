//
//  VideoTextExtractor.swift
//  VideoTextExtractor
//
//  Created by David Sherlock on 2026.
//

import AVFoundation
import CoreMedia
import Vision

/// Extract text, barcodes, and structured document content from video frames
/// using on-device OCR.
///
/// `VideoTextExtractor` uses Apple's `VideoProcessor` to sample frames at
/// configurable intervals, streams Vision recognition results via `AsyncSequence`,
/// deduplicates the results, and returns a structured timeline of all content found.
///
/// No network access, no third-party dependencies, no API keys. Uses the Vision
/// framework's `RecognizeTextRequest`, `DetectBarcodesRequest`, and
/// `RecognizeDocumentsRequest` streamed through `VideoProcessor`.
///
/// ## Quick Start
///
/// ```swift
/// import VideoTextExtractor
///
/// let result = try await VideoTextExtractor.extract(from: videoUrl)
///
/// // All unique text found
/// for text in result.uniqueTexts {
///     print(text)
/// }
///
/// // Plain text dump (great for LLM input)
/// print(result.plainText)
/// ```
///
/// ## With All Features
///
/// ```swift
/// let options = ExtractionOptions(
///     frameInterval: 0.5,
///     minimumConfidence: 0.7,
///     languages: ["en-US", "ja-JP"],
///     detectBarcodes: true,
///     enableDocumentRecognition: true
/// )
///
/// let result = try await VideoTextExtractor.extract(from: videoUrl, options: options)
///
/// // Text
/// print(result.plainText)
///
/// // Barcodes
/// for barcode in result.uniqueBarcodes {
///     print("\(barcode.symbology): \(barcode.payload ?? "")")
/// }
///
/// // Detected data (URLs, emails, phones)
/// for item in result.uniqueDetectedData {
///     print("\(item.kind): \(item.value)")
/// }
/// ```
///
/// ## With Progress
///
/// ```swift
/// let result = try await VideoTextExtractor.extract(from: videoUrl) { progress in
///     print(progress.statusText)
///     progressBar.progress = progress.fraction
/// }
/// ```
public enum VideoTextExtractor {

    /// Extracts text, barcodes, and document content from a local video file.
    ///
    /// Uses `VideoProcessor` to sample frames at the configured cadence, then
    /// streams recognition results from up to three parallel Vision requests:
    ///
    /// - `RecognizeTextRequest` — always active, provides text blocks with
    ///   confidence and bounding boxes for deduplication and timeline.
    /// - `DetectBarcodesRequest` — when ``ExtractionOptions/detectBarcodes``
    ///   is `true`, detects QR codes, EAN, Code128, and other barcode types.
    /// - `RecognizeDocumentsRequest` — when
    ///   ``ExtractionOptions/enableDocumentRecognition`` is `true`, extracts
    ///   tables, lists, paragraphs, titles, and detected data types.
    ///
    /// All requests run in parallel on the same frames — enabling barcode
    /// or document recognition adds no extra frame processing cost.
    ///
    /// - Parameters:
    ///   - url: A local file URL pointing to a video file.
    ///   - options: Extraction configuration. Default is ``ExtractionOptions()``.
    ///   - progress: An optional callback reporting extraction progress.
    /// - Throws: ``ExtractionError`` if the video cannot be processed.
    /// - Returns: A ``VideoTextResult`` containing all extracted content.
    public static func extract(
        from url: URL,
        options: ExtractionOptions = ExtractionOptions(),
        progress: (@Sendable (ExtractionProgress) -> Void)? = nil
    ) async throws -> VideoTextResult {

        // MARK: Validate

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExtractionError.invalidFile
        }

        progress?(ExtractionProgress(
            phase: .loading, framesProcessed: 0, totalFrames: 0, framesSkipped: 0
        ))

        let asset = AVURLAsset(url: url)
        let duration: Double

        do {
            let cmDuration = try await asset.load(.duration)
            duration = CMTimeGetSeconds(cmDuration)
        } catch {
            throw ExtractionError.invalidFile
        }

        guard duration > 0 else {
            throw ExtractionError.noVideoTrack
        }

        let videoTracks: [AVAssetTrack]
        do {
            videoTracks = try await asset.loadTracks(withMediaType: .video)
        } catch {
            throw ExtractionError.noVideoTrack
        }

        guard !videoTracks.isEmpty else {
            throw ExtractionError.noVideoTrack
        }

        // MARK: Configure VideoProcessor

        let cadence: VideoProcessor.Cadence = switch options.cadenceMode {
        case .timeInterval:
            .timeInterval(CMTime(seconds: options.frameInterval, preferredTimescale: 600))
        case .frameInterval(let every):
            .frameInterval(max(1, every))
        }

        let estimatedFrames = min(
            Int(duration / options.frameInterval) + 1,
            options.maxFrames ?? Int.max
        )

        progress?(ExtractionProgress(
            phase: .preparingAnalysis, framesProcessed: 0,
            totalFrames: estimatedFrames, framesSkipped: 0
        ))

        let processor = VideoProcessor(url)

        // MARK: Add Text Request (always)

        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = options.useAccurateRecognition ? .accurate : .fast
        textRequest.recognitionLanguages = options.languages.map { Locale.Language(identifier: $0) }
        textRequest.usesLanguageCorrection = true

        let textStream = try await processor.addRequest(textRequest, cadence: cadence)

        // MARK: Add Barcode Request (optional)

        var barcodeStream: (any AsyncSequence)?
        if options.detectBarcodes {
            let barcodeRequest = DetectBarcodesRequest()
            barcodeStream = try await processor.addRequest(barcodeRequest, cadence: cadence)
        }

        // MARK: Add Document Request (optional)

        var docStream: (any AsyncSequence)?
        if options.enableDocumentRecognition {
            var docRequest = RecognizeDocumentsRequest()
            docRequest.barcodeDetectionOptions.enabled = true
            docRequest.barcodeDetectionOptions.coalesceCompositeSymbologies = true
            docRequest.barcodeDetectionOptions.symbologies = docRequest.supportedBarcodeSymbologies
            docRequest.textRecognitionOptions.automaticallyDetectLanguage = true
            docRequest.textRecognitionOptions.maximumCandidateCount = 1
            docRequest.textRecognitionOptions.minimumTextHeightFraction = options.minimumTextHeightFraction
            docRequest.textRecognitionOptions.useLanguageCorrection = true

            docStream = try await processor.addRequest(docRequest, cadence: cadence)
        }

        // MARK: Start Analysis

        if let timeRange = options.timeRange {
            processor.startAnalysis(of: timeRange)
        } else {
            processor.startAnalysis()
        }

        // MARK: Collect Text Results

        var textFrames: [(timestamp: Double, blocks: [TextBlock])] = []
        var framesProcessed = 0
        var framesSkipped = 0
        var lastTimestamp: Double = -1

        for try await observations in textStream {
            try Task.checkCancellation()

            let timestamp: Double = observations.first
                .flatMap(\.timeRange)
                .map { CMTimeGetSeconds($0.start) } ?? 0

            // Skip duplicate timestamps
            if abs(timestamp - lastTimestamp) < 0.05 {
                framesSkipped += 1
                continue
            }
            lastTimestamp = timestamp

            framesProcessed += 1
            if let max = options.maxFrames, framesProcessed > max { break }

            let blocks = Self.textBlocks(
                from: observations,
                minimumConfidence: options.minimumConfidence
            )

            textFrames.append((timestamp: timestamp, blocks: blocks))

            progress?(ExtractionProgress(
                phase: .recognizingText,
                framesProcessed: framesProcessed,
                totalFrames: estimatedFrames,
                framesSkipped: framesSkipped
            ))
        }

        // MARK: Collect Barcode Results

        var barcodeFrames: [Double: [DetectedBarcode]] = [:]
        if let stream = barcodeStream as? any AsyncSequence<[BarcodeObservation], any Error> {
            for try await observations in stream {
                let timestamp: Double = observations.first
                    .flatMap(\.timeRange)
                    .map { CMTimeGetSeconds($0.start) } ?? 0

                if barcodeFrames[timestamp] == nil {
                    let barcodes: [DetectedBarcode] = observations.map { obs in
                        DetectedBarcode(
                            symbology: String(describing: obs.symbology),
                            payload: obs.payloadString,
                            boundingBox: obs.boundingBox.cgRect
                        )
                    }
                    barcodeFrames[timestamp] = barcodes
                }
            }
        }

        // MARK: Collect Document Results

        var docFrames: [Double: DocumentContent] = [:]
        if let stream = docStream as? any AsyncSequence<[DocumentObservation], any Error> {
            for try await observations in stream {
                guard let first = observations.first else { continue }
                let timestamp: Double = first.timeRange
                    .map { CMTimeGetSeconds($0.start) } ?? 0

                if docFrames[timestamp] == nil {
                    docFrames[timestamp] = DocumentContentBuilder.build(from: observations)
                }
            }
        }

        // Cancel processor if we hit maxFrames
        if let max = options.maxFrames, framesProcessed >= max {
            await processor.cancel()
        }

        // MARK: Merge Results

        let frameResults: [FrameText] = textFrames.map { frame in
            FrameText(
                timestamp: frame.timestamp,
                blocks: frame.blocks,
                skipped: false,
                barcodes: barcodeFrames[frame.timestamp] ?? [],
                documentContent: docFrames[frame.timestamp]
            )
        }

        // MARK: Deduplicate

        progress?(ExtractionProgress(
            phase: .deduplicating,
            framesProcessed: framesProcessed,
            totalFrames: framesProcessed,
            framesSkipped: framesSkipped
        ))

        let (uniqueTexts, timeline) = TextDeduplicator.deduplicate(
            frames: frameResults,
            threshold: options.textSimilarityThreshold
        )

        progress?(ExtractionProgress(
            phase: .complete,
            framesProcessed: framesProcessed,
            totalFrames: framesProcessed,
            framesSkipped: framesSkipped
        ))

        return VideoTextResult(
            videoDuration: duration,
            frames: frameResults,
            uniqueTexts: uniqueTexts,
            timeline: timeline,
            options: options
        )
    }

    // MARK: - Private Helpers

    /// Converts `RecognizedTextObservation` array to sorted `TextBlock` array.
    ///
    /// Filters by minimum confidence and sorts top-to-bottom, left-to-right.
    ///
    /// - Parameters:
    ///   - observations: The text observations from Vision.
    ///   - minimumConfidence: Minimum confidence threshold.
    /// - Returns: Sorted array of text blocks.
    private static func textBlocks(
        from observations: [RecognizedTextObservation],
        minimumConfidence: Float
    ) -> [TextBlock] {
        observations.compactMap { observation in
            guard observation.confidence >= minimumConfidence else { return nil }

            return TextBlock(
                text: observation.transcript,
                confidence: observation.confidence,
                boundingBox: observation.boundingBox.cgRect
            )
        }.sorted { a, b in
            // Sort top-to-bottom, left-to-right (Vision origin is bottom-left)
            let aTop = 1.0 - a.boundingBox.origin.y - a.boundingBox.height
            let bTop = 1.0 - b.boundingBox.origin.y - b.boundingBox.height
            if abs(aTop - bTop) > 0.02 { return aTop < bTop }
            return a.boundingBox.origin.x < b.boundingBox.origin.x
        }
    }

}

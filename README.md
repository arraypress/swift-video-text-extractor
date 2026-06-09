# Swift Video Text Extractor

Extract text, barcodes, and structured document content from video frames using on-device OCR. No network access, no third-party dependencies, no API keys — pure Vision framework.

Built on Apple's `VideoProcessor` for efficient frame sampling with parallel `RecognizeTextRequest`, `DetectBarcodesRequest`, and `RecognizeDocumentsRequest` streams.

## Features

- 🎯 **Simple API** — extract text with a single async call
- 🔤 **On-device OCR** — Vision `RecognizeTextRequest` streamed through `VideoProcessor`
- 📱 **QR & barcode detection** — `DetectBarcodesRequest` runs in parallel on the same frames
- 📄 **Document recognition** — tables, lists, barcodes, and data detection via `RecognizeDocumentsRequest`
- 🔗 **Detected data** — automatic extraction of URLs, emails, phone numbers, dates, money, and more
- ⏱️ **Timestamped results** — know exactly when each text appeared and disappeared
- 🧹 **Smart deduplication** — merges identical/near-identical text across frames
- 📊 **Progress reporting** — real-time callbacks for UI integration
- ⚡ **Configurable** — frame interval, time range, confidence threshold, languages, max frames
- 🍎 **Cross-platform** — macOS 26+, iOS 26+, tvOS 26+
- 🔒 **Zero dependencies** — Vision + AVFoundation only

## Requirements

- macOS 26.0+ / iOS 26.0+ / tvOS 26.0+
- Swift 6.0+
- Xcode 26.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-video-text-extractor.git", from: "2.0.0")
]
```

## Usage

### Basic Extraction

```swift
import VideoTextExtractor

let result = try await VideoTextExtractor.extract(from: videoUrl)

// All unique text found in the video
for text in result.uniqueTexts {
    print(text)
}

// Plain text dump (great for LLM input)
print(result.plainText)
```

### Timeline

See when each text appeared and disappeared:

```swift
for entry in result.timeline {
    print("[\(entry.formattedFirstSeen)–\(entry.formattedLastSeen)] \(entry.text)")
}
// [0:05–0:32] E = mc²
// [0:33–1:15] def fibonacci(n):
```

### Custom Options

```swift
let options = ExtractionOptions(
    frameInterval: 0.5,              // Sample every 0.5s
    minimumConfidence: 0.7,          // Only high-confidence text
    languages: ["en-US", "ja-JP"],   // Multi-language
    useAccurateRecognition: true,    // Accurate mode (slower but better)
    maxFrames: 200                   // Cap processing time
)

let result = try await VideoTextExtractor.extract(from: videoUrl, options: options)
```

### Barcode & QR Code Detection

```swift
let options = ExtractionOptions(detectBarcodes: true)
let result = try await VideoTextExtractor.extract(from: videoUrl, options: options)

// Unique barcodes found across all frames
for barcode in result.uniqueBarcodes {
    print("\(barcode.symbology): \(barcode.payload ?? "")")
}

// Per-frame barcodes
for frame in result.frames where !frame.barcodes.isEmpty {
    print("[\(frame.formattedTimestamp)] Found \(frame.barcodes.count) barcodes")
}
```

### Document Recognition

Extract structured content — tables, lists, and detected data types like URLs, emails, and phone numbers:

```swift
let options = ExtractionOptions(enableDocumentRecognition: true)
let result = try await VideoTextExtractor.extract(from: videoUrl, options: options)

// Tables
for table in result.allTables {
    print("Table (\(table.rowCount)×\(table.columnCount)):")
    print(table.tsvRepresentation)
}

// Lists
for list in result.allLists {
    for item in list.items { print("• \(item)") }
}

// Detected data (URLs, emails, phone numbers, etc.)
for item in result.uniqueDetectedData {
    print("\(item.kind): \(item.value)")
}
```

### All Features Together

```swift
let options = ExtractionOptions(
    frameInterval: 0.5,
    detectBarcodes: true,
    enableDocumentRecognition: true
)

let result = try await VideoTextExtractor.extract(from: videoUrl, options: options)

print(result.plainText)                    // Text
print(result.uniqueBarcodes.count)         // Barcodes
print(result.uniqueDetectedData.count)     // URLs, emails, phones
print(result.allTables.count)              // Tables
print(result.allLists.count)               // Lists
```

### Time Range Analysis

Analyse only a specific segment of a video:

```swift
let range = CMTimeRange(
    start: CMTime(seconds: 30, preferredTimescale: 600),
    duration: CMTime(seconds: 60, preferredTimescale: 600)
)
let options = ExtractionOptions(timeRange: range)
let result = try await VideoTextExtractor.extract(from: videoUrl, options: options)
```

### Frame Interval Cadence

Sample every Nth frame instead of time-based intervals:

```swift
let options = ExtractionOptions(cadenceMode: .frameInterval(30))  // Every 30th frame
let result = try await VideoTextExtractor.extract(from: videoUrl, options: options)
```

### JSON Export

Export the entire result as JSON — perfect for sending to LLMs, APIs, or saving to disk:

```swift
let result = try await VideoTextExtractor.extract(from: videoUrl, options: options)

// Get JSON string
let json = try result.jsonString()
print(json)

// Get JSON Data (for API requests, file saving, etc.)
let data = try result.jsonData()

// Compact JSON (no indentation)
let compact = try result.jsonData(prettyPrinted: false)
```

The JSON includes video metadata, deduplicated text with timeline, per-frame detail (text blocks, barcodes, document content), and all detected structured data. Keys use `snake_case` formatting.

### Progress Reporting

```swift
let result = try await VideoTextExtractor.extract(from: videoUrl) { progress in
    print(progress.statusText)
    progressBar.progress = progress.fraction
}
```

### Error Handling

```swift
do {
    let result = try await VideoTextExtractor.extract(from: videoUrl)
} catch ExtractionError.invalidFile {
    print("File not found or not a valid video")
} catch ExtractionError.noVideoTrack {
    print("File contains no video track")
} catch ExtractionError.cancelled {
    print("Extraction was cancelled")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

## How It Works

`VideoProcessor` manages the entire pipeline — frame sampling, request execution, and result streaming:

```
VideoProcessor(url)
  ├─ RecognizeTextRequest      → Text blocks with confidence + bounding boxes
  ├─ DetectBarcodesRequest     → QR codes, EAN, Code128, etc. (optional)
  ├─ RecognizeDocumentsRequest → Tables, lists, detected data (optional)
  └─ startAnalysis()
       └─ Frames sampled once, fanned out to all requests in parallel
```

Results are streamed via `AsyncSequence`, deduplicated using Levenshtein distance, and merged into a unified `VideoTextResult` with per-frame detail and aggregate properties.

## Models

| Property | Type | Description |
|----------|------|-------------|
| `videoDuration` | `Double` | Video duration in seconds |
| `frames` | `[FrameText]` | Per-frame text, barcodes, and document content |
| `uniqueTexts` | `[String]` | Deduplicated texts, ordered by appearance |
| `timeline` | `[TextAppearance]` | When each text appeared/disappeared |
| `plainText` | `String` | All unique text joined with newlines |
| `uniqueBarcodes` | `[DetectedBarcode]` | Deduplicated barcodes |
| `allTables` | `[DocumentTable]` | Tables from document mode |
| `allLists` | `[DocumentList]` | Lists from document mode |
| `uniqueDetectedData` | `[DetectedDataItem]` | Deduplicated URLs, emails, phones, etc. |

## Use Cases

- **Educational videos** — Extract formulas, code, slide text from lectures
- **Tutorial content** — Capture terminal commands, URLs, configuration snippets
- **Presentation archival** — Pull slide content from recorded talks
- **QR code extraction** — Find QR codes and barcodes in product videos
- **Accessibility** — Make on-screen text searchable and available as plain text
- **Content indexing** — Build searchable indexes of video libraries
- **Document scanning** — Extract structured data from videos of receipts, forms, labels

## Testing

```bash
swift test
```

Unit tests cover options validation, deduplication logic, similarity scoring, model formatting, and error handling. Integration tests require a local video file (`example.mov`) in the test resources directory.

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2026.

# Swift Video Text Extractor

Extract text, barcodes, and structured document content from video frames using on-device OCR. `VideoTextExtractor` samples frames at configurable intervals with Apple's `VideoProcessor`, streams Vision recognition results, deduplicates them, and returns a structured timeline of everything found on screen. No network access, no third-party dependencies, no API keys — pure Vision framework.

## Features

- 🎯 **On-device OCR** — recognises text from video frames using Vision's `RecognizeTextRequest`, fully offline
- ⏱️ **Configurable sampling** — sample by time interval or every Nth frame, with optional max-frame and time-range limits
- 🔁 **Smart deduplication** — merges near-identical OCR results across frames using a similarity threshold
- 📅 **Appearance timeline** — tracks when each unique text first/last appeared, how many frames it spanned, and its average confidence
- 📦 **Barcode & QR detection** — optional `DetectBarcodesRequest` runs in parallel on the same frames
- 📄 **Document recognition** — optional `RecognizeDocumentsRequest` extracts tables, lists, paragraphs, titles, and detected data
- 🔍 **Detected data types** — pulls URLs, emails, phone numbers, addresses, money amounts, and more out of recognised text
- 📊 **Progress reporting** — optional callback with phase, frame counts, fraction complete, and a ready-to-display status string
- 🌍 **Multi-language** — set recognition languages with BCP 47 tags; choose fast or accurate recognition
- 🧾 **LLM-friendly export** — `plainText` and compact JSON output strip bounding boxes/confidence for direct model input
- ⚡ **Single-pass efficiency** — text, barcode, and document requests all run on the same sampled frames
- 🚫 **Cancellable** — respects `Task` cancellation and honours `maxFrames`

## Requirements

- macOS 26.0+ / iOS 26.0+ / tvOS 26.0+
- Swift 6.2+
- Xcode 26.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-video-text-extractor.git", from: "1.0.0")
]
```

## Usage

### Quick start

```swift
import VideoTextExtractor

let result = try await VideoTextExtractor.extract(from: videoUrl)

// All unique text found
for text in result.uniqueTexts {
    print(text)
}

// Plain text dump (great for LLM input)
print(result.plainText)
```

### With all features

```swift
import VideoTextExtractor

let options = ExtractionOptions(
    frameInterval: 0.5,
    minimumConfidence: 0.7,
    languages: ["en-US", "ja-JP"],
    detectBarcodes: true,
    enableDocumentRecognition: true
)

let result = try await VideoTextExtractor.extract(from: videoUrl, options: options)

// Barcodes
for barcode in result.uniqueBarcodes {
    print("\(barcode.symbology): \(barcode.payload ?? "")")
}

// Detected data (URLs, emails, phones)
for item in result.uniqueDetectedData {
    print("\(item.kind): \(item.value)")
}

// Tables and lists from document recognition
for table in result.allTables {
    print(table.tsvRepresentation)
}
```

### Timeline of appearances

```swift
import VideoTextExtractor

let result = try await VideoTextExtractor.extract(from: videoUrl)

for appearance in result.timeline {
    print("[\(appearance.formattedFirstSeen)–\(appearance.formattedLastSeen)] \(appearance.text)")
}
// [0:05–0:32] E = mc²
// [0:33–1:15] def fibonacci(n):
```

### With progress

```swift
import VideoTextExtractor

let result = try await VideoTextExtractor.extract(from: videoUrl) { progress in
    print(progress.statusText)          // "Recognizing text: 12/45 frames"
    progressBar.progress = progress.fraction
}
```

### JSON export for LLMs

```swift
import VideoTextExtractor

let result = try await VideoTextExtractor.extract(from: videoUrl)
let json = try result.jsonString()      // compact, no bounding boxes or confidence
```

## How It Works

1. The video asset is loaded and its duration/tracks validated.
2. A `VideoProcessor` samples frames at the configured cadence (`.timeInterval` using `frameInterval`, or `.frameInterval(n)`).
3. A `RecognizeTextRequest` always runs; `DetectBarcodesRequest` and `RecognizeDocumentsRequest` are added in parallel when their options are enabled. All three analyse the same sampled frames.
4. Recognition results stream back via `AsyncSequence`; duplicate timestamps are skipped, text blocks are filtered by confidence and sorted into reading order.
5. Per-frame text, barcodes, and document content are merged by timestamp into `FrameText` values.
6. Text is deduplicated using the similarity threshold to produce `uniqueTexts` and a `TextAppearance` timeline.

## Models

| Type | Description |
|------|-------------|
| `VideoTextResult` | Top-level result: frames, unique texts, timeline, aggregates (`allBarcodes`, `uniqueBarcodes`, `allTables`, `allLists`, `uniqueDetectedData`), and JSON export |
| `ExtractionOptions` | Configuration: frame interval, cadence mode, max frames, time range, confidence, languages, accurate vs fast, dedup threshold, barcode/document toggles |
| `ExtractionProgress` | Phase, frames processed/total/skipped, `fraction`, and `statusText` |
| `FrameText` | A single frame's timestamp, text blocks, barcodes, and document content |
| `TextBlock` | One recognised text region: text, confidence, normalised bounding box |
| `TextAppearance` | A unique text with first/last seen, frame count, average confidence, and duration |
| `DetectedBarcode` | Barcode symbology, payload, and bounding box |
| `DocumentContent` | Title, full text, paragraphs, tables, lists, barcodes, and detected data |
| `DetectedDataItem` | A detected data value and its `Kind` (url, email, phoneNumber, postalAddress, moneyAmount, …) |
| `ExtractionError` | `invalidFile`, `noVideoTrack`, `frameGenerationFailed`, `recognitionFailed`, `cancelled` |

## Use Cases

- Extracting slide text, code, or formulas from lecture and tutorial recordings
- Indexing screen recordings for search
- Reading receipts, forms, and printed tables captured on video
- Pulling URLs, emails, and phone numbers shown on screen
- Feeding video content to an LLM as plain text or compact JSON

## Testing

```bash
swift test
```

The test suite exercises extraction options, deduplication, barcode and document recognition, and the result aggregates against bundled video resources.

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2026.

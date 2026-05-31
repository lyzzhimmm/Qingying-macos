# Qingying — macOS Open Source

**Tired of your photos turning blurry after posting to social media?**


---

## Features

### 🚀 High-Quality Batch Resizing

Built on Apple's vImage rendering engine with a 16-bit float (Float16) processing pipeline, preserving color depth and reducing banding when scaling down large images.

- Supports JPG, PNG, PSD, HEIC, WebP, TIFF and more
- PNG transparent channel preservation
- Adjustable output quality (50%–100%)

### 🎞️ Batch Film Frame Overlay

4 built-in film frame styles based on real film scans, covering 2:3 and 3:4 aspect ratios:

| Asset | Ratio | Style |
|-------|-------|-------|
| filmk32 | 2:3 | With film name |
| filmk32B | 2:3 | With exposure info |
| filmk645 | 3:4 | With film name |
| filmk645B | 3:4 | With exposure info |

### 💧 Batch Watermark Overlay

- Import custom PNG watermarks
- 6 preset positions (4 corners + top/bottom center)
- Custom drag-to-position support
- Adjustable size (5%–200%) and opacity (20%–100%)

### 🏞️ Multi-Format Support

JPG, PNG, TIF, PSD and more. PNG preserves transparent channels.

### 🔐 Local Processing

All processing happens on your machine — no cloud upload, no privacy concerns. Native Apple Silicon optimization for fast parallel batch processing.

---

## Usage

### Option 1: Download Pre-built App

1. Download the latest release from [Releases](https://github.com/lyzzhimmm/ResizeJpg-open-source/releases)
2. Open the `.dmg` and drag 「轻影」 to your Applications folder
3. On first launch, you may need to allow it in System Settings → Privacy & Security

### Option 2: Build from Source

1. Clone the repository
   ```bash
   git clone https://github.com/lyzzhimmm/ResizeJpg-open-source.git
   ```
2. Open `无损缩图Pro.xcodeproj` in Xcode
3. Select Target → `ResizeJpg` and build

### Quick Start

1. Open 轻影
2. Set the "Short Edge" size (default 2000px, ideal for Instagram/WeChat)
3. Optionally enable watermark or film frame overlay
4. Drag in your photos to start batch processing
5. Processed images are saved to a "无损缩图小图" folder next to the source files

---

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (for building from source)

## Tech Stack

- Swift 5.9+
- SwiftUI
- Accelerate (vImage) — 16-bit high-precision image scaling
- Core Graphics / ImageIO — image I/O and rendering

## Project Structure

```
├── ProfessionalImageProcessor.swift  # Image processing engine (resize + watermark + film frame)
├── ContentView.swift                 # Main UI
├── ResizeJpgApp.swift                # App entry point
├── Assets.xcassets/                  # App icons
├── kuang/                            # Built-in film frame assets
│   ├── filmk32.png                   # 2:3 with film name
│   ├── filmk32B.png                  # 2:3 with exposure info
│   ├── filmk645.png                  # 3:4 with film name
│   └── filmk645B.png                 # 3:4 with exposure info
├── 无损缩图Pro.xcodeproj             # Xcode project
├── README.md
└── LICENSE
```


## License

[MIT License](LICENSE)

## Author

**胶仔阿志** — Xiaohongshu: 胶仔阿志

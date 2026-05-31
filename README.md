# 轻影 (ResizeJpg) - 开源版

macOS 无损批量缩图工具，支持 16-bit vImage 高精度缩放、水印叠加和胶片框叠加。

## 功能

- **16-bit vImage 缩放** — 保留色彩精度的高质量图片缩放
- **水印叠加** — 支持预设位置和自定义位置，可调透明度和大小
- **胶片框叠加** — 4 种内置胶片框样式，自动匹配比例
- **批量处理** — 拖入多张图片并行处理
- **多格式支持** — JPEG、PNG、PSD、HEIC、WebP、TIFF

## 系统要求

- macOS 13.0 (Ventura) 或更高
- Xcode 15+ (如需编译)

## 使用方法

1. 打开 Xcode，打开 `ResizeJpg.xcodeproj`
2. 选择 Target → `ResizeJpg`，编译运行
3. 拖入图片即可开始缩图

或直接使用 Release 构建的 App。

## 技术栈

- Swift 5.9+
- SwiftUI
- Accelerate (vImage)
- Core Graphics / ImageIO

## 许可证

[MIT License](LICENSE)

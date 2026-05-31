# 轻影 Qingying — macOS 开源版

**每次修完图，一发小红书/朋友圈就变糊？细节没了，色彩也变差？**


---

## 功能亮点

### 🚀 高画质批量缩放

基于 Apple vImage 渲染引擎，使用 16-bit 浮点（Float16）处理管线，缩图时尽量保留原始色彩深度，减少色阶断层，让大图缩小后依然细节扎实、过渡顺滑。

- 支持 JPG、PNG、PSD、HEIC、WebP、TIFF 等常见格式
- PNG 可保留透明通道
- 输出质量可调（50%–100%）

### 🎞️ 批量胶片框

内置 4 款基于真实胶片扫描的胶片框，覆盖 2:3 和 3:4 两种常用比例：

| 素材 | 比例 | 风格 |
|------|------|------|
| filmk32 | 2:3 | 含胶卷名 |
| filmk32B | 2:3 | 含曝光参数 |
| filmk645 | 3:4 | 含胶卷名 |
| filmk645B | 3:4 | 含曝光参数 |

### 💧 批量水印叠加

- 支持导入自定义 PNG 水印
- 6 种预设位置（四角 + 上下居中）
- 支持自定义拖动定位
- 可调节大小（5%–200%）和透明度（20%–100%）

### 🏞️ 多格式支持

支持 JPG、PNG、TIF、PSD 等常见格式，PNG 可保留透明通道。

### 🔐 本地高速处理

图片在本机处理，不上传云端，隐私安全。原生适配 Apple M 系列芯片，并行极速处理，批量大图导出也极快。

---

## 使用方法

### 方法一：直接使用 App

1. 从 [Releases](https://github.com/lyzzhimmm/ResizeJpg-open-source/releases) 下载最新版本
2. 打开 `.dmg`，将「轻影」拖入 Applications 文件夹
3. 首次打开可能需要在「系统设置 → 隐私与安全性」中允许运行

### 方法二：从源码编译

1. 克隆仓库
   ```bash
   git clone https://github.com/lyzzhimmm/ResizeJpg-open-source.git
   ```
2. 打开 Xcode，打开 `无损缩图Pro.xcodeproj`
3. 选择 Target → `ResizeJpg`，编译运行

### 快速使用

1. 打开轻影
2. 设置「短边」尺寸（默认 2000px，适合小红书/朋友圈）
3. 可选：开启水印或胶片框
4. 拖入图片即可开始批量处理
5. 处理后的图片保存在源文件同目录下的「无损缩图小图」文件夹

---

## 系统要求

- macOS 13.0 (Ventura) 或更高
- Xcode 15+（如需编译）

## 技术栈

- Swift 5.9+
- SwiftUI
- Accelerate (vImage) — 16-bit 高精度图片缩放
- Core Graphics / ImageIO — 图片读写与渲染

## 项目结构

```
├── ProfessionalImageProcessor.swift  # 图片处理引擎（缩放+水印+胶片框）
├── ContentView.swift                 # 主界面
├── ResizeJpgApp.swift                # App 入口
├── Assets.xcassets/                  # 图标资源
├── kuang/                            # 内置胶片框素材
│   ├── filmk32.png                   # 2:3 含胶卷名
│   ├── filmk32B.png                  # 2:3 含曝光参数
│   ├── filmk645.png                  # 3:4 含胶卷名
│   └── filmk645B.png                 # 3:4 含曝光参数
├── 无损缩图Pro.xcodeproj             # Xcode 工程
├── README.md
└── LICENSE
```


## 许可证

[MIT License](LICENSE)

## 作者

**胶仔阿志** — 小红书：胶仔阿志

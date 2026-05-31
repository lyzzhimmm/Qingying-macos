import SwiftUI
import Accelerate
import ImageIO
import UniformTypeIdentifiers
import IOKit
import Foundation
import AppKit
internal import Combine

enum WatermarkPositionPreset: String, CaseIterable, Identifiable {
    case topLeft
    case topCenter
    case topRight
    case bottomLeft
    case bottomCenter
    case bottomRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft: return "左上"
        case .topCenter: return "上中"
        case .topRight: return "右上"
        case .bottomLeft: return "左下"
        case .bottomCenter: return "下中"
        case .bottomRight: return "右下"
        }
    }
}

private enum FilmFrameSource: String {
    case builtin
    case custom
}

private enum FilmFrameBuiltinStyle: String {
    case filmName
    case exposureInfo

    var title: String {
        switch self {
        case .filmName: return "含胶卷名"
        case .exposureInfo: return "含曝光参数"
        }
    }
}

private struct FilmFrameRatio: Equatable {
    let shortSide: Int
    let longSide: Int

    var text: String {
        "\(shortSide):\(longSide)"
    }

    var value: CGFloat {
        CGFloat(shortSide) / CGFloat(max(longSide, 1))
    }
}

enum ResizeAppSettings {
    static let suiteName = "com.jiaoziazh.ResizePro"
    static let store = UserDefaults(suiteName: suiteName)
    static var defaults: UserDefaults { store ?? .standard }

    static let defaultFolderName = "无损缩图小图"
    static let defaultShortEdge: Double = 2000
    static let defaultCompressionQuality: Double = 0.95
    static let defaultWatermarkScalePercent: Double = 20.0
    static let defaultWatermarkOpacity: Double = 1.0
    static let defaultOpenOutputFolderAfterExport = true
    static let watermarkEdgeMarginRatio: CGFloat = 0.025

    enum Key {
        static let targetShortEdge = "TargetShortEdge"
        static let customFolderName = "customFolderName"
        static let openOutputFolderAfterExport = "openOutputFolderAfterExport"
        static let compressionQuality = "compressionQuality"
        static let watermarkEnabled = "watermarkEnabled"
        static let watermarkApplyToQuickAction = "watermarkApplyToQuickAction"
        static let watermarkFilePath = "watermarkFilePath"
        static let watermarkPreviewFilePath = "watermarkPreviewFilePath"
        static let watermarkPositionPreset = "watermarkPositionPreset"
        static let watermarkCustomXRatio = "watermarkCustomXRatio"
        static let watermarkCustomYRatio = "watermarkCustomYRatio"
        static let watermarkScalePercent = "watermarkScalePercent"
        static let watermarkOpacity = "watermarkOpacity"
        static let filmFrameEnabled = "filmFrameEnabled"
        static let filmFrameApplyToQuickAction = "filmFrameApplyToQuickAction"
        static let filmFramePreviewFilePath = "filmFramePreviewFilePath"
        static let filmFrameCustomFilePath = "filmFrameCustomFilePath"
        static let filmFrameSelectedRatio = "filmFrameSelectedRatio"
        static let filmFrameSource = "filmFrameSource"
        static let filmFrameBuiltinStyle = "filmFrameBuiltinStyle"
    }

    static func savedCompressionQuality() -> Double {
        guard defaults.object(forKey: Key.compressionQuality) != nil else {
            return defaultCompressionQuality
        }
        let value = defaults.double(forKey: Key.compressionQuality)
        return min(max(value, 0.5), 1.0)
    }

    static func outputFolderName() -> String {
        let savedName = defaults.string(forKey: Key.customFolderName)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let savedName, !savedName.isEmpty {
            return savedName
        }
        return defaultFolderName
    }

    static func savedOpenOutputFolderAfterExport() -> Bool {
        guard defaults.object(forKey: Key.openOutputFolderAfterExport) != nil else {
            return defaultOpenOutputFolderAfterExport
        }
        return defaults.bool(forKey: Key.openOutputFolderAfterExport)
    }

    static func savedWatermarkScalePercent() -> Double {
        guard defaults.object(forKey: Key.watermarkScalePercent) != nil else {
            return defaultWatermarkScalePercent
        }
        return min(max(defaults.double(forKey: Key.watermarkScalePercent), 5.0), 100.0)
    }

    static func savedWatermarkOpacity() -> Double {
        guard defaults.object(forKey: Key.watermarkOpacity) != nil else {
            return defaultWatermarkOpacity
        }
        return min(max(defaults.double(forKey: Key.watermarkOpacity), 0.2), 1.0)
    }

    static func watermarkSupportDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("无损缩图Pro", isDirectory: true)
            .appendingPathComponent("Watermarks", isDirectory: true)
    }

    static func filmFrameSupportDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("无损缩图Pro", isDirectory: true)
            .appendingPathComponent("FilmFrames", isDirectory: true)
    }
}

private struct WatermarkRenderSettings {
    let fileURL: URL
    let preset: WatermarkPositionPreset?
    let customXRatio: CGFloat
    let customYRatio: CGFloat
    let scalePercent: CGFloat
    let opacity: CGFloat
}

struct WatermarkEditSnapshot {
    let watermarkEnabled: Bool
    let watermarkApplyToQuickAction: Bool
    let watermarkFilePath: String
    let watermarkPreviewFilePath: String
    let watermarkPositionPreset: String
    let watermarkCustomXRatio: Double
    let watermarkCustomYRatio: Double
    let watermarkScalePercent: Double
    let watermarkOpacity: Double
    let watermarkData: Data?
    let previewData: Data?
}

private struct FilmFrameRenderSettings {
    let fileURL: URL
}

private struct ResizeEngineResult {
    let success: Bool
    let failureReason: String?

    static let ok = ResizeEngineResult(success: true, failureReason: nil)

    static func failed(_ reason: String) -> ResizeEngineResult {
        ResizeEngineResult(success: false, failureReason: reason)
    }
}

struct FilmFrameEditSnapshot {
    let filmFrameEnabled: Bool
    let filmFrameApplyToQuickAction: Bool
    let filmFramePreviewFilePath: String
    let filmFrameCustomFilePath: String
    let filmFrameSelectedRatio: String
    let filmFrameSource: String
    let filmFrameBuiltinStyle: String
    let previewData: Data?
    let customFrameData: Data?
}

class ProfessionalImageProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var statusMessage = ""
    @Published var showFinishedAlert = false
    @Published var watermarkPreviewRefreshID = UUID()
    @Published var filmFramePreviewRefreshID = UUID()
    @Published var compressionQuality: Double {
        didSet {
            ResizeAppSettings.defaults.set(compressionQuality, forKey: ResizeAppSettings.Key.compressionQuality)
        }
    }


    @AppStorage(ResizeAppSettings.Key.targetShortEdge, store: ResizeAppSettings.store)
    var targetShortEdge: Double = ResizeAppSettings.defaultShortEdge


    @AppStorage(ResizeAppSettings.Key.watermarkEnabled, store: ResizeAppSettings.store)
    var watermarkEnabled: Bool = false

    @AppStorage(ResizeAppSettings.Key.watermarkApplyToQuickAction, store: ResizeAppSettings.store)
    var watermarkApplyToQuickAction: Bool = false

    @AppStorage(ResizeAppSettings.Key.watermarkFilePath, store: ResizeAppSettings.store)
    var watermarkFilePath: String = ""

    @AppStorage(ResizeAppSettings.Key.watermarkPreviewFilePath, store: ResizeAppSettings.store)
    var watermarkPreviewFilePath: String = ""

    @AppStorage(ResizeAppSettings.Key.watermarkPositionPreset, store: ResizeAppSettings.store)
    var watermarkPositionPreset: String = WatermarkPositionPreset.bottomCenter.rawValue

    @AppStorage(ResizeAppSettings.Key.watermarkCustomXRatio, store: ResizeAppSettings.store)
    var watermarkCustomXRatio: Double = 0.5

    @AppStorage(ResizeAppSettings.Key.watermarkCustomYRatio, store: ResizeAppSettings.store)
    var watermarkCustomYRatio: Double = 0.5

    @AppStorage(ResizeAppSettings.Key.watermarkScalePercent, store: ResizeAppSettings.store)
    var watermarkScalePercent: Double = ResizeAppSettings.defaultWatermarkScalePercent

    @AppStorage(ResizeAppSettings.Key.watermarkOpacity, store: ResizeAppSettings.store)
    var watermarkOpacity: Double = ResizeAppSettings.defaultWatermarkOpacity

    @AppStorage(ResizeAppSettings.Key.filmFrameEnabled, store: ResizeAppSettings.store)
    var filmFrameEnabled: Bool = false

    @AppStorage(ResizeAppSettings.Key.filmFrameApplyToQuickAction, store: ResizeAppSettings.store)
    var filmFrameApplyToQuickAction: Bool = false

    @AppStorage(ResizeAppSettings.Key.filmFramePreviewFilePath, store: ResizeAppSettings.store)
    var filmFramePreviewFilePath: String = ""

    @AppStorage(ResizeAppSettings.Key.filmFrameCustomFilePath, store: ResizeAppSettings.store)
    var filmFrameCustomFilePath: String = ""

    @AppStorage(ResizeAppSettings.Key.filmFrameSelectedRatio, store: ResizeAppSettings.store)
    var filmFrameSelectedRatio: String = ""

    @AppStorage(ResizeAppSettings.Key.filmFrameSource, store: ResizeAppSettings.store)
    var filmFrameSource: String = ""

    @AppStorage(ResizeAppSettings.Key.filmFrameBuiltinStyle, store: ResizeAppSettings.store)
    var filmFrameBuiltinStyle: String = FilmFrameBuiltinStyle.exposureInfo.rawValue

    init() {
        self.compressionQuality = ResizeAppSettings.savedCompressionQuality()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc func defaultsChanged() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var hasWatermarkImage: Bool {
        guard let url = currentWatermarkURL() else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func currentWatermarkURL() -> URL? {
        guard !watermarkFilePath.isEmpty else { return nil }
        return URL(fileURLWithPath: watermarkFilePath)
    }

    func currentWatermarkImage() -> NSImage? {
        guard let url = currentWatermarkURL() else { return nil }
        return NSImage(contentsOf: url)
    }

    func currentWatermarkPreviewURL() -> URL? {
        guard !watermarkPreviewFilePath.isEmpty else { return nil }
        return URL(fileURLWithPath: watermarkPreviewFilePath)
    }

    func currentWatermarkPreviewImage() -> NSImage? {
        guard let url = currentWatermarkPreviewURL() else { return nil }
        return NSImage(contentsOf: url)
    }

    func notifyWatermarkSettingsChanged() {
        // 水印设置存在共享 UserDefaults 中，手动刷新一次让 SwiftUI 预览和点亮状态立即同步。
        watermarkPreviewRefreshID = UUID()
        ResizeAppSettings.defaults.synchronize()
    }

    var hasFilmFrameOverlay: Bool {
        guard !filmFrameSource.isEmpty else { return false }
        return currentFilmFrameURLForPreview() != nil
    }

    func notifyFilmFrameSettingsChanged() {
        // 胶片框和右键快速操作共用一份设置，刷新 ID 让主界面预览状态立即更新。
        filmFramePreviewRefreshID = UUID()
        ResizeAppSettings.defaults.synchronize()
    }

    func currentFilmFramePreviewURL() -> URL? {
        guard !filmFramePreviewFilePath.isEmpty else { return nil }
        return URL(fileURLWithPath: filmFramePreviewFilePath)
    }

    func currentFilmFramePreviewImage() -> NSImage? {
        guard let url = currentFilmFramePreviewURL() else { return nil }
        return NSImage(contentsOf: url)
    }

    func currentFilmFramePreviewRatioText() -> String {
        currentFilmFramePreviewRatio()?.text ?? ""
    }

    func currentFilmFrameImageForPreview() -> NSImage? {
        guard let url = currentFilmFrameURLForPreview() else { return nil }
        return NSImage(contentsOf: url)
    }

    func currentFilmFramePreviewNeedsRotation() -> Bool {
        guard let previewImage = currentFilmFramePreviewImage(),
              let frameImage = currentFilmFrameImageForPreview() else { return false }
        return previewImage.isLandscape != frameImage.isLandscape
    }

    func isBuiltinFilmFrameSelected(_ ratioText: String) -> Bool {
        filmFrameSource == FilmFrameSource.builtin.rawValue && filmFrameSelectedRatio == ratioText
    }

    func isFilmFrameBuiltinStyleSelected(_ styleRawValue: String) -> Bool {
        filmFrameSource == FilmFrameSource.builtin.rawValue && normalizedFilmFrameBuiltinStyle().rawValue == styleRawValue
    }

    func filmFrameBuiltinStyleTitle(_ styleRawValue: String) -> String {
        FilmFrameBuiltinStyle(rawValue: styleRawValue)?.title ?? FilmFrameBuiltinStyle.exposureInfo.title
    }

    func selectFilmFrameBuiltinStyle(_ styleRawValue: String) throws {
        guard let style = FilmFrameBuiltinStyle(rawValue: styleRawValue) else { return }
        filmFrameBuiltinStyle = style.rawValue

        guard let previewRatio = currentFilmFramePreviewRatio() else {
            notifyFilmFrameSettingsChanged()
            return
        }
        guard let _ = builtinFilmFrameURL(for: previewRatio, style: style) else {
            filmFrameSource = ""
            filmFrameEnabled = false
            notifyFilmFrameSettingsChanged()
            return
        }

        // 切换样式时按当前照片比例立即切换到对应内置素材。
        filmFrameSelectedRatio = previewRatio.text
        filmFrameSource = FilmFrameSource.builtin.rawValue
        filmFrameEnabled = true
        notifyFilmFrameSettingsChanged()
    }

    func selectBuiltinFilmFrame(ratioText: String) throws {
        guard let previewRatio = currentFilmFramePreviewRatio() else {
            throw NSError(domain: "ResizeJpgFilmFrame", code: 7, userInfo: [NSLocalizedDescriptionKey: "请先选择预览照片"])
        }
        guard previewRatio.text == ratioText else {
            throw NSError(domain: "ResizeJpgFilmFrame", code: 8, userInfo: [NSLocalizedDescriptionKey: "比例不一致无法使用"])
        }
        guard builtinFilmFrameURL(for: previewRatio, style: normalizedFilmFrameBuiltinStyle()) != nil else {
            throw NSError(domain: "ResizeJpgFilmFrame", code: 10, userInfo: [NSLocalizedDescriptionKey: "内置胶片框资源缺失"])
        }

        // 内置按钮只保存比例、样式和来源，真正 PNG 从 App 包里读取，避免重复复制资源。
        filmFrameSelectedRatio = ratioText
        filmFrameSource = FilmFrameSource.builtin.rawValue
        filmFrameEnabled = true
        notifyFilmFrameSettingsChanged()
    }

    func makeWatermarkEditSnapshot() -> WatermarkEditSnapshot {
        let watermarkData = currentWatermarkURL().flatMap { try? Data(contentsOf: $0) }
        let previewData = currentWatermarkPreviewURL().flatMap { try? Data(contentsOf: $0) }

        return WatermarkEditSnapshot(
            watermarkEnabled: watermarkEnabled,
            watermarkApplyToQuickAction: watermarkApplyToQuickAction,
            watermarkFilePath: watermarkFilePath,
            watermarkPreviewFilePath: watermarkPreviewFilePath,
            watermarkPositionPreset: watermarkPositionPreset,
            watermarkCustomXRatio: watermarkCustomXRatio,
            watermarkCustomYRatio: watermarkCustomYRatio,
            watermarkScalePercent: watermarkScalePercent,
            watermarkOpacity: watermarkOpacity,
            watermarkData: watermarkData,
            previewData: previewData
        )
    }

    func makeFilmFrameEditSnapshot() -> FilmFrameEditSnapshot {
        let previewData = currentFilmFramePreviewURL().flatMap { try? Data(contentsOf: $0) }
        let customFrameData = currentFilmFrameCustomURL().flatMap { try? Data(contentsOf: $0) }

        return FilmFrameEditSnapshot(
            filmFrameEnabled: filmFrameEnabled,
            filmFrameApplyToQuickAction: filmFrameApplyToQuickAction,
            filmFramePreviewFilePath: filmFramePreviewFilePath,
            filmFrameCustomFilePath: filmFrameCustomFilePath,
            filmFrameSelectedRatio: filmFrameSelectedRatio,
            filmFrameSource: filmFrameSource,
            filmFrameBuiltinStyle: normalizedFilmFrameBuiltinStyle().rawValue,
            previewData: previewData,
            customFrameData: customFrameData
        )
    }

    func restoreWatermarkEditSnapshot(_ snapshot: WatermarkEditSnapshot) {
        restoreSnapshotFile(path: watermarkFilePath, snapshotPath: snapshot.watermarkFilePath, data: snapshot.watermarkData)
        restoreSnapshotFile(path: watermarkPreviewFilePath, snapshotPath: snapshot.watermarkPreviewFilePath, data: snapshot.previewData)

        watermarkEnabled = snapshot.watermarkEnabled
        watermarkApplyToQuickAction = snapshot.watermarkApplyToQuickAction
        watermarkFilePath = snapshot.watermarkData == nil ? "" : snapshot.watermarkFilePath
        watermarkPreviewFilePath = snapshot.previewData == nil ? "" : snapshot.watermarkPreviewFilePath
        watermarkPositionPreset = snapshot.watermarkPositionPreset
        watermarkCustomXRatio = snapshot.watermarkCustomXRatio
        watermarkCustomYRatio = snapshot.watermarkCustomYRatio
        watermarkScalePercent = snapshot.watermarkScalePercent
        watermarkOpacity = snapshot.watermarkOpacity
        notifyWatermarkSettingsChanged()
    }

    func restoreFilmFrameEditSnapshot(_ snapshot: FilmFrameEditSnapshot) {
        restoreSnapshotFile(path: filmFramePreviewFilePath, snapshotPath: snapshot.filmFramePreviewFilePath, data: snapshot.previewData)
        restoreSnapshotFile(path: filmFrameCustomFilePath, snapshotPath: snapshot.filmFrameCustomFilePath, data: snapshot.customFrameData)

        filmFrameEnabled = snapshot.filmFrameEnabled
        filmFrameApplyToQuickAction = snapshot.filmFrameApplyToQuickAction
        filmFramePreviewFilePath = snapshot.previewData == nil ? "" : snapshot.filmFramePreviewFilePath
        filmFrameCustomFilePath = snapshot.customFrameData == nil ? "" : snapshot.filmFrameCustomFilePath
        filmFrameSelectedRatio = snapshot.filmFrameSelectedRatio
        filmFrameSource = snapshot.filmFrameSource
        filmFrameBuiltinStyle = snapshot.filmFrameBuiltinStyle
        notifyFilmFrameSettingsChanged()
    }

    private func restoreSnapshotFile(path currentPath: String, snapshotPath: String, data: Data?) {
        if !currentPath.isEmpty, currentPath != snapshotPath {
            try? FileManager.default.removeItem(atPath: currentPath)
        }

        guard let data, !snapshotPath.isEmpty else {
            if !snapshotPath.isEmpty {
                try? FileManager.default.removeItem(atPath: snapshotPath)
            }
            return
        }

        let snapshotURL = URL(fileURLWithPath: snapshotPath)
        try? FileManager.default.createDirectory(at: snapshotURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: snapshotURL, options: .atomic)
    }

    func importWatermarkPreviewImage(from sourceURL: URL) throws {
        let canAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if canAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            throw NSError(domain: "ResizeJpgWatermark", code: 4, userInfo: [NSLocalizedDescriptionKey: "无法读取这张预览照片"])
        }

        guard let supportDirectory = ResizeAppSettings.watermarkSupportDirectory() else {
            throw NSError(domain: "ResizeJpgWatermark", code: 5, userInfo: [NSLocalizedDescriptionKey: "无法创建水印预览保存目录"])
        }

        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let fileExtension = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension.lowercased()
        let destinationURL = supportDirectory.appendingPathComponent("current-preview.\(fileExtension)")

        // 每次只保留一张预览照片，避免 Application Support 里积累临时预览素材。
        let existingPreviewURLs = (try? FileManager.default.contentsOfDirectory(at: supportDirectory, includingPropertiesForKeys: nil)) ?? []
        for url in existingPreviewURLs where url.lastPathComponent.hasPrefix("current-preview.") {
            try? FileManager.default.removeItem(at: url)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        watermarkPreviewFilePath = destinationURL.path
        notifyWatermarkSettingsChanged()
    }

    func importWatermarkPNG(from sourceURL: URL) throws {
        guard sourceURL.pathExtension.lowercased() == "png" else {
            throw NSError(domain: "ResizeJpgWatermark", code: 1, userInfo: [NSLocalizedDescriptionKey: "水印只能选择 PNG 图片"])
        }

        let canAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if canAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            throw NSError(domain: "ResizeJpgWatermark", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法读取这张 PNG 水印"])
        }

        guard let supportDirectory = ResizeAppSettings.watermarkSupportDirectory() else {
            throw NSError(domain: "ResizeJpgWatermark", code: 3, userInfo: [NSLocalizedDescriptionKey: "无法创建水印保存目录"])
        }

        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let destinationURL = supportDirectory.appendingPathComponent("current-watermark.png")

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        // 复制到 Application Support，避免用户移动原 PNG 后批量导出或右键快速操作找不到水印。
        watermarkFilePath = destinationURL.path
        watermarkEnabled = true
        if watermarkPositionPreset.isEmpty {
            watermarkPositionPreset = WatermarkPositionPreset.bottomCenter.rawValue
        }
        watermarkScalePercent = min(max(watermarkScalePercent, 5.0), 100.0)
        watermarkOpacity = min(max(watermarkOpacity, 0.2), 1.0)
        notifyWatermarkSettingsChanged()
    }

    func importFilmFramePreviewImage(from sourceURL: URL) throws {
        let canAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if canAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            throw NSError(domain: "ResizeJpgFilmFrame", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取这张预览照片"])
        }

        guard let supportDirectory = ResizeAppSettings.filmFrameSupportDirectory() else {
            throw NSError(domain: "ResizeJpgFilmFrame", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法创建胶片框预览保存目录"])
        }

        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let fileExtension = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension.lowercased()
        let destinationURL = supportDirectory.appendingPathComponent("current-film-preview.\(fileExtension)")

        // 预览照片每次都重新选择并覆盖旧文件，取消编辑时再用快照恢复。
        let existingPreviewURLs = (try? FileManager.default.contentsOfDirectory(at: supportDirectory, includingPropertiesForKeys: nil)) ?? []
        for url in existingPreviewURLs where url.lastPathComponent.hasPrefix("current-film-preview.") {
            try? FileManager.default.removeItem(at: url)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        filmFramePreviewFilePath = destinationURL.path
        notifyFilmFrameSettingsChanged()
    }

    func prepareFilmFrameForCurrentPreview() {
        guard let ratio = currentFilmFramePreviewRatio() else {
            filmFrameSource = ""
            filmFrameSelectedRatio = ""
            filmFrameEnabled = false
            notifyFilmFrameSettingsChanged()
            return
        }

        filmFrameSelectedRatio = ratio.text
        if builtinFilmFrameURL(for: ratio, style: normalizedFilmFrameBuiltinStyle()) != nil {
            filmFrameSource = FilmFrameSource.builtin.rawValue
            filmFrameEnabled = true
        } else {
            filmFrameSource = ""
            filmFrameEnabled = false
        }
        notifyFilmFrameSettingsChanged()
    }

    func importFilmFramePNG(from sourceURL: URL) throws {
        guard sourceURL.pathExtension.lowercased() == "png" else {
            throw NSError(domain: "ResizeJpgFilmFrame", code: 3, userInfo: [NSLocalizedDescriptionKey: "胶片框只能选择 PNG 图片"])
        }
        guard let previewRatio = currentFilmFramePreviewRatio() else {
            throw NSError(domain: "ResizeJpgFilmFrame", code: 4, userInfo: [NSLocalizedDescriptionKey: "请先选择预览照片"])
        }

        let canAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if canAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let frameImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "ResizeJpgFilmFrame", code: 5, userInfo: [NSLocalizedDescriptionKey: "无法读取这张 PNG 胶片框"])
        }
        guard let frameRatio = detectedFilmFrameRatio(width: frameImage.width, height: frameImage.height),
              ratioMatches(frameRatio, previewRatio) else {
            throw NSError(domain: "ResizeJpgFilmFrame", code: 6, userInfo: [NSLocalizedDescriptionKey: "胶片框比例非当前照片比例，请重新选择"])
        }
        guard let supportDirectory = ResizeAppSettings.filmFrameSupportDirectory() else {
            throw NSError(domain: "ResizeJpgFilmFrame", code: 9, userInfo: [NSLocalizedDescriptionKey: "无法创建胶片框保存目录"])
        }

        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let destinationURL = supportDirectory.appendingPathComponent("current-film-frame.png")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        // 自定义胶片框只校验长短边比例；横竖方向在预览和导出时自动旋转匹配照片。
        filmFrameCustomFilePath = destinationURL.path
        filmFrameSelectedRatio = previewRatio.text
        filmFrameSource = FilmFrameSource.custom.rawValue
        filmFrameEnabled = true
        notifyFilmFrameSettingsChanged()
    }

    func deleteCurrentWatermark() {
        if let url = currentWatermarkURL() {
            try? FileManager.default.removeItem(at: url)
        }

        // 删除水印只清空当前 PNG 和启用状态，预览照片不参与导出，保留也不会影响下次重新添加。
        watermarkFilePath = ""
        watermarkEnabled = false
        watermarkApplyToQuickAction = false
        watermarkPositionPreset = WatermarkPositionPreset.bottomCenter.rawValue
        watermarkCustomXRatio = 0.5
        watermarkCustomYRatio = 0.5
        watermarkScalePercent = ResizeAppSettings.defaultWatermarkScalePercent
        watermarkOpacity = ResizeAppSettings.defaultWatermarkOpacity
        notifyWatermarkSettingsChanged()
    }

    func deleteCurrentFilmFrame() {
        if let url = currentFilmFrameCustomURL() {
            try? FileManager.default.removeItem(at: url)
        }

        // 删除胶片框只清空叠加设置和同步状态，预览照片不影响导出，保留便于下次继续编辑预览。
        filmFrameCustomFilePath = ""
        filmFrameSelectedRatio = ""
        filmFrameSource = ""
        filmFrameEnabled = false
        filmFrameApplyToQuickAction = false
        filmFrameBuiltinStyle = FilmFrameBuiltinStyle.exposureInfo.rawValue
        notifyFilmFrameSettingsChanged()
    }

    // MARK: - Mac 快速操作处理逻辑
    // processQuickAction removed for open source

#if os(macOS)


    private func showQuickActionFailureAlert(messages: [String]) {
        let header = "处理失败" as CFString
        let joinedMessages = messages.prefix(5).joined(separator: "\n\n")
        let overflowText = messages.count > 5 ? "\n\n另有 \(messages.count - 5) 个文件失败。" : ""
        let message = "\(joinedMessages)\(overflowText)" as CFString
        var response: CFOptionFlags = 0
        CFUserNotificationDisplayAlert(0, kCFUserNotificationCautionAlertLevel, nil, nil, nil, header, message, "确定" as CFString, nil, nil, &response)
    }
#endif

    // MARK: - 安装右键插件逻辑









    // MARK: - 核心处理入口 (修正了嵌套错误和变量名)
    func handleDroppedFiles(providers: [NSItemProvider], targetSizeStr: String) {

        let targetShortSide = CGFloat(Double(targetSizeStr) ?? ResizeAppSettings.defaultShortEdge)
        let compressionQuality = self.compressionQuality
        var pendingUrls: [URL] = []
        let pendingUrlsLock = NSLock()
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }

                if let url {
                    pendingUrlsLock.lock()
                    pendingUrls.append(url)
                    pendingUrlsLock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            guard !pendingUrls.isEmpty else {
                self.statusMessage = "未能读取文件路径"
                return
            }

            self.isProcessing = true
            self.progress = 0
            self.statusMessage = "已识别 \(pendingUrls.count) 个文件，开始处理..."

            DispatchQueue.global(qos: .userInitiated).async {
                var processedCount = 0
                var outputFoldersToOpen: [URL] = []
                for (index, url) in pendingUrls.enumerated() {

                    let result = self.runResizeEngine(
                        url: url,
                        targetShortSide: targetShortSide,
                        compressionQuality: compressionQuality
                    )

                    DispatchQueue.main.async {
                        if result.success {
                            self.statusMessage = "已处理: \(index + 1)"
                        } else {
                            let reason = result.failureReason ?? "未知原因"
                            self.statusMessage = "处理失败: \(url.lastPathComponent)\n\(reason)"
                        }
                        self.progress = Double(index + 1) / Double(pendingUrls.count)
                    }
                    if result.success {
                        processedCount += 1
                        self.appendUniqueOutputFolder(for: url, to: &outputFoldersToOpen)
                    }
                }
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if ResizeAppSettings.savedOpenOutputFolderAfterExport() {
                        self.openOutputFolders(outputFoldersToOpen)
                    }
                    self.showFinishedAlert = true
                }
            }
        }
    }

    private func appendUniqueOutputFolder(for sourceURL: URL, to outputFolders: inout [URL]) {
        let outputFolder = sourceURL.deletingLastPathComponent().appendingPathComponent(ResizeAppSettings.outputFolderName())
        if !outputFolders.contains(outputFolder) {
            outputFolders.append(outputFolder)
        }
    }

    private func openOutputFolders(_ folders: [URL]) {
        // 批量任务全部结束后再打开输出文件夹，避免每导出一张图片就打断用户。
        for folder in folders where FileManager.default.fileExists(atPath: folder.path) {
            NSWorkspace.shared.open(folder)
        }
    }

    // MARK: - 16-bit 3.0 引擎核心 (移到了 handleDroppedFiles 外面)
    private func runResizeEngine(url: URL, targetShortSide: CGFloat, compressionQuality: Double? = nil, isQuickAction: Bool = false) -> ResizeEngineResult {
        let canAccess = url.startAccessingSecurityScopedResource()
        defer { if canAccess { url.stopAccessingSecurityScopedResource() } }

        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            return .failed("无法读取图片文件：\(error.localizedDescription)")
        }

        guard let source = CGImageSourceCreateWithData(fileData as CFData, nil) else {
            return .failed("无法解析图片数据，可能不是有效的 JPG/PNG。")
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return .failed("无法解码图片，可能是格式特殊、文件损坏或系统不支持。")
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        guard w > 0, h > 0 else {
            return .failed("图片尺寸异常：\(Int(w)) x \(Int(h))。")
        }
        let ratio = w / h

        // 简单等比缩放（开源版不含比例寻优）
        let finalW = Int((w > h) ? (targetShortSide * ratio).rounded() : targetShortSide.rounded())
        let finalH = Int((w > h) ? targetShortSide.rounded() : (targetShortSide / ratio).rounded())

        var format = vImage_CGImageFormat(
            bitsPerComponent: 16, bitsPerPixel: 64,
            colorSpace: Unmanaged.passRetained(cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder16Little.rawValue),
            version: 0, decode: nil, renderingIntent: .defaultIntent
        )

        var srcBuf = vImage_Buffer()
        var dstBuf = vImage_Buffer()

        let sourceInitError = vImageBuffer_InitWithCGImage(&srcBuf, &format, nil, cgImage, vImage_Flags(kvImageNoFlags))
        guard sourceInitError == kvImageNoError else {
            return .failed("无法转换图片色彩/位图格式，vImage 错误码：\(sourceInitError)。")
        }
        defer { free(srcBuf.data) }

        let destinationInitError = vImageBuffer_Init(&dstBuf, vImagePixelCount(finalH), vImagePixelCount(finalW), format.bitsPerPixel, vImage_Flags(kvImageNoFlags))
        guard destinationInitError == kvImageNoError else {
            return .failed("无法创建缩放缓存，vImage 错误码：\(destinationInitError)。")
        }

        var scaleError = vImageScale_ARGB16F(&srcBuf, &dstBuf, nil, vImage_Flags(kvImageHighQualityResampling))
        if scaleError == kvImageUnknownFlagsBit {
            // macOS 13.x may reject the high-quality flag on ARGB16F scaling; keep the 16-bit path and retry without optional flags.
            scaleError = vImageScale_ARGB16F(&srcBuf, &dstBuf, nil, vImage_Flags(kvImageNoFlags))
        }
        guard scaleError == kvImageNoError else {
            free(dstBuf.data)
            return .failed("图片缩放失败，vImage 错误码：\(scaleError)。")
        }



        guard let outCG = vImageCreateCGImageFromBuffer(&dstBuf, &format, nil, nil, vImage_Flags(kvImageNoFlags), nil)?.takeRetainedValue() else {
            free(dstBuf.data)
            return .failed("无法生成缩放后的图片。")
        }

        let watermarkSettings = activeWatermarkSettings(isQuickAction: isQuickAction)
        let watermarkedCG = watermarkSettings.flatMap {
            renderWatermark(on: outCG, outputWidth: finalW, outputHeight: finalH, settings: $0)
        }
        let filmFrameSettings = activeFilmFrameSettings(
            isQuickAction: isQuickAction,
            outputWidth: finalW,
            outputHeight: finalH
        )
        let filmFramedCG = filmFrameSettings.flatMap {
            renderFilmFrame(on: watermarkedCG ?? outCG, outputWidth: finalW, outputHeight: finalH, settings: $0)
        }
        let finalCG = filmFramedCG ?? watermarkedCG ?? outCG
        let didApplyWatermark = watermarkedCG != nil
        let didApplyFilmFrame = filmFramedCG != nil

        let originalExtension = url.pathExtension.lowercased()
        let isPNG = (originalExtension == "png")
        let outputType = isPNG ? UTType.png : UTType.jpeg

        let outDir = url.deletingLastPathComponent().appendingPathComponent(ResizeAppSettings.outputFolderName())
        do {
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        } catch {
            free(dstBuf.data)
            return .failed("无法创建输出文件夹：\(error.localizedDescription)")
        }

        let sizeLabel = "_\(Int(targetShortSide))"
        let watermarkLabel = didApplyWatermark ? "sy" : ""
        let filmFrameLabel = didApplyFilmFrame ? "film" : ""
        let finalExtension = isPNG ? "png" : "jpg"
        let outFileName = "\(url.deletingPathExtension().lastPathComponent)\(sizeLabel)\(watermarkLabel)\(filmFrameLabel).\(finalExtension)"
        let outURL = outDir.appendingPathComponent(outFileName)

        guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, outputType.identifier as CFString, 1, nil) else {
            free(dstBuf.data)
            return .failed("无法创建导出文件：\(outURL.path)")
        }

        var finalProps = properties ?? [:]
        finalProps[kCGImagePropertyPixelWidth] = finalW
        finalProps[kCGImagePropertyPixelHeight] = finalH
        if !isPNG {
            finalProps[kCGImageDestinationLossyCompressionQuality] = compressionQuality ?? self.compressionQuality
        }

        CGImageDestinationAddImage(dest, finalCG, finalProps as CFDictionary)
        let success = CGImageDestinationFinalize(dest)
        free(dstBuf.data)
        guard success else {
            return .failed("写入导出文件失败，请检查输出文件夹权限或同名文件是否被占用。")
        }
        return .ok
    }

    private func activeWatermarkSettings(isQuickAction: Bool) -> WatermarkRenderSettings? {
        // “添加水印”是总开关；关闭时 App 内导出和访达快速操作都不加水印。
        guard watermarkEnabled else { return nil }
        guard !filmFrameEnabled else { return nil }
        if isQuickAction && !watermarkApplyToQuickAction { return nil }
        guard let fileURL = currentWatermarkURL(),
              FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        return WatermarkRenderSettings(
            fileURL: fileURL,
            preset: WatermarkPositionPreset(rawValue: watermarkPositionPreset),
            customXRatio: CGFloat(min(max(watermarkCustomXRatio, 0), 1)),
            customYRatio: CGFloat(min(max(watermarkCustomYRatio, 0), 1)),
            scalePercent: CGFloat(min(max(watermarkScalePercent, 5.0), 100.0)),
            opacity: CGFloat(min(max(watermarkOpacity, 0.2), 1.0))
        )
    }

    private func activeFilmFrameSettings(isQuickAction: Bool, outputWidth: Int, outputHeight: Int) -> FilmFrameRenderSettings? {
        // “添加胶片框”是总开关；关闭时 App 内导出和访达快速操作都不叠框。
        guard filmFrameEnabled else { return nil }
        if isQuickAction && !filmFrameApplyToQuickAction { return nil }
        guard let outputRatio = detectedFilmFrameRatio(width: outputWidth, height: outputHeight) else { return nil }

        if filmFrameSource == FilmFrameSource.custom.rawValue,
           let customRatio = ratioFromText(filmFrameSelectedRatio),
           ratioMatches(customRatio, outputRatio),
           let customURL = currentFilmFrameCustomURL(),
           FileManager.default.fileExists(atPath: customURL.path) {
            return FilmFrameRenderSettings(fileURL: customURL)
        }

        if let builtinURL = builtinFilmFrameURL(for: outputRatio, style: normalizedFilmFrameBuiltinStyle()) {
            return FilmFrameRenderSettings(fileURL: builtinURL)
        }

        return nil
    }

    private func renderWatermark(on baseImage: CGImage, outputWidth: Int, outputHeight: Int, settings: WatermarkRenderSettings) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(settings.fileURL as CFURL, nil),
              let watermarkImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let outputSize = CGSize(width: outputWidth, height: outputHeight)
        let colorSpace = baseImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(baseImage, in: CGRect(origin: .zero, size: outputSize))

        let watermarkRect = watermarkDrawRect(
            watermarkSize: CGSize(width: watermarkImage.width, height: watermarkImage.height),
            outputSize: outputSize,
            settings: settings
        )

        // 在最终导出尺寸上叠加水印，避免水印再参与 16-bit 缩放和锐化。
        context.saveGState()
        context.setAlpha(settings.opacity)
        context.interpolationQuality = .high
        context.draw(watermarkImage, in: watermarkRect)
        context.restoreGState()

        return context.makeImage()
    }

    private func renderFilmFrame(on baseImage: CGImage, outputWidth: Int, outputHeight: Int, settings: FilmFrameRenderSettings) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(settings.fileURL as CFURL, nil),
              let frameImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let outputSize = CGSize(width: outputWidth, height: outputHeight)
        let colorSpace = baseImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(baseImage, in: CGRect(origin: .zero, size: outputSize))

        // 胶片框永远覆盖整张输出图；方向不一致时在绘制时旋转，用户导入横竖 PNG 都能用。
        context.saveGState()
        context.interpolationQuality = .high
        if CGSize(width: frameImage.width, height: frameImage.height).isLandscape != outputSize.isLandscape {
            context.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.rotate(by: -.pi / 2)
            context.draw(
                frameImage,
                in: CGRect(
                    x: -outputSize.height / 2,
                    y: -outputSize.width / 2,
                    width: outputSize.height,
                    height: outputSize.width
                )
            )
        } else {
            context.draw(frameImage, in: CGRect(origin: .zero, size: outputSize))
        }
        context.restoreGState()

        return context.makeImage()
    }

    private func watermarkDrawRect(watermarkSize: CGSize, outputSize: CGSize, settings: WatermarkRenderSettings) -> CGRect {
        // 导出按输出图片短边计算水印宽度，让横竖图批量导出时水印大小更一致。
        let targetWatermarkWidth = min(outputSize.width, outputSize.height) * settings.scalePercent / 100.0
        let aspectRatio = watermarkSize.height / max(watermarkSize.width, 1)
        let targetWatermarkHeight = targetWatermarkWidth * aspectRatio
        let fitRatio = min(1, outputSize.width / max(targetWatermarkWidth, 1), outputSize.height / max(targetWatermarkHeight, 1))
        let watermarkWidth = targetWatermarkWidth * fitRatio
        let watermarkHeight = targetWatermarkHeight * fitRatio
        let margin = min(outputSize.width, outputSize.height) * ResizeAppSettings.watermarkEdgeMarginRatio
        let maxX = max(outputSize.width - watermarkWidth, 0)
        let maxTopY = max(outputSize.height - watermarkHeight, 0)

        let topLeftOrigin: CGPoint
        if let preset = settings.preset {
            topLeftOrigin = presetTopLeftOrigin(
                preset: preset,
                watermarkSize: CGSize(width: watermarkWidth, height: watermarkHeight),
                outputSize: outputSize,
                margin: margin
            )
        } else {
            // 自定义拖动位置保存为“左上角相对坐标”，导出时再换算到实际图片尺寸。
            topLeftOrigin = CGPoint(
                x: settings.customXRatio * maxX,
                y: settings.customYRatio * maxTopY
            )
        }

        let clampedX = min(max(topLeftOrigin.x, 0), maxX)
        let clampedTopY = min(max(topLeftOrigin.y, 0), maxTopY)
        let cgY = outputSize.height - watermarkHeight - clampedTopY
        return CGRect(x: clampedX, y: cgY, width: watermarkWidth, height: watermarkHeight)
    }

    private func presetTopLeftOrigin(
        preset: WatermarkPositionPreset,
        watermarkSize: CGSize,
        outputSize: CGSize,
        margin: CGFloat
    ) -> CGPoint {
        let centerX = (outputSize.width - watermarkSize.width) / 2
        let rightX = outputSize.width - watermarkSize.width - margin
        let bottomTopY = outputSize.height - watermarkSize.height - margin

        switch preset {
        case .topLeft:
            return CGPoint(x: margin, y: margin)
        case .topCenter:
            return CGPoint(x: centerX, y: margin)
        case .topRight:
            return CGPoint(x: rightX, y: margin)
        case .bottomLeft:
            return CGPoint(x: margin, y: bottomTopY)
        case .bottomCenter:
            return CGPoint(x: centerX, y: bottomTopY)
        case .bottomRight:
            return CGPoint(x: rightX, y: bottomTopY)
        }
    }

    private func currentFilmFrameURLForPreview() -> URL? {
        guard let previewRatio = currentFilmFramePreviewRatio() else { return nil }
        if filmFrameSource == FilmFrameSource.custom.rawValue,
           let customRatio = ratioFromText(filmFrameSelectedRatio),
           ratioMatches(customRatio, previewRatio),
           let customURL = currentFilmFrameCustomURL(),
           FileManager.default.fileExists(atPath: customURL.path) {
            return customURL
        }
        if filmFrameSource == FilmFrameSource.builtin.rawValue,
           ratioFromText(filmFrameSelectedRatio) == previewRatio {
            return builtinFilmFrameURL(for: previewRatio, style: normalizedFilmFrameBuiltinStyle())
        }
        return nil
    }

    private func currentFilmFrameCustomURL() -> URL? {
        guard !filmFrameCustomFilePath.isEmpty else { return nil }
        return URL(fileURLWithPath: filmFrameCustomFilePath)
    }

    private func currentFilmFramePreviewRatio() -> FilmFrameRatio? {
        guard let previewURL = currentFilmFramePreviewURL(),
              let source = CGImageSourceCreateWithURL(previewURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return detectedFilmFrameRatio(width: image.width, height: image.height)
    }

    private func builtinFilmFrameURL(for ratio: FilmFrameRatio, style: FilmFrameBuiltinStyle) -> URL? {
        let resourceName: String
        switch (ratio.text, style) {
        case ("2:3", .filmName):
            resourceName = "filmk32"
        case ("2:3", .exposureInfo):
            resourceName = "filmk32B"
        case ("3:4", .filmName):
            resourceName = "filmk645"
        case ("3:4", .exposureInfo):
            resourceName = "filmk645B"
        default:
            return nil
        }
        return Bundle.main.url(forResource: resourceName, withExtension: "png", subdirectory: "kuang")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "png")
    }

    private func normalizedFilmFrameBuiltinStyle() -> FilmFrameBuiltinStyle {
        FilmFrameBuiltinStyle(rawValue: filmFrameBuiltinStyle) ?? .exposureInfo
    }

    private func detectedFilmFrameRatio(width: Int, height: Int) -> FilmFrameRatio? {
        let shortSide = CGFloat(min(width, height))
        let longSide = CGFloat(max(width, height))
        guard shortSide > 0, longSide > 0 else { return nil }
        let actual = shortSide / longSide
        var bestRatio: FilmFrameRatio?
        var bestScore = CGFloat.greatestFiniteMagnitude

        // 以短边:长边匹配比例，允许横竖照片共用同一套胶片框素材。
        for long in 1...16 {
            for short in 1...long {
                let candidate = FilmFrameRatio(shortSide: short, longSide: long)
                let error = abs(actual - candidate.value) / candidate.value
                guard error <= 0.05 else { continue }

                let sizePenalty = CGFloat(short + long) * 0.01
                let score = error + sizePenalty
                if score < bestScore {
                    bestScore = score
                    bestRatio = candidate
                }
            }
        }

        return bestRatio
    }

    private func ratioFromText(_ text: String) -> FilmFrameRatio? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { return nil }
        return FilmFrameRatio(shortSide: min(parts[0], parts[1]), longSide: max(parts[0], parts[1]))
    }

    private func ratioMatches(_ lhs: FilmFrameRatio, _ rhs: FilmFrameRatio) -> Bool {
        abs(lhs.value - rhs.value) / rhs.value <= 0.05
    }




}

private extension CGSize {
    var isLandscape: Bool {
        width > height
    }
}

private extension NSImage {
    var isLandscape: Bool {
        size.width > size.height
    }
}

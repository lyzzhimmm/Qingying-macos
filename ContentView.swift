import SwiftUI
import UniformTypeIdentifiers
import AppKit
internal import Combine

struct ContentView: View {
    @EnvironmentObject var processor: ProfessionalImageProcessor
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    @State private var inputCode: String = ""
    @State private var showAlert = false
    @State private var alertMsg = ""
    @State private var showPurchaseSheet = false
    @State private var showWatermarkEditor = false
    @State private var watermarkEditorSnapshot: WatermarkEditSnapshot?
    @State private var pendingWatermarkRestoreSnapshot: WatermarkEditSnapshot?
    @State private var showFilmFrameEditor = false
    @State private var filmFrameEditorSnapshot: FilmFrameEditSnapshot?
    @State private var pendingFilmFrameRestoreSnapshot: FilmFrameEditSnapshot?
    @State private var inputSize: String = ""
    @AppStorage(ResizeAppSettings.Key.customFolderName, store: ResizeAppSettings.store)
    private var customFolderName: String = ResizeAppSettings.defaultFolderName
    @AppStorage(ResizeAppSettings.Key.openOutputFolderAfterExport, store: ResizeAppSettings.store)
    private var openOutputFolderAfterExport: Bool = ResizeAppSettings.defaultOpenOutputFolderAfterExport


    var body: some View {
        ZStack {
            mainAppUI
        }
        .onAppear {
            inputSize = String(Int(processor.targetShortEdge))
            refreshPersistentState()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                refreshPersistentState()
            }
        }

        .contentShape(Rectangle())
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .frame(minWidth: 1160, minHeight: 680)

        .background(Color(NSColor.windowBackgroundColor))
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMsg)
        }
    }

    // MARK: - 购买详情弹窗界面
    var purchaseSheetView: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: { showPurchaseSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }.buttonStyle(.plain)
            }.padding([.top, .trailing], 15)

            Text("扫码支付获取授权").font(.headline)

            Image("wxqr")
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 260)
                .cornerRadius(12)
                .shadow(radius: 5)

            VStack(spacing: 10) {
                Text("付款后请将『支付截图』及机器码发送至")
                    .font(.system(size: 13, weight: .bold))

                Text("邮箱：1216792742@qq.com 或")
                    .font(.system(size: 12, weight: .bold))
                Text("微信：zhimmmn")
                    .font(.system(size: 12, weight: .bold))

                Text("我将尽快为您发送激活码")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .frame(width: 350) // 弹窗宽度
    }
    // MARK: - 主功能界面
    var mainAppUI: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("轻影")
                            .font(.system(size: 23, weight: .bold))
                            .fontWeight(.bold)

                        Text("无损批量缩图 / 水印 / 胶片框")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                }

                Spacer(minLength: 20)

                HStack(spacing: 6) {
                    Text("输出文件夹名:").font(.subheadline).foregroundColor(.secondary)
                    TextField("默认: 无损缩图小图", text: $customFolderName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 180)
                }

                Toggle("导出后打开文件夹", isOn: $openOutputFolderAfterExport)
                    .font(.subheadline)

                HStack(spacing: 6) {
                    Text("短边:").font(.subheadline).foregroundColor(.secondary)
                    TextField("2000", text: $inputSize)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                        .onChange(of: inputSize) { newValue in
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if filtered != newValue {
                                inputSize = filtered
                                return
                            }
                            if let val = Double(filtered), val > 0 {
                                processor.targetShortEdge = val
                            }
                        }
                    Text("px").font(.subheadline).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 25)
            .padding(.top, 25)
            .padding(.bottom, 15)
            .onAppear {
                inputSize = String(Int(processor.targetShortEdge))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("输出质量")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(processor.compressionQuality * 100))%").font(.caption).monospaced()
                }
                Slider(value: $processor.compressionQuality, in: 0.5...1.0)
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 14)

            watermarkSettingsView

            HStack(spacing: 0) {
                featureTag(i: "plus.circle.fill", t: "水印胶片框", c: .accentColor)
                Divider().frame(height: 12)
                featureTag(i: "checkmark.circle.fill", t: "比例寻优不变形", c: .green)
                Divider().frame(height: 12)
                featureTag(i: "info.circle.fill", t: "EXIF全保留", c: .blue)
                Divider().frame(height: 12)
                featureTag(i: "cpu.fill", t: "16Bit无损处理", c: .orange)
            }
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.05))

            ZStack {
                RoundedRectangle(cornerRadius: 20).stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(processor.isProcessing ? .accentColor : .secondary.opacity(0.2)).padding(20)

                if processor.isProcessing {
                    VStack(spacing: 15) {
                        ProgressView(value: processor.progress).frame(width: 250)
                        Text(processor.statusMessage).font(.caption).foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 15) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(.tint)
                        Text("拖入 JPG/PNG 图片开始处理，朋友圈小红书建议短边2000px").font(.headline)
                        Text("支持多图 16-bit 高精缩放并行处理").font(.caption)
                            .foregroundColor(.secondary)
                            .opacity(0.7)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                processor.handleDroppedFiles(providers: providers, targetSizeStr: inputSize)
                return true
            }

            HStack(alignment: .bottom) {
                Button(action: {
                }) {
                    HStack(spacing: 7) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 20, height: 20)

                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11, weight: .bold))
                        }

                        }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )

                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        }
                    )
                    .cornerRadius(8)
                                        .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("小红书：胶仔阿志")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                    .onTapGesture(count: 15) {
                        print("状态已重置")
                    }
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 20)
        }
        .alert("提示", isPresented: $processor.showFinishedAlert) {
            Button("确定") { }
        } message: {
            Text(processor.statusMessage)
        }
        .sheet(isPresented: $showWatermarkEditor, onDismiss: {
            if let pendingWatermarkRestoreSnapshot {
                processor.restoreWatermarkEditSnapshot(pendingWatermarkRestoreSnapshot)
                self.pendingWatermarkRestoreSnapshot = nil
            }
        }) {
            WatermarkEditorView(
                processor: processor,
                onCancel: {
                    pendingWatermarkRestoreSnapshot = watermarkEditorSnapshot
                    watermarkEditorSnapshot = nil
                },
                onComplete: {
                    pendingWatermarkRestoreSnapshot = nil
                    watermarkEditorSnapshot = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        processor.statusMessage = "已成功设置水印，后续勾选添加，导出照片自动添加"
                        processor.showFinishedAlert = true
                    }
                }
            ) {
                chooseWatermarkPNG()
            }
        }
        .sheet(isPresented: $showFilmFrameEditor, onDismiss: {
            if let pendingFilmFrameRestoreSnapshot {
                processor.restoreFilmFrameEditSnapshot(pendingFilmFrameRestoreSnapshot)
                self.pendingFilmFrameRestoreSnapshot = nil
            }
        }) {
            FilmFrameEditorView(
                processor: processor,
                onCancel: {
                    pendingFilmFrameRestoreSnapshot = filmFrameEditorSnapshot
                    filmFrameEditorSnapshot = nil
                },
                onComplete: {
                    pendingFilmFrameRestoreSnapshot = nil
                    if processor.hasFilmFrameOverlay && processor.filmFrameEnabled {
                        deactivateWatermarkForExclusiveOverlay()
                    }
                    filmFrameEditorSnapshot = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        processor.statusMessage = "已成功设置胶片框，后续勾选添加，导出照片自动添加"
                        processor.showFinishedAlert = true
                    }
                },
                chooseFilmFrame: {
                    chooseFilmFramePNG()
                },
                selectBuiltin: { ratioText in
                    guard pendingFilmFrameRestoreSnapshot == nil,
                          processor.currentFilmFramePreviewRatioText() == ratioText else { return }
                    do {
                        try processor.selectBuiltinFilmFrame(ratioText: ratioText)
                    } catch {
                        if showFilmFrameEditor {
                            alertMsg = error.localizedDescription
                            showAlert = true
                        }
                    }
                },
                selectBuiltinStyle: { styleRawValue in
                    do {
                        try processor.selectFilmFrameBuiltinStyle(styleRawValue)
                    } catch {
                        alertMsg = error.localizedDescription
                        showAlert = true
                    }
                }
            )
        }
    }

    var watermarkSettingsView: some View {
        HStack(spacing: 28) {
            HStack(spacing: 24) {
                HStack(spacing: 8) {
                    Toggle(isOn: Binding(
                        get: { processor.watermarkEnabled },
                        set: { newValue in
                            if newValue {
                                if processor.hasWatermarkImage {
                                    activateWatermarkMode()
                                } else {
                                    beginAddWatermarkFlow()
                                }
                            } else {
                                processor.watermarkEnabled = false
                                processor.watermarkApplyToQuickAction = false
                                processor.notifyWatermarkSettingsChanged()
                            }
                        }
                    )) {
                        Text("添加水印")
                            .fontWeight(.bold)
                    }
                }

                if processor.hasWatermarkImage {
                    HStack(spacing: 10) {
                        WatermarkThumbnailView(image: processor.currentWatermarkImage())
                            .id(processor.watermarkPreviewRefreshID)

                        Button(action: {
                            beginEditWatermarkFlow()
                        }) {
                            actionPillButton(title: "编辑", color: .accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("编辑水印")

                        Button(action: {
                            processor.deleteCurrentWatermark()
                        }) {
                            actionPillButton(title: "删除", color: .red)
                        }
                        .buttonStyle(.plain)
                        .help("删除当前水印")
                    }

                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 24) {
                Toggle(isOn: Binding(
                    get: { processor.filmFrameEnabled },
                    set: { newValue in
                        if newValue {
                            if processor.hasFilmFrameOverlay {
                                activateFilmFrameMode()
                            } else {
                                beginAddFilmFrameFlow()
                            }
                        } else {
                            processor.filmFrameEnabled = false
                            processor.filmFrameApplyToQuickAction = false
                            processor.notifyFilmFrameSettingsChanged()
                        }
                    }
                )) {
                    Text("添加胶片框")
                        .fontWeight(.bold)
                }

                if processor.hasFilmFrameOverlay {
                    HStack(spacing: 10) {
                        Button(action: {
                            beginEditFilmFrameFlow()
                        }) {
                            actionPillButton(title: "更换", color: .accentColor)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            processor.deleteCurrentFilmFrame()
                        }) {
                            actionPillButton(title: "删除", color: .red)
                        }
                        .buttonStyle(.plain)
                        .help("删除当前胶片框")
                    }

                    .disabled(!processor.filmFrameEnabled)
                    .opacity(processor.filmFrameEnabled ? 1 : 0.45)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.12 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12), lineWidth: 1)
        )
        .padding(.horizontal, 25)
        .padding(.bottom, 14)
    }

    private func actionPillButton(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 46, height: 26)
            .background(color)
            .cornerRadius(6)
    }

    func featureTag(i: String, t: String, c: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: i).foregroundColor(c)
            Text(t).font(.system(size: 10, weight: .bold))
        }.frame(maxWidth: .infinity)
    }

    private func refreshPersistentState() {
        let defaults = ResizeAppSettings.defaults
        defaults.synchronize()


    }

    private func beginAddWatermarkFlow() {
        watermarkEditorSnapshot = processor.makeWatermarkEditSnapshot()
        chooseWatermarkPreviewImage { didChoosePreview in
            guard didChoosePreview else {
                if let watermarkEditorSnapshot {
                    processor.restoreWatermarkEditSnapshot(watermarkEditorSnapshot)
                }
                watermarkEditorSnapshot = nil
                return
            }

            if processor.hasWatermarkImage {
                processor.watermarkEnabled = true
                deactivateFilmFrameForExclusiveOverlay()
                processor.notifyWatermarkSettingsChanged()
                showWatermarkEditor = true
            } else {
                chooseWatermarkPNG(openEditorAfterImport: true)
            }
        }
    }

    private func beginEditWatermarkFlow() {
        watermarkEditorSnapshot = processor.makeWatermarkEditSnapshot()
        chooseWatermarkPreviewImage { didChoosePreview in
            if didChoosePreview {
                showWatermarkEditor = true
            } else {
                if let watermarkEditorSnapshot {
                    processor.restoreWatermarkEditSnapshot(watermarkEditorSnapshot)
                }
                watermarkEditorSnapshot = nil
            }
        }
    }

    private func chooseWatermarkPreviewImage(completion: @escaping (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "第 1 步：选择预览照片"
        panel.message = "第一步选择照片，只用于预览水印位置，不会被导出或修改。"
        panel.prompt = "选择预览照片"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(false)
                return
            }

            do {
                // 预览照片只用于编辑水印位置，复制一份后就能在弹窗里稳定显示。
                try processor.importWatermarkPreviewImage(from: url)
                completion(true)
            } catch {
                alertMsg = error.localizedDescription
                showAlert = true
                completion(false)
            }
        }
    }

    private func chooseWatermarkPNG(openEditorAfterImport: Bool = false) {
        let panel = NSOpenPanel()
        panel.title = "第 2 步：选择 PNG 水印"
        panel.message = "请选择要叠加到导出照片上的 PNG 水印。"
        panel.prompt = "选择水印"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png]

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                if !processor.hasWatermarkImage {
                    processor.watermarkEnabled = false
                }
                if openEditorAfterImport {
                    if let watermarkEditorSnapshot {
                        processor.restoreWatermarkEditSnapshot(watermarkEditorSnapshot)
                    }
                    watermarkEditorSnapshot = nil
                }
                return
            }

            do {
                // 只允许导入 PNG，并交给处理器复制到 App 支持目录，保证右键快速操作也能稳定读取。
                try processor.importWatermarkPNG(from: url)
                if openEditorAfterImport {
                    deactivateFilmFrameForExclusiveOverlay()
                    processor.watermarkPositionPreset = WatermarkPositionPreset.bottomCenter.rawValue
                    processor.watermarkCustomXRatio = 0.5
                    processor.watermarkCustomYRatio = 0.5
                    processor.watermarkScalePercent = ResizeAppSettings.defaultWatermarkScalePercent
                    processor.watermarkOpacity = ResizeAppSettings.defaultWatermarkOpacity
                    processor.notifyWatermarkSettingsChanged()
                    showWatermarkEditor = true
                }
            } catch {
                if openEditorAfterImport, let watermarkEditorSnapshot {
                    processor.restoreWatermarkEditSnapshot(watermarkEditorSnapshot)
                    self.watermarkEditorSnapshot = nil
                } else {
                    processor.watermarkEnabled = processor.hasWatermarkImage
                }
                alertMsg = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func beginAddFilmFrameFlow() {
        filmFrameEditorSnapshot = processor.makeFilmFrameEditSnapshot()
        chooseFilmFramePreviewImage { didChoosePreview in
            guard didChoosePreview else {
                if let filmFrameEditorSnapshot {
                    processor.restoreFilmFrameEditSnapshot(filmFrameEditorSnapshot)
                }
                filmFrameEditorSnapshot = nil
                return
            }

            processor.prepareFilmFrameForCurrentPreview()
            showFilmFrameEditor = true
        }
    }

    private func beginEditFilmFrameFlow() {
        filmFrameEditorSnapshot = processor.makeFilmFrameEditSnapshot()
        chooseFilmFramePreviewImage { didChoosePreview in
            if didChoosePreview {
                processor.prepareFilmFrameForCurrentPreview()
                showFilmFrameEditor = true
            } else {
                if let filmFrameEditorSnapshot {
                    processor.restoreFilmFrameEditSnapshot(filmFrameEditorSnapshot)
                }
                filmFrameEditorSnapshot = nil
            }
        }
    }

    private func chooseFilmFramePreviewImage(completion: @escaping (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "选择胶片框预览照片"
        panel.message = "选择照片，只用于预览胶片框样式，不会被导出或修改。"
        panel.prompt = "选择预览照片"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(false)
                return
            }

            do {
                // 胶片框每次添加/编辑都重新选择预览照片，保证比例识别来自用户当前关注的图片。
                try processor.importFilmFramePreviewImage(from: url)
                completion(true)
            } catch {
                alertMsg = error.localizedDescription
                showAlert = true
                completion(false)
            }
        }
    }

    private func chooseFilmFramePNG() {
        let panel = NSOpenPanel()
        panel.title = "选择 PNG 胶片框"
        panel.message = "请选择与预览照片比例一致的 PNG 胶片框；横竖方向不一致时 App 会自动旋转。"
        panel.prompt = processor.hasFilmFrameOverlay ? "更换胶片框" : "导入胶片框"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                // 自定义胶片框复制到 Application Support，保证批量导出和右键快速操作都能稳定读取。
                try processor.importFilmFramePNG(from: url)
                alertMsg = ""
                showAlert = false
            } catch {
                // 胶片框编辑窗口仍打开时，用 AppKit 即时提示，避免 SwiftUI 全局 alert 延后到点“完成”后才弹出。
                showFilmFrameSelectionAlert(message: error.localizedDescription)
            }
        }
    }

    private func showFilmFrameSelectionAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "提示"
        alert.informativeText = message
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    private func activateWatermarkMode() {
        processor.watermarkEnabled = true
        deactivateFilmFrameForExclusiveOverlay()
        processor.notifyWatermarkSettingsChanged()
    }

    private func activateFilmFrameMode() {
        processor.filmFrameEnabled = true
        deactivateWatermarkForExclusiveOverlay()
        processor.notifyFilmFrameSettingsChanged()
    }

    private func deactivateWatermarkForExclusiveOverlay() {
        guard processor.watermarkEnabled || processor.watermarkApplyToQuickAction else { return }
        processor.watermarkEnabled = false
        processor.watermarkApplyToQuickAction = false
        processor.notifyWatermarkSettingsChanged()
        showExclusiveOverlayAlert()
    }

    private func deactivateFilmFrameForExclusiveOverlay() {
        guard processor.filmFrameEnabled || processor.filmFrameApplyToQuickAction else { return }
        processor.filmFrameEnabled = false
        processor.filmFrameApplyToQuickAction = false
        processor.notifyFilmFrameSettingsChanged()
        showExclusiveOverlayAlert()
    }

    private func showExclusiveOverlayAlert() {
        alertMsg = "添加水印与胶片框只能应用一项"
        showAlert = true
    }
}

struct WatermarkThumbnailView: View {
    let image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
                .frame(width: 48, height: 32)

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 26)
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}

struct WatermarkKeyHandlingView: NSViewRepresentable {
    let focusToken: UUID
    let onMove: (MoveCommandDirection) -> Void

    func makeNSView(context: Context) -> KeyHandlingNSView {
        let view = KeyHandlingNSView()
        view.onMove = onMove
        return view
    }

    func updateNSView(_ nsView: KeyHandlingNSView, context: Context) {
        nsView.onMove = onMove
        nsView.focusToken = focusToken
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class KeyHandlingNSView: NSView {
        var onMove: ((MoveCommandDirection) -> Void)?
        var focusToken = UUID()

        override var acceptsFirstResponder: Bool { true }
        override var focusRingType: NSFocusRingType {
            get { .none }
            set { }
        }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 123:
                onMove?(.left)
            case 124:
                onMove?(.right)
            case 125:
                onMove?(.down)
            case 126:
                onMove?(.up)
            default:
                super.keyDown(with: event)
            }
        }
    }
}

struct WatermarkEditorView: View {
    @ObservedObject var processor: ProfessionalImageProcessor
    let onCancel: () -> Void
    let onComplete: () -> Void
    let chooseWatermark: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var dragStartTopLeft: CGPoint?
    @State private var keyboardFocusToken = UUID()
    @State private var snapEscapeDirection: Int = 0
    @State private var snapEscapeCount: Int = 0
    @State private var horizontalSnapBypassDirection: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            watermarkPreviewPanel

            Divider()

            watermarkControlPanel
        }
        .frame(width: 960, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var watermarkPreviewPanel: some View {
        GeometryReader { geometry in
            let previewImage = processor.currentWatermarkPreviewImage()
            let previewSize = fittedPreviewSize(in: CGSize(width: geometry.size.width, height: geometry.size.height - 24), image: previewImage)
            let watermarkRect = currentWatermarkRect(in: previewSize)

            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: previewSize.width, height: previewSize.height)

                    if let previewImage {
                        Image(nsImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: previewSize.width, height: previewSize.height)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 46))
                            .foregroundColor(.secondary.opacity(0.25))
                    }

                    if let image = processor.currentWatermarkImage() {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.clear)
                                .contentShape(Rectangle())

                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: watermarkRect.width, height: watermarkRect.height)
                                .opacity(processor.watermarkOpacity)
                                .allowsHitTesting(false)
                        }
                        .frame(
                            width: watermarkRect.width + watermarkDragPadding * 2,
                            height: watermarkRect.height + watermarkDragPadding * 2
                        )
                        .position(x: watermarkRect.midX, y: watermarkRect.midY)
                        .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        // 拖动后清空预设，预设按钮全部熄灭；坐标按预览区左上角比例保存。
                                        let start = dragStartTopLeft ?? watermarkRect.origin
                                        if dragStartTopLeft == nil {
                                            dragStartTopLeft = start
                                        }
                                        updateCustomPosition(
                                            from: CGPoint(
                                                x: start.x + value.translation.width,
                                                y: start.y + value.translation.height
                                            ),
                                            previewSize: previewSize,
                                            watermarkSize: watermarkRect.size
                                        )
                                    }
                                    .onEnded { _ in
                                        dragStartTopLeft = nil
                                    }
                            )
                    }
                }
                .frame(width: previewSize.width, height: previewSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("拖动水印/键盘方向键微调可自定义水印位置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .onTapGesture {
                keyboardFocusToken = UUID()
            }
            .background(
                WatermarkKeyHandlingView(focusToken: keyboardFocusToken) { direction in
                    moveWatermark(
                        direction: direction,
                        previewSize: previewSize,
                        watermarkSize: watermarkRect.size,
                        currentTopLeft: watermarkRect.origin
                    )
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
        .frame(width: 680)
    }

    private var watermarkControlPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                WatermarkThumbnailView(image: processor.currentWatermarkImage())
                    .id(processor.watermarkPreviewRefreshID)

                Button(action: chooseWatermark) {
                    Label("更换 PNG 水印", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("位置")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("大小")
                    Spacer()
                    Text("\(processor.watermarkScalePercent, specifier: "%.1f")%")
                        .monospacedDigit()
                }
                .font(.caption)
                Slider(value: Binding(
                    get: { processor.watermarkScalePercent },
                    set: {
                        processor.watermarkScalePercent = min(max($0, 5.0), 100.0)
                        processor.notifyWatermarkSettingsChanged()
                    }
                ), in: 5.0...100.0, step: 0.5)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("透明度")
                    Spacer()
                    Text("\(Int(processor.watermarkOpacity * 100))%")
                        .monospacedDigit()
                }
                .font(.caption)
                Slider(value: Binding(
                    get: { processor.watermarkOpacity },
                    set: {
                        processor.watermarkOpacity = min(max($0, 0.2), 1.0)
                        processor.notifyWatermarkSettingsChanged()
                    }
                ), in: 0.2...1.0, step: 0.01)
            }

            Spacer()

            HStack {
                Spacer()
                Button("取消") {
                    onCancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("完成") {
                    onComplete()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 280)
    }

    private func presetButton(_ preset: WatermarkPositionPreset) -> some View {
        let isSelected = processor.watermarkPositionPreset == preset.rawValue

        return Button(action: {
            processor.watermarkPositionPreset = preset.rawValue
            processor.notifyWatermarkSettingsChanged()
        }) {
            Text(preset.title)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 54, height: 28)
                .foregroundColor(isSelected ? .white : .primary)
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func fittedPreviewSize(in containerSize: CGSize, image: NSImage?) -> CGSize {
        let maxWidth = max(containerSize.width - 12, 120)
        let maxHeight = max(containerSize.height - 12, 120)
        let imageSize = image?.size ?? CGSize(width: 3, height: 2)
        let aspectRatio = max(imageSize.width, 1) / max(imageSize.height, 1)

        if maxWidth / maxHeight > aspectRatio {
            return CGSize(width: maxHeight * aspectRatio, height: maxHeight)
        }
        return CGSize(width: maxWidth, height: maxWidth / aspectRatio)
    }

    private func currentWatermarkRect(in previewSize: CGSize) -> CGRect {
        let imageSize = processor.currentWatermarkImage()?.size ?? CGSize(width: 1, height: 1)
        // 预览按显示图片短边计算水印宽度，确保与导出时的短边比例一致。
        let targetWidth = min(previewSize.width, previewSize.height) * CGFloat(processor.watermarkScalePercent) / 100.0
        let targetHeight = targetWidth * imageSize.height / max(imageSize.width, 1)
        let fitRatio = min(1, previewSize.width / max(targetWidth, 1), previewSize.height / max(targetHeight, 1))
        let width = targetWidth * fitRatio
        let height = targetHeight * fitRatio
        let size = CGSize(width: width, height: height)
        let margin = min(previewSize.width, previewSize.height) * ResizeAppSettings.watermarkEdgeMarginRatio
        let maxX = max(previewSize.width - width, 0)
        let maxY = max(previewSize.height - height, 0)

        if let preset = WatermarkPositionPreset(rawValue: processor.watermarkPositionPreset) {
            return CGRect(origin: presetTopLeftOrigin(preset, watermarkSize: size, previewSize: previewSize, margin: margin), size: size)
        }

        return CGRect(
            x: CGFloat(processor.watermarkCustomXRatio) * maxX,
            y: CGFloat(processor.watermarkCustomYRatio) * maxY,
            width: width,
            height: height
        )
    }

    private func moveWatermark(
        direction: MoveCommandDirection,
        previewSize: CGSize,
        watermarkSize: CGSize,
        currentTopLeft: CGPoint
    ) {
        let step = min(previewSize.width, previewSize.height) * 0.005
        var nextTopLeft = currentTopLeft
        let centeredX = (previewSize.width - watermarkSize.width) / 2
        let snapThreshold = horizontalSnapThreshold(for: previewSize)
        let isSnappedToCenter = abs(currentTopLeft.x - centeredX) <= 0.5
        let isInsideSnapZone = abs(currentTopLeft.x - centeredX) <= snapThreshold
        if horizontalSnapBypassDirection != 0 && !isInsideSnapZone {
            horizontalSnapBypassDirection = 0
        }
        var allowHorizontalSnap = horizontalSnapBypassDirection == 0

        switch direction {
        case .up:
            nextTopLeft.y -= step
            snapEscapeDirection = 0
            snapEscapeCount = 0
        case .down:
            nextTopLeft.y += step
            snapEscapeDirection = 0
            snapEscapeCount = 0
        case .left:
            nextTopLeft.x -= step
            if isSnappedToCenter && horizontalSnapBypassDirection == 0 {
                prepareHorizontalSnapEscape(direction: -1)
                if snapEscapeCount >= 3 {
                    nextTopLeft.x = centeredX - step
                    snapEscapeCount = 0
                    horizontalSnapBypassDirection = -1
                    allowHorizontalSnap = false
                }
            } else {
                snapEscapeDirection = 0
                snapEscapeCount = 0
            }
        case .right:
            nextTopLeft.x += step
            if isSnappedToCenter && horizontalSnapBypassDirection == 0 {
                prepareHorizontalSnapEscape(direction: 1)
                if snapEscapeCount >= 2 {
                    nextTopLeft.x = centeredX + step
                    snapEscapeCount = 0
                    horizontalSnapBypassDirection = 1
                    allowHorizontalSnap = false
                }
            } else {
                snapEscapeDirection = 0
                snapEscapeCount = 0
            }
        @unknown default:
            return
        }

        updateCustomPosition(
            from: nextTopLeft,
            previewSize: previewSize,
            watermarkSize: watermarkSize,
            allowHorizontalSnap: allowHorizontalSnap
        )
    }

    private func prepareHorizontalSnapEscape(direction: Int) {
        if snapEscapeDirection == direction {
            snapEscapeCount += 1
        } else {
            snapEscapeDirection = direction
            snapEscapeCount = 1
        }
    }

    private func updateCustomPosition(
        from topLeft: CGPoint,
        previewSize: CGSize,
        watermarkSize: CGSize,
        allowHorizontalSnap: Bool = true
    ) {
        let maxX = max(previewSize.width - watermarkSize.width, 1)
        let maxY = max(previewSize.height - watermarkSize.height, 1)
        var clampedX = min(max(topLeft.x, 0), maxX)
        let clampedY = min(max(topLeft.y, 0), maxY)

        let centeredX = (previewSize.width - watermarkSize.width) / 2
        let snapThreshold = horizontalSnapThreshold(for: previewSize)
        if allowHorizontalSnap && abs(clampedX - centeredX) <= snapThreshold {
            // 水印接近图片水平中心时自动吸附，让下中/上中之外的自定义居中更容易对齐。
            clampedX = centeredX
        }

        processor.watermarkPositionPreset = ""
        processor.watermarkCustomXRatio = Double(clampedX / maxX)
        processor.watermarkCustomYRatio = Double(clampedY / maxY)
        processor.objectWillChange.send()
    }

    private func horizontalSnapThreshold(for previewSize: CGSize) -> CGFloat {
        max(8, previewSize.width * 0.018)
    }

    private var watermarkDragPadding: CGFloat {
        24
    }

    private func presetTopLeftOrigin(
        _ preset: WatermarkPositionPreset,
        watermarkSize: CGSize,
        previewSize: CGSize,
        margin: CGFloat
    ) -> CGPoint {
        let centerX = (previewSize.width - watermarkSize.width) / 2
        let rightX = previewSize.width - watermarkSize.width - margin
        let bottomY = previewSize.height - watermarkSize.height - margin

        switch preset {
        case .topLeft:
            return CGPoint(x: margin, y: margin)
        case .topCenter:
            return CGPoint(x: centerX, y: margin)
        case .topRight:
            return CGPoint(x: rightX, y: margin)
        case .bottomLeft:
            return CGPoint(x: margin, y: bottomY)
        case .bottomCenter:
            return CGPoint(x: centerX, y: bottomY)
        case .bottomRight:
            return CGPoint(x: rightX, y: bottomY)
        }
    }
}

struct FilmFrameEditorView: View {
    @ObservedObject var processor: ProfessionalImageProcessor
    let onCancel: () -> Void
    let onComplete: () -> Void
    let chooseFilmFrame: () -> Void
    let selectBuiltin: (String) -> Void
    let selectBuiltinStyle: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isClosing = false

    var body: some View {
        HStack(spacing: 0) {
            filmFramePreviewPanel

            Divider()

            filmFrameControlPanel
        }
        .frame(width: 960, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var filmFramePreviewPanel: some View {
        GeometryReader { geometry in
            let previewImage = processor.currentFilmFramePreviewImage()
            let previewSize = fittedPreviewSize(in: CGSize(width: geometry.size.width, height: geometry.size.height - 24), image: previewImage)

            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: previewSize.width, height: previewSize.height)

                    if let previewImage {
                        Image(nsImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: previewSize.width, height: previewSize.height)
                    } else {
                        Text("预览图片区")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    if let frameImage = processor.currentFilmFrameImageForPreview() {
                        filmFrameOverlayImage(frameImage, previewSize: previewSize)
                            .id(processor.filmFramePreviewRefreshID)
                    }
                }
                .frame(width: previewSize.width, height: previewSize.height)

                if !processor.currentFilmFramePreviewRatioText().isEmpty {
                    Text("当前照片比例：\(processor.currentFilmFramePreviewRatioText())")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
        .frame(width: 680)
    }

    private var filmFrameControlPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button(action: chooseFilmFrame) {
                Text(processor.hasFilmFrameOverlay ? "更换胶片框" : "导入胶片框")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(Color(red: 1.0, green: 0.74, blue: 0.20))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Text(filmFrameRequirementText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                Text("内置胶片框")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)

                Text("样式")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    builtinStyleButton("filmName")
                    builtinStyleButton("exposureInfo")
                }

                Text("框样式比例")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 14) {
                    builtinRatioButton("2:3")
                    builtinRatioButton("3:4")
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("取消") {
                    isClosing = true
                    onCancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("完成") {
                    isClosing = true
                    onComplete()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!processor.hasFilmFrameOverlay)
            }
        }
        .padding(24)
        .frame(width: 280)
    }

    private var filmFrameRequirementText: String {
        let ratioText = processor.currentFilmFramePreviewRatioText()
        guard !ratioText.isEmpty else {
            return "必须使用与照片比例一致的 PNG 胶片框"
        }
        return "必须使用与照片比例一致\(ratioText)的 PNG 胶片框"
    }

    private func builtinStyleButton(_ styleRawValue: String) -> some View {
        let isAvailable = isBuiltinFilmFrameRatioAvailable
        let isSelected = isAvailable && processor.isFilmFrameBuiltinStyleSelected(styleRawValue)

        return Button(action: {
            guard isAvailable, !isClosing else { return }
            selectBuiltinStyle(styleRawValue)
        }) {
            Text(processor.filmFrameBuiltinStyleTitle(styleRawValue))
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 96, height: 32)
                .foregroundColor(isSelected ? .white : (isAvailable ? .primary : .secondary.opacity(0.45)))
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor).opacity(isAvailable ? 1 : 0.45))
                .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable || isClosing)
        .opacity(isAvailable ? 1 : 0.45)
    }

    private func builtinRatioButton(_ ratioText: String) -> some View {
        let isSelected = processor.isBuiltinFilmFrameSelected(ratioText)
        let isAvailable = processor.currentFilmFramePreviewRatioText() == ratioText

        return Button(action: {
            guard isAvailable, !isClosing else { return }
            selectBuiltin(ratioText)
        }) {
            Text(ratioText)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 72, height: 38)
                .foregroundColor(isSelected ? .white : (isAvailable ? .primary : .secondary.opacity(0.45)))
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor).opacity(isAvailable ? 1 : 0.45))
                .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable || isClosing)
        .opacity(isAvailable ? 1 : 0.45)
    }

    private var isBuiltinFilmFrameRatioAvailable: Bool {
        let ratioText = processor.currentFilmFramePreviewRatioText()
        return ratioText == "2:3" || ratioText == "3:4"
    }

    private func filmFrameOverlayImage(_ image: NSImage, previewSize: CGSize) -> some View {
        let needsRotation = processor.currentFilmFramePreviewNeedsRotation()

        return Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .frame(
                width: needsRotation ? previewSize.height : previewSize.width,
                height: needsRotation ? previewSize.width : previewSize.height
            )
            .rotationEffect(.degrees(needsRotation ? -90 : 0))
            .frame(width: previewSize.width, height: previewSize.height)
            .clipped()
            .allowsHitTesting(false)
    }

    private func fittedPreviewSize(in containerSize: CGSize, image: NSImage?) -> CGSize {
        let maxWidth = max(containerSize.width - 12, 120)
        let maxHeight = max(containerSize.height - 12, 120)
        let imageSize = image?.size ?? CGSize(width: 3, height: 4)
        let aspectRatio = max(imageSize.width, 1) / max(imageSize.height, 1)

        if maxWidth / maxHeight > aspectRatio {
            return CGSize(width: maxHeight * aspectRatio, height: maxHeight)
        }
        return CGSize(width: maxWidth, height: maxWidth / aspectRatio)
    }
}

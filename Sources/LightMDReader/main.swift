import AppKit
import UniformTypeIdentifiers
import WebKit

private let appDisplayName = "LightMD"
private let appBundleIdentifier = "com.kellan.lightmd"
private let themeDefaultsKey = "LightMD.SelectedTheme"
private let developerDisplayName = "Kellan / 许可"
private let developerEmail = "kenbot818@gmail.com"

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var readerWindow: ReaderWindowController?
    private var filesPendingLaunch: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        if installFromDiskImageIfNeeded() {
            return
        }

        configureMenu()

        let controller = ReaderWindowController()
        readerWindow = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        let argumentFiles = CommandLine.arguments.dropFirst().map(URL.init(fileURLWithPath:))
        let files = filesPendingLaunch + argumentFiles
        if files.isEmpty {
            controller.showWelcome()
        } else {
            controller.openFiles(files)
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map(URL.init(fileURLWithPath:))
        if let readerWindow {
            readerWindow.openFiles(urls)
            readerWindow.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            filesPendingLaunch.append(contentsOf: urls)
        }
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @MainActor
    private func configureMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "关于 \(appDisplayName)",
            action: #selector(showAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "退出 \(appDisplayName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(withTitle: "打开...", action: #selector(ReaderWindowController.openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "保存", action: #selector(ReaderWindowController.saveCurrentDocument(_:)), keyEquivalent: "s")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "导出为 PNG...", action: #selector(ReaderWindowController.exportAsPNG(_:)), keyEquivalent: "")
        fileMenu.addItem(withTitle: "导出为 PDF...", action: #selector(ReaderWindowController.exportAsPDF(_:)), keyEquivalent: "")
        fileMenu.addItem(withTitle: "导出为 HTML...", action: #selector(ReaderWindowController.exportAsHTML(_:)), keyEquivalent: "")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "关闭当前文件", action: #selector(ReaderWindowController.closeCurrentDocument(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "查看")
        viewMenu.addItem(withTitle: "缩小字体", action: #selector(ReaderWindowController.decreaseFontSize(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "放大字体", action: #selector(ReaderWindowController.increaseFontSize(_:)), keyEquivalent: "=")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @MainActor
    @objc private func showAboutPanel(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: appDisplayName,
            .applicationVersion: "0.1.0",
            .version: "MVP",
            .credits: NSAttributedString(
                string: "开发者：\(developerDisplayName)\n联系邮箱：\(developerEmail)\n© 2026 \(developerDisplayName). All rights reserved.",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        ])
    }

    @MainActor
    private func installFromDiskImageIfNeeded() -> Bool {
        let sourceURL = Bundle.main.bundleURL
        let sourcePath = sourceURL.path

        guard sourcePath.hasPrefix("/Volumes/") else {
            return false
        }

        let targetURL = URL(fileURLWithPath: "/Applications").appendingPathComponent(sourceURL.lastPathComponent)
        let fileManager = FileManager.default

        do {
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }

            try fileManager.copyItem(at: sourceURL, to: targetURL)
            NSWorkspace.shared.open(targetURL)
            NSApp.terminate(nil)
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法自动安装 \(appDisplayName)"
            alert.informativeText = "请把 \(appDisplayName) 拖到 Applications 后再打开。\n\n\(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "继续打开")
            alert.runModal()
            return false
        }
    }
}

@main
enum LightMDReaderApp {
    @MainActor
    private static let appDelegate = AppDelegate()

    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.run()
    }
}

struct MarkdownDocument: Equatable {
    let url: URL
    var content: String

    var title: String {
        url.lastPathComponent
    }

    var subtitle: String {
        url.deletingLastPathComponent().path
    }

    var monogram: String {
        let baseName = url.deletingPathExtension().lastPathComponent
        let first = baseName.trimmingCharacters(in: .whitespacesAndNewlines).first
        return first.map { String($0).uppercased() } ?? "M"
    }
}

enum ReaderTheme: Int, CaseIterable {
    case blue
    case paper
    case night

    var label: String {
        switch self {
        case .blue: return "蓝"
        case .paper: return "纸"
        case .night: return "夜"
        }
    }

    var htmlValue: String {
        switch self {
        case .blue: return "blue"
        case .paper: return "paper"
        case .night: return "night"
        }
    }

    var accentColor: NSColor {
        switch self {
        case .blue: return .systemBlue
        case .paper: return NSColor(calibratedRed: 0.65, green: 0.36, blue: 0.08, alpha: 1)
        case .night: return NSColor(calibratedRed: 0.34, green: 0.55, blue: 0.95, alpha: 1)
        }
    }

    var windowAppearance: NSAppearance? {
        switch self {
        case .blue: return nil
        case .paper: return NSAppearance(named: .aqua)
        case .night: return NSAppearance(named: .darkAqua)
        }
    }

    var readerBackgroundColor: NSColor {
        switch self {
        case .blue: return NSColor(calibratedRed: 0.985, green: 0.99, blue: 0.998, alpha: 1)
        case .paper: return NSColor(calibratedRed: 0.985, green: 0.968, blue: 0.935, alpha: 1)
        case .night: return NSColor(calibratedRed: 0.122, green: 0.133, blue: 0.157, alpha: 1)
        }
    }

    var sidebarBaseColor: NSColor {
        switch self {
        case .blue: return NSColor(calibratedWhite: 0.88, alpha: 1)
        case .paper: return NSColor(calibratedWhite: 0.86, alpha: 1)
        case .night: return NSColor(calibratedWhite: 0.17, alpha: 1)
        }
    }
}

final class MonogramIconView: NSView {
    var text: String = "" {
        didSet { needsDisplay = true }
    }

    var fillColor: NSColor = .systemBlue {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 26, height: 26)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.integral.insetBy(dx: 0.5, dy: 0.5)
        fillColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let size = attributed.size()
        let drawRect = NSRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2 - 0.5,
            width: size.width,
            height: size.height
        )
        attributed.draw(in: drawRect)
    }
}

final class RoundedReaderView: NSView {
    private let cornerRadius: CGFloat = 14

    var fillColor: NSColor = .windowBackgroundColor {
        didSet {
            layer?.backgroundColor = fillColor.cgColor
            layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.38).cgColor
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = fillColor.cgColor
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.38).cgColor
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private enum ExportFormat {
    case png
    case pdf
    case html

    var title: String {
        switch self {
        case .png: return "导出为 PNG"
        case .pdf: return "导出为 PDF"
        case .html: return "导出为 HTML"
        }
    }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .pdf: return "pdf"
        case .html: return "html"
        }
    }

    var contentType: UTType {
        switch self {
        case .png: return .png
        case .pdf: return .pdf
        case .html: return .html
        }
    }
}

private final class RenderExportSession: NSObject, WKNavigationDelegate {
    private let html: String
    private let baseURL: URL
    private let destinationURL: URL
    private let format: ExportFormat
    private let completion: (Result<Void, Error>) -> Void
    private let webView: WKWebView
    private let renderWindow: NSWindow
    private var didComplete = false

    init(html: String, baseURL: URL, destinationURL: URL, format: ExportFormat, completion: @escaping (Result<Void, Error>) -> Void) {
        self.html = html
        self.baseURL = baseURL
        self.destinationURL = destinationURL
        self.format = format
        self.completion = completion
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 980, height: 700))
        self.renderWindow = NSWindow(
            contentRect: NSRect(x: -12000, y: -12000, width: 980, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        renderWindow.contentView = webView
    }

    func start() {
        renderWindow.orderBack(nil)
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let script = """
        (() => {
          document.body.classList.remove('editing');
          const width = Math.max(document.documentElement.scrollWidth, document.body.scrollWidth, 980);
          const height = Math.max(document.documentElement.scrollHeight, document.body.scrollHeight, 700);
          return { width, height };
        })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else { return }
            if let error {
                self.finish(.failure(error))
                return
            }

            let size = self.exportSize(from: result)
            self.webView.frame = NSRect(origin: .zero, size: size)
            self.renderWindow.setFrame(NSRect(x: -12000, y: -12000, width: size.width, height: size.height), display: true)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.writeExport(size: size)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    private func exportSize(from result: Any?) -> NSSize {
        let dictionary = result as? [String: Any]
        let width = number(dictionary?["width"], fallback: 980)
        let height = number(dictionary?["height"], fallback: 700)
        return NSSize(
            width: min(max(width, 980), 2400),
            height: min(max(height, 700), 30000)
        )
    }

    private func number(_ value: Any?, fallback: CGFloat) -> CGFloat {
        if let number = value as? NSNumber {
            return CGFloat(truncating: number)
        }
        if let value = value as? CGFloat {
            return value
        }
        if let value = value as? Double {
            return CGFloat(value)
        }
        return fallback
    }

    private func writeExport(size: NSSize) {
        switch format {
        case .png:
            let configuration = WKSnapshotConfiguration()
            configuration.rect = NSRect(origin: .zero, size: size)
            webView.takeSnapshot(with: configuration) { [weak self] image, error in
                guard let self else { return }
                if let error {
                    self.finish(.failure(error))
                    return
                }
                guard let image,
                      let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    self.finish(.failure(Self.error("无法生成 PNG 图片。")))
                    return
                }

                do {
                    try pngData.write(to: self.destinationURL)
                    self.finish(.success(()))
                } catch {
                    self.finish(.failure(error))
                }
            }

        case .pdf:
            if #available(macOS 11.0, *) {
                let configuration = WKPDFConfiguration()
                configuration.rect = NSRect(origin: .zero, size: size)
                webView.createPDF(configuration: configuration) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success(let data):
                        do {
                            try data.write(to: self.destinationURL)
                            self.finish(.success(()))
                        } catch {
                            self.finish(.failure(error))
                        }
                    case .failure(let error):
                        self.finish(.failure(error))
                    }
                }
            } else {
                finish(.failure(Self.error("当前 macOS 版本不支持 PDF 导出。")))
            }

        case .html:
            finish(.failure(Self.error("HTML 导出不需要渲染会话。")))
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        guard !didComplete else { return }
        didComplete = true
        renderWindow.orderOut(nil)
        completion(result)
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "LightMD.Export", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

final class ReaderWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let renderer = MarkdownRenderer()
    private var documents: [MarkdownDocument] = []
    private var selectedIndex: Int?
    private var currentTheme: ReaderTheme = ReaderTheme(rawValue: UserDefaults.standard.integer(forKey: themeDefaultsKey)) ?? .blue

    private let sidebarWidth: CGFloat = 240
    private let readerOverlap: CGFloat = 22
    private let readerContainer = RoundedReaderView()
    private let tableView = NSTableView()
    private let webView = WKWebView()
    private let titleLabel = NSTextField(labelWithString: appDisplayName)
    private let detailLabel = NSTextField(labelWithString: "双击即读 Markdown")
    private let openButton = NSButton(title: "", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "只读")
    private let modeControl = NSSegmentedControl(labels: ["阅读", "编辑"], trackingMode: .selectOne, target: nil, action: nil)
    private let saveButton = NSButton(title: "保存", target: nil, action: nil)
    private let searchField = NSSearchField()
    private let previousMatchButton = NSButton(title: "", target: nil, action: nil)
    private let nextMatchButton = NSButton(title: "", target: nil, action: nil)
    private let decreaseFontButton = NSButton(title: "A-", target: nil, action: nil)
    private let increaseFontButton = NSButton(title: "A+", target: nil, action: nil)
    private let exportButton = NSPopUpButton()
    private let themeControl = NSSegmentedControl(labels: ReaderTheme.allCases.map(\.label), trackingMode: .selectOne, target: nil, action: nil)
    private var fontScale = 1.0
    private var keyMonitor: Any?
    private var exportSessions: [RenderExportSession] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = appDisplayName
        window.minSize = NSSize(width: 920, height: 520)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.appearance = currentTheme.windowAppearance
        super.init(window: window)
        setupUI()
        installKeyboardShortcuts()
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "markdown"),
            UTType.plainText
        ].compactMap { $0 }

        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK else { return }
            self?.openFiles(panel.urls)
        }
    }

    @objc func closeCurrentDocument(_ sender: Any?) {
        guard let selectedIndex, documents.indices.contains(selectedIndex) else { return }
        documents.remove(at: selectedIndex)
        tableView.reloadData()

        if documents.isEmpty {
            self.selectedIndex = nil
            showWelcome()
            return
        }

        updateStatus()
        let nextIndex = min(selectedIndex, documents.count - 1)
        selectDocument(at: nextIndex)
    }

    func openFiles(_ urls: [URL]) {
        let readableFiles = urls.filter { ["md", "markdown", "txt"].contains($0.pathExtension.lowercased()) }
        var firstNewIndex: Int?

        for url in readableFiles {
            if let existingIndex = documents.firstIndex(where: { $0.url == url }) {
                firstNewIndex = firstNewIndex ?? existingIndex
                continue
            }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let document = MarkdownDocument(url: url, content: content)
                documents.append(document)
                firstNewIndex = firstNewIndex ?? (documents.count - 1)
            } catch {
                showError("无法打开文件", detail: "\(url.lastPathComponent)\n\(error.localizedDescription)")
            }
        }

        tableView.reloadData()
        updateStatus()

        if let firstNewIndex {
            selectDocument(at: firstNewIndex)
        } else if documents.isEmpty {
            showWelcome()
        }
    }

    func showWelcome() {
        titleLabel.stringValue = appDisplayName
        detailLabel.stringValue = "只读 · 等待打开 Markdown"
        modeControl.selectedSegment = 0
        updateMode()
        updateStatus()
        webView.loadHTMLString(renderer.welcomeHTML(theme: currentTheme), baseURL: nil)
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = currentTheme.sidebarBaseColor.cgColor

        let sidebar = NSVisualEffectView()
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        let sidebarHeader = NSStackView()
        sidebarHeader.orientation = .horizontal
        sidebarHeader.alignment = .centerY
        sidebarHeader.spacing = 8
        sidebarHeader.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 8, right: 10)
        sidebarHeader.translatesAutoresizingMaskIntoConstraints = false

        let appLabel = NSTextField(labelWithString: "打开的文件")
        appLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        appLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        openButton.target = self
        openButton.action = #selector(openDocument(_:))
        openButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "打开文件")
        openButton.imagePosition = .imageOnly
        openButton.bezelStyle = .rounded
        openButton.controlSize = .small
        openButton.toolTip = "打开 Markdown 文件"
        sidebarHeader.addArrangedSubview(appLabel)
        sidebarHeader.addArrangedSubview(openButton)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.rowHeight = 54
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        scrollView.documentView = tableView

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        sidebar.addSubview(sidebarHeader)
        sidebar.addSubview(scrollView)
        sidebar.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            sidebarHeader.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            sidebarHeader.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -readerOverlap),
            sidebarHeader.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 46),
            scrollView.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -readerOverlap),
            scrollView.topAnchor.constraint(equalTo: sidebarHeader.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),
            statusLabel.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12 - readerOverlap),
            statusLabel.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -12)
        ])

        readerContainer.translatesAutoresizingMaskIntoConstraints = false
        readerContainer.fillColor = currentTheme.readerBackgroundColor

        let reader = NSStackView()
        reader.orientation = .vertical
        reader.spacing = 0
        reader.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 14
        header.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 8, right: 24)
        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.spacing = 2
        titleStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(detailLabel)

        modeControl.selectedSegment = 0
        modeControl.target = self
        modeControl.action = #selector(modeChanged(_:))
        modeControl.controlSize = .small
        modeControl.segmentStyle = .rounded
        modeControl.setWidth(54, forSegment: 0)
        modeControl.setWidth(54, forSegment: 1)

        saveButton.target = self
        saveButton.action = #selector(saveCurrentDocument(_:))
        saveButton.bezelStyle = .rounded
        saveButton.controlSize = .small
        saveButton.toolTip = "保存当前 Markdown 文件"
        saveButton.isHidden = true

        searchField.placeholderString = "查找"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.controlSize = .small
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        configureIconButton(previousMatchButton, symbol: "chevron.up", tooltip: "上一个匹配")
        previousMatchButton.action = #selector(findPrevious(_:))
        configureIconButton(nextMatchButton, symbol: "chevron.down", tooltip: "下一个匹配")
        nextMatchButton.action = #selector(findNext(_:))
        configureTextButton(decreaseFontButton, tooltip: "缩小字体")
        decreaseFontButton.action = #selector(decreaseFontSize(_:))
        configureTextButton(increaseFontButton, tooltip: "放大字体")
        increaseFontButton.action = #selector(increaseFontSize(_:))

        exportButton.pullsDown = true
        exportButton.bezelStyle = .rounded
        exportButton.controlSize = .small
        exportButton.toolTip = "导出当前文档"
        exportButton.menu = NSMenu()
        exportButton.menu?.addItem(withTitle: "导出", action: nil, keyEquivalent: "")
        exportButton.menu?.addItem(withTitle: "PNG", action: #selector(exportAsPNG(_:)), keyEquivalent: "")
        exportButton.menu?.addItem(withTitle: "PDF", action: #selector(exportAsPDF(_:)), keyEquivalent: "")
        exportButton.menu?.addItem(withTitle: "HTML", action: #selector(exportAsHTML(_:)), keyEquivalent: "")
        exportButton.menu?.items.forEach { $0.target = self }

        themeControl.selectedSegment = currentTheme.rawValue
        themeControl.target = self
        themeControl.action = #selector(themeChanged(_:))
        themeControl.controlSize = .small
        themeControl.segmentStyle = .rounded
        for index in ReaderTheme.allCases.indices {
            themeControl.setWidth(34, forSegment: index)
        }

        let controls = NSStackView(views: [modeControl, saveButton, searchField, previousMatchButton, nextMatchButton, decreaseFontButton, increaseFontButton, exportButton, themeControl])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 6

        header.addArrangedSubview(titleStack)
        header.addArrangedSubview(controls)

        let contentSeparator = NSBox()
        contentSeparator.boxType = .separator
        contentSeparator.translatesAutoresizingMaskIntoConstraints = false

        webView.setValue(false, forKey: "drawsBackground")
        reader.addArrangedSubview(header)
        reader.addArrangedSubview(contentSeparator)
        reader.addArrangedSubview(webView)
        readerContainer.addSubview(reader)
        NSLayoutConstraint.activate([
            reader.leadingAnchor.constraint(equalTo: readerContainer.leadingAnchor),
            reader.trailingAnchor.constraint(equalTo: readerContainer.trailingAnchor),
            reader.topAnchor.constraint(equalTo: readerContainer.topAnchor),
            reader.bottomAnchor.constraint(equalTo: readerContainer.bottomAnchor)
        ])

        contentView.addSubview(sidebar)
        contentView.addSubview(readerContainer)

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: sidebarWidth),
            readerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sidebarWidth - readerOverlap),
            readerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            readerContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            readerContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        window?.center()
    }

    private func installKeyboardShortcuts() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
                  event.charactersIgnoringModifiers?.lowercased() == "s" else {
                return event
            }
            self.saveCurrentDocument(nil)
            return nil
        }
    }

    private func configureIconButton(_ button: NSButton, symbol: String, tooltip: String) {
        button.target = self
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.imagePosition = .imageOnly
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.toolTip = tooltip
    }

    private func configureTextButton(_ button: NSButton, tooltip: String) {
        button.target = self
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.toolTip = tooltip
        button.font = .systemFont(ofSize: 11, weight: .semibold)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        documents.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard documents.indices.contains(row) else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("DocumentCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = identifier

        cell.subviews.forEach { $0.removeFromSuperview() }

        let icon = MonogramIconView()
        icon.text = documents[row].monogram
        icon.fillColor = currentTheme.accentColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 26),
            icon.heightAnchor.constraint(equalToConstant: 26)
        ])

        let title = NSTextField(labelWithString: documents[row].title)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.lineBreakMode = .byTruncatingMiddle

        let path = NSTextField(labelWithString: documents[row].subtitle)
        path.font = .systemFont(ofSize: 11)
        path.textColor = .secondaryLabelColor
        path.lineBreakMode = .byTruncatingMiddle

        let textStack = NSStackView(views: [title, path])
        textStack.orientation = .vertical
        textStack.spacing = 3

        let stack = NSStackView(views: [icon, textStack])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectDocument(at: tableView.selectedRow)
    }

    private func selectDocument(at index: Int) {
        guard documents.indices.contains(index) else { return }
        selectedIndex = index
        if tableView.selectedRow != index {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }

        let document = documents[index]
        titleLabel.stringValue = document.title
        detailLabel.stringValue = "\(modeLabel()) · \(formattedSize(for: document.content)) · \(document.subtitle)"
        window?.title = document.title
        updateStatus()
        webView.loadHTMLString(renderer.render(document.content, title: document.title, theme: currentTheme), baseURL: document.url.deletingLastPathComponent())
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.applyFontScale()
            self?.updateMode()
        }
        updateMode()
    }

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        updateMode()
    }

    @objc func saveCurrentDocument(_ sender: Any?) {
        guard let selectedIndex, documents.indices.contains(selectedIndex) else { return }
        let url = documents[selectedIndex].url

        webView.evaluateJavaScript("window.lightMDExportMarkdown && window.lightMDExportMarkdown();") { [weak self] result, error in
            guard let self else { return }
            if let error {
                self.showError("无法保存文件", detail: error.localizedDescription)
                return
            }
            guard let content = result as? String else {
                self.showError("无法保存文件", detail: "页面内容无法转换为 Markdown。")
                return
            }

            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                self.documents[selectedIndex].content = content
                self.tableView.reloadData()
                self.detailLabel.stringValue = "\(self.modeLabel()) · \(self.formattedSize(for: content)) · \(self.documents[selectedIndex].subtitle)"
                self.webView.loadHTMLString(self.renderer.render(content, title: self.documents[selectedIndex].title, theme: self.currentTheme), baseURL: url.deletingLastPathComponent())
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.applyFontScale()
                    self?.updateMode()
                }
            } catch {
                self.showError("无法保存文件", detail: "\(url.lastPathComponent)\n\(error.localizedDescription)")
            }
        }
    }

    @objc func exportAsPNG(_ sender: Any?) {
        exportCurrentDocument(as: .png)
    }

    @objc func exportAsPDF(_ sender: Any?) {
        exportCurrentDocument(as: .pdf)
    }

    @objc func exportAsHTML(_ sender: Any?) {
        exportCurrentDocument(as: .html)
    }

    private func exportCurrentDocument(as format: ExportFormat) {
        guard let selectedIndex, documents.indices.contains(selectedIndex) else {
            showError("无法导出", detail: "请先打开一个 Markdown 文件。")
            return
        }

        let document = documents[selectedIndex]
        let panel = NSSavePanel()
        panel.title = format.title
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = document.url.deletingPathExtension().lastPathComponent + "." + format.fileExtension
        panel.canCreateDirectories = true

        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let destinationURL = panel.url else { return }
            self?.export(document: document, to: destinationURL, as: format)
        }
    }

    private func export(document: MarkdownDocument, to destinationURL: URL, as format: ExportFormat) {
        currentMarkdown { [weak self] markdown in
            guard let self else { return }
            let html = self.renderer.render(markdown, title: document.title, theme: self.currentTheme)

            if format == .html {
                do {
                    try html.write(to: destinationURL, atomically: true, encoding: .utf8)
                    self.showExportSuccess(destinationURL)
                } catch {
                    self.showError("导出失败", detail: error.localizedDescription)
                }
                return
            }

            var session: RenderExportSession?
            session = RenderExportSession(
                html: html,
                baseURL: document.url.deletingLastPathComponent(),
                destinationURL: destinationURL,
                format: format
            ) { [weak self, weak session] result in
                guard let self else { return }
                if let session {
                    self.exportSessions.removeAll { $0 === session }
                }

                switch result {
                case .success:
                    self.showExportSuccess(destinationURL)
                case .failure(let error):
                    self.showError("导出失败", detail: error.localizedDescription)
                }
            }

            if let session {
                self.exportSessions.append(session)
                session.start()
            }
        }
    }

    private func currentMarkdown(completion: @escaping (String) -> Void) {
        guard let selectedIndex, documents.indices.contains(selectedIndex) else {
            completion("")
            return
        }

        webView.evaluateJavaScript("window.lightMDExportMarkdown && window.lightMDExportMarkdown();") { [weak self] result, _ in
            guard let self else { return }
            let fallback = self.documents[selectedIndex].content
            let markdown = (result as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallback
            completion(markdown)
        }
    }

    private func showExportSuccess(_ url: URL) {
        let alert = NSAlert()
        alert.messageText = "导出完成"
        alert.informativeText = url.path
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.addButton(withTitle: "在 Finder 中显示")
        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func updateMode() {
        let isEditing = modeControl.selectedSegment == 1
        saveButton.isHidden = !isEditing
        searchField.isHidden = isEditing
        previousMatchButton.isHidden = isEditing
        nextMatchButton.isHidden = isEditing
        webView.evaluateJavaScript("window.lightMDSetEditing && window.lightMDSetEditing(\(isEditing ? "true" : "false"));")
        detailLabel.stringValue = detailLabel.stringValue.replacingOccurrences(of: isEditing ? "只读" : "编辑", with: modeLabel())
        updateStatus()
    }

    @objc private func themeChanged(_ sender: NSSegmentedControl) {
        guard let theme = ReaderTheme(rawValue: sender.selectedSegment) else { return }
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: themeDefaultsKey)
        window?.appearance = theme.windowAppearance
        window?.contentView?.layer?.backgroundColor = theme.sidebarBaseColor.cgColor
        readerContainer.fillColor = theme.readerBackgroundColor
        tableView.reloadData()
        reloadCurrentDocument()
    }

    private func reloadCurrentDocument() {
        guard let selectedIndex, documents.indices.contains(selectedIndex) else {
            webView.loadHTMLString(renderer.welcomeHTML(theme: currentTheme), baseURL: nil)
            return
        }

        let document = documents[selectedIndex]
        webView.loadHTMLString(renderer.render(document.content, title: document.title, theme: currentTheme), baseURL: document.url.deletingLastPathComponent())
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.applyFontScale()
            self?.updateMode()
        }
    }

    private func modeLabel() -> String {
        modeControl.selectedSegment == 1 ? "编辑" : "只读"
    }

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        runFind(backwards: false)
    }

    @objc private func findNext(_ sender: Any?) {
        runFind(backwards: false)
    }

    @objc private func findPrevious(_ sender: Any?) {
        runFind(backwards: true)
    }

    @objc func increaseFontSize(_ sender: Any?) {
        fontScale = min(fontScale + 0.08, 1.4)
        applyFontScale()
    }

    @objc func decreaseFontSize(_ sender: Any?) {
        fontScale = max(fontScale - 0.08, 0.82)
        applyFontScale()
    }

    private func runFind(backwards: Bool) {
        let query = searchField.stringValue
        guard !query.isEmpty else { return }
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")
        webView.evaluateJavaScript("window.find('\(escaped)', false, \(backwards ? "true" : "false"), true, false, true, false);")
    }

    private func applyFontScale() {
        webView.evaluateJavaScript("document.documentElement.style.setProperty('--font-scale', '\(fontScale)');")
    }

    private func updateStatus() {
        if documents.isEmpty {
            statusLabel.stringValue = "\(modeLabel()) · 未打开文件"
        } else {
            statusLabel.stringValue = "\(modeLabel()) · \(documents.count) 个文件"
        }
    }

    private func formattedSize(for content: String) -> String {
        let bytes = content.lengthOfBytes(using: .utf8)
        if bytes < 1024 {
            return "\(bytes) B"
        }
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        return String(format: "%.1f MB", kb / 1024)
    }

    private func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}

final class MarkdownRenderer {
    func welcomeHTML(theme: ReaderTheme) -> String {
        pageHTML(
            title: appDisplayName,
            body: """
            <section class="welcome">
              <div class="brand-mark">#</div>
              <h1>双击即读 Markdown</h1>
              <p>为 AI 工具生成的临时文档准备的轻便阅读视图。</p>
              <p class="muted">只读预览 · 本地文件 · 不建知识库</p>
            </section>
            """,
            theme: theme
        )
    }

    func render(_ markdown: String, title: String, theme: ReaderTheme) -> String {
        pageHTML(
            title: title,
            body: markdownToHTML(markdown),
            tableOfContents: tableOfContentsHTML(markdown),
            sourceMarkdown: markdown,
            theme: theme
        )
    }

    private func pageHTML(title: String, body: String, tableOfContents: String = "", sourceMarkdown: String = "", theme: ReaderTheme) -> String {
        """
        <!doctype html>
        <html data-theme="\(theme.htmlValue)">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escapeHTML(title))</title>
          <style>
            \(muyaCSS())
            :root {
              color-scheme: light dark;
              --font-scale: 1;
              --bg: #fbfcfe;
              --fg: #1d2433;
              --muted: #667085;
              --border: #d6deea;
              --code-bg: #f2f5f9;
              --quote-bg: #f4f8fb;
              --link: #1769e0;
              --accent: #1769e0;
              --focus-ring: color-mix(in srgb, var(--link) 34%, transparent);
            }
            html[data-theme="paper"] {
              color-scheme: light;
              --bg: #fbf7ef;
              --fg: #2d251c;
              --muted: #7a6c5d;
              --border: #ded2bf;
              --code-bg: #f1e8d8;
              --quote-bg: #f5ecdf;
              --link: #a35b11;
              --accent: #a35b11;
              --focus-ring: rgba(163, 91, 17, 0.24);
            }
            html[data-theme="night"] {
              color-scheme: dark;
              --bg: #1f2228;
              --fg: #edf1f7;
              --muted: #a8b1c1;
              --border: #3a4250;
              --code-bg: #292f38;
              --quote-bg: #252d35;
              --link: #8bb8ff;
              --accent: #8bb8ff;
              --focus-ring: rgba(139, 184, 255, 0.28);
            }
            @media (prefers-color-scheme: dark) {
              html[data-theme="blue"] {
                --bg: #1f2228;
                --fg: #edf1f7;
                --muted: #a8b1c1;
                --border: #3a4250;
                --code-bg: #292f38;
                --quote-bg: #252d35;
                --link: #8bb8ff;
                --accent: #8bb8ff;
              }
            }
            body {
              margin: 0;
              background: var(--bg);
              color: var(--fg);
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
              font-size: calc(16px * var(--font-scale));
              line-height: 1.72;
            }
            main {
              max-width: 720px;
              margin: 0 auto;
              padding: 40px 76px 72px 48px;
            }
            .toc-panel {
              position: fixed;
              top: 92px;
              right: 0;
              width: 210px;
              max-height: calc(100vh - 124px);
              overflow: auto;
              padding: 12px 14px 12px 18px;
              border: 1px solid var(--border);
              border-right: 0;
              border-radius: 8px;
              background: color-mix(in srgb, var(--bg) 92%, transparent);
              backdrop-filter: blur(18px);
              box-sizing: border-box;
              box-shadow: 0 12px 30px rgba(16, 24, 40, 0.08);
              transform: translateX(196px);
              opacity: 0.68;
              transition: transform 180ms ease, opacity 180ms ease, box-shadow 180ms ease;
            }
            .toc-panel::before {
              content: "";
              position: absolute;
              top: 14px;
              left: 0;
              width: 4px;
              height: calc(100% - 28px);
              border-radius: 99px;
              background: var(--link);
            }
            .toc-panel:hover,
            .toc-panel:focus-within {
              transform: translateX(0);
              opacity: 1;
              box-shadow: 0 16px 40px rgba(16, 24, 40, 0.14);
            }
            .toc-panel a {
              display: block;
              color: var(--muted);
              text-decoration: none;
              font-size: 0.82rem;
              line-height: 1.35;
              padding: 4px 0;
              overflow: hidden;
              text-overflow: ellipsis;
              white-space: nowrap;
            }
            .toc-panel a:hover {
              color: var(--link);
            }
            .toc-level-2 { padding-left: 10px !important; }
            .toc-level-3, .toc-level-4, .toc-level-5, .toc-level-6 { padding-left: 20px !important; }
            @media (max-width: 900px) {
              main {
                padding-right: 48px;
              }
              .toc-panel {
                display: none;
              }
            }
            .welcome {
              padding-top: 18vh;
              max-width: 560px;
            }
            .brand-mark {
              display: inline-flex;
              align-items: center;
              justify-content: center;
              width: 52px;
              height: 52px;
              border-radius: 14px;
              margin-bottom: 18px;
              background: var(--link);
              color: white;
              font-size: 28px;
              font-weight: 800;
              line-height: 1;
            }
            h1, h2, h3, h4, h5, h6 {
              line-height: 1.28;
              margin: 1.45em 0 0.55em;
              letter-spacing: 0;
            }
            h1:first-child, h2:first-child, h3:first-child {
              margin-top: 0;
            }
            h1 { font-size: 2.08rem; }
            h2 { font-size: 1.55rem; border-bottom: 1px solid var(--border); padding-bottom: 0.25em; }
            h3 { font-size: 1.25rem; }
            p { margin: 0.65em 0; }
            a { color: var(--link); }
            code {
              background: var(--code-bg);
              border-radius: 5px;
              padding: 0.12em 0.35em;
              font-family: "SF Mono", Menlo, Consolas, monospace;
              font-size: 0.92em;
            }
            pre {
              background: var(--code-bg);
              border: 1px solid var(--border);
              border-radius: 7px;
              overflow: auto;
              padding: 14px 16px;
            }
            pre code {
              background: transparent;
              padding: 0;
              border-radius: 0;
              font-size: 0.9rem;
            }
            blockquote {
              margin: 1em 0;
              padding: 0.75em 1em;
              border-left: 4px solid var(--accent);
              background: var(--quote-bg);
              color: var(--fg);
            }
            ul, ol {
              padding-left: 1.5em;
            }
            table {
              width: 100%;
              border-collapse: collapse;
              margin: 1em 0;
              font-size: 0.95em;
            }
            th, td {
              border: 1px solid var(--border);
              padding: 8px 10px;
              vertical-align: top;
            }
            th {
              background: var(--code-bg);
              text-align: left;
            }
            hr {
              border: 0;
              border-top: 1px solid var(--border);
              margin: 2em 0;
            }
            img {
              max-width: 100%;
              height: auto;
            }
            .muted {
              color: var(--muted);
            }
            body.editing main {
              display: none;
            }
            body.editing .toc-panel {
              display: none;
            }
            #lightmd-source {
              display: none;
            }
            .editor-shell {
              display: none;
              box-sizing: border-box;
              width: 100%;
              min-height: calc(100vh - 92px);
              margin: 0;
              padding: 0;
              border: 0;
              overflow-x: hidden;
              overflow-y: auto;
              background: var(--bg);
              box-shadow: none;
            }
            body.editing .editor-shell {
              display: block;
            }
            #lightmd-editor {
              box-sizing: border-box;
              width: min(860px, calc(100% - 96px));
              min-height: calc(100vh - 92px);
              margin: 0 auto;
              padding: 38px 0 72px;
              color: var(--fg);
              caret-color: var(--link);
              --editor-bg-color: var(--bg);
              --editor-color: var(--fg);
              --editor-border-color: var(--border);
              --editor-primary-color: var(--link);
              --editor-select-bg-color: var(--focus-ring);
            }
            #lightmd-editor,
            #lightmd-editor * {
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
              letter-spacing: 0;
            }
            #lightmd-editor .ag-front-menu,
            #lightmd-editor .mu-front-menu,
            #lightmd-editor .mu-quick-insert,
            #lightmd-editor .ag-tool-bar,
            #lightmd-editor .mu-tool-bar {
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
            }
            #lightmd-editor h1,
            #lightmd-editor h2,
            #lightmd-editor h3,
            #lightmd-editor h4,
            #lightmd-editor h5,
            #lightmd-editor h6 {
              color: var(--fg);
              line-height: 1.28;
              border: 0;
            }
            #lightmd-editor h1 { font-size: calc(2.08rem * var(--font-scale)); }
            #lightmd-editor h2 {
              font-size: calc(1.55rem * var(--font-scale));
              border-bottom: 1px solid var(--border);
              padding-bottom: 0.25em;
            }
            #lightmd-editor h3 { font-size: calc(1.25rem * var(--font-scale)); }
            #lightmd-editor p,
            #lightmd-editor li,
            #lightmd-editor blockquote,
            #lightmd-editor table {
              font-size: calc(16px * var(--font-scale));
              line-height: 1.72;
              color: var(--fg);
            }
            #lightmd-editor blockquote {
              border-left-color: var(--accent);
              background: var(--quote-bg);
            }
            #lightmd-editor pre,
            #lightmd-editor code {
              font-family: "SF Mono", Menlo, Consolas, monospace;
              background: var(--code-bg);
              color: var(--fg);
            }
            #lightmd-editor a {
              color: var(--link);
            }
            #lightmd-editor [contenteditable="true"]:focus {
              outline: 0;
            }
          </style>
          \(muyaScriptTag())
          <script>
            function lightMDSetEditing(enabled) {
              const main = document.querySelector('main');
              const source = document.querySelector('#lightmd-source');
              if (!main) return;
              document.body.classList.toggle('editing', enabled);
              if (enabled) {
                const editor = lightMDEnsureEditor();
                if (editor) editor.focus();
              } else if (window.lightMDMuya) {
                source.value = lightMDGetEditorMarkdown();
              }
            }

            function lightMDEnsureEditor() {
              if (window.lightMDMuya) return window.lightMDMuya;
              const container = document.querySelector('#lightmd-editor');
              const source = document.querySelector('#lightmd-source');
              const Muya = window.LightMDMuya;
              if (!container || !source || !Muya) return null;
              window.lightMDMuya = new Muya(container, {});
              window.lightMDMuya.init();
              window.lightMDMuya.setContent(source.value || '');
              window.lightMDMuya.on && window.lightMDMuya.on('change', () => {
                source.value = lightMDGetEditorMarkdown();
              });
              window.setTimeout(() => window.lightMDMuya && window.lightMDMuya.focus(), 0);
              return window.lightMDMuya;
            }

            function lightMDGetEditorMarkdown() {
              if (!window.lightMDMuya) return '';
              if (typeof window.lightMDMuya.getMarkdown === 'function') {
                return window.lightMDMuya.getMarkdown();
              }
              return '';
            }

            function lightMDEscape(text) {
              return (text || '').replace(/\\\\/g, '\\\\\\\\').replace(/`/g, '\\\\`').trim();
            }

            function lightMDInline(node) {
              if (node.nodeType === Node.TEXT_NODE) return node.textContent || '';
              if (node.nodeType !== Node.ELEMENT_NODE) return '';
              const tag = node.tagName.toLowerCase();
              const inner = Array.from(node.childNodes).map(lightMDInline).join('');
              if (tag === 'strong' || tag === 'b') return '**' + inner + '**';
              if (tag === 'em' || tag === 'i') return '*' + inner + '*';
              if (tag === 'code') return '`' + lightMDEscape(inner) + '`';
              if (tag === 'a') return '[' + inner + '](' + (node.getAttribute('href') || '') + ')';
              if (tag === 'br') return '\\n';
              return inner;
            }

            function lightMDBlock(node) {
              if (node.nodeType !== Node.ELEMENT_NODE) return '';
              const tag = node.tagName.toLowerCase();
              const inline = () => lightMDInline(node).trim();
              if (/^h[1-6]$/.test(tag)) return '#'.repeat(Number(tag[1])) + ' ' + inline();
              if (tag === 'p' || tag === 'div') {
                const text = inline();
                return text || lightMDElements(node);
              }
              if (tag === 'blockquote') {
                return lightMDElements(node).split('\\n').map(line => line ? '> ' + line : '>').join('\\n');
              }
              if (tag === 'pre') return '```\\n' + (node.innerText || '').replace(/\\n$/, '') + '\\n```';
              if (tag === 'ul') {
                return Array.from(node.children).filter(li => li.tagName.toLowerCase() === 'li').map(li => '- ' + lightMDInline(li).trim()).join('\\n');
              }
              if (tag === 'ol') {
                return Array.from(node.children).filter(li => li.tagName.toLowerCase() === 'li').map((li, i) => (i + 1) + '. ' + lightMDInline(li).trim()).join('\\n');
              }
              if (tag === 'table') {
                const rows = Array.from(node.querySelectorAll('tr')).map(row => Array.from(row.children).map(cell => lightMDInline(cell).trim()));
                if (!rows.length) return '';
                const header = rows[0];
                const separator = header.map(() => '---');
                const body = rows.slice(1);
                return [header, separator, ...body].map(row => '| ' + row.join(' | ') + ' |').join('\\n');
              }
              if (tag === 'hr') return '---';
              return lightMDElements(node);
            }

            function lightMDElements(root) {
              return Array.from(root.children).map(lightMDBlock).filter(Boolean).join('\\n\\n');
            }

            function lightMDExportMarkdown() {
              if (window.lightMDMuya) {
                const markdown = lightMDGetEditorMarkdown();
                const source = document.querySelector('#lightmd-source');
                if (source) source.value = markdown;
                return markdown.trimEnd() + '\\n';
              }
              const main = document.querySelector('main');
              return main ? lightMDElements(main).trim() + '\\n' : '';
            }
          </script>
        </head>
        <body>
          \(tableOfContents)
          <textarea id="lightmd-source">\(escapeHTML(sourceMarkdown))</textarea>
          <section class="editor-shell">
            <div id="lightmd-editor"></div>
          </section>
          <main>
            \(body)
          </main>
        </body>
        </html>
        """
    }

    private func muyaCSS() -> String {
        resourceText(named: "muya-style", extension: "css", subdirectory: "Muya")
    }

    private func muyaScriptTag() -> String {
        if let url = resourceURL(named: "lightmd-muya.bundle", extension: "js", subdirectory: "Muya") {
            return #"<script src="\#(escapeHTML(url.absoluteString))"></script>"#
        }

        let script = resourceText(named: "lightmd-muya.bundle", extension: "js", subdirectory: "Muya")
            .replacingOccurrences(of: "</script", with: "<\\/script")
        return "<script>\(script)</script>"
    }

    private func resourceText(named name: String, extension fileExtension: String, subdirectory: String) -> String {
        if let bundleURL = resourceURL(named: name, extension: fileExtension, subdirectory: subdirectory),
           let text = try? String(contentsOf: bundleURL, encoding: .utf8) {
            return text
        }
        return ""
    }

    private func resourceURL(named name: String, extension fileExtension: String, subdirectory: String) -> URL? {
        if let bundleURL = Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: subdirectory) {
            return bundleURL
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectURL = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let localURL = projectURL
            .appendingPathComponent("Assets")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent("\(name).\(fileExtension)")
        return FileManager.default.fileExists(atPath: localURL.path) ? localURL : nil
    }

    private func markdownToHTML(_ markdown: String) -> String {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var index = 0
        var headingIndex = 0
        var output: [String] = []

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                output.append("<hr>")
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let fence = String(trimmed.prefix(3))
                index += 1
                var codeLines: [String] = []
                while index < lines.count {
                    let current = lines[index]
                    if current.trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                        index += 1
                        break
                    }
                    codeLines.append(current)
                    index += 1
                }
                output.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
                continue
            }

            if let heading = headingHTML(for: trimmed, index: &headingIndex) {
                output.append(heading)
                index += 1
                continue
            }

            if isTableStart(lines, at: index) {
                let table = parseTable(lines, startingAt: index)
                output.append(table.html)
                index = table.nextIndex
                continue
            }

            if isUnorderedListLine(trimmed) {
                let list = parseList(lines, startingAt: index, ordered: false)
                output.append(list.html)
                index = list.nextIndex
                continue
            }

            if isOrderedListLine(trimmed) {
                let list = parseList(lines, startingAt: index, ordered: true)
                output.append(list.html)
                index = list.nextIndex
                continue
            }

            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard current.hasPrefix(">") else { break }
                    let text = current.dropFirst().trimmingCharacters(in: .whitespaces)
                    quoteLines.append(String(text))
                    index += 1
                }
                output.append("<blockquote>\(markdownToHTML(quoteLines.joined(separator: "\n")))</blockquote>")
                continue
            }

            var paragraphLines: [String] = [trimmed]
            index += 1
            while index < lines.count {
                let next = lines[index].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || isBlockStart(lines, at: index) {
                    break
                }
                paragraphLines.append(next)
                index += 1
            }
            output.append("<p>\(inlineHTML(paragraphLines.joined(separator: " ")))</p>")
        }

        return output.joined(separator: "\n")
    }

    private func tableOfContentsHTML(_ markdown: String) -> String {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var headingIndex = 0
        var links: [String] = []

        for line in normalized.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let hashes = trimmed.prefix { $0 == "#" }.count
            guard (1...6).contains(hashes), trimmed.dropFirst(hashes).first == " " else { continue }
            headingIndex += 1
            let text = trimmed.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
            links.append("<a class=\"toc-level-\(hashes)\" href=\"#heading-\(headingIndex)\">\(escapeHTML(text))</a>")
        }

        guard !links.isEmpty else { return "" }
        return """
        <aside class="toc-panel">
          \(links.joined(separator: "\n"))
        </aside>
        """
    }

    private func headingHTML(for line: String, index: inout Int) -> String? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        index += 1
        let text = line.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
        return "<h\(hashes) id=\"heading-\(index)\">\(inlineHTML(text))</h\(hashes)>"
    }

    private func isBlockStart(_ lines: [String], at index: Int) -> Bool {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("# ")
            || trimmed.hasPrefix("## ")
            || trimmed.hasPrefix("### ")
            || trimmed.hasPrefix("#### ")
            || trimmed.hasPrefix("##### ")
            || trimmed.hasPrefix("###### ")
            || trimmed.hasPrefix(">")
            || trimmed.hasPrefix("```")
            || trimmed.hasPrefix("~~~")
            || trimmed == "---"
            || trimmed == "***"
            || trimmed == "___"
            || isUnorderedListLine(trimmed)
            || isOrderedListLine(trimmed)
            || isTableStart(lines, at: index)
    }

    private func isUnorderedListLine(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private func isOrderedListLine(_ line: String) -> Bool {
        range(line, pattern: #"^\d+\.\s+"#) != nil
    }

    private func parseList(_ lines: [String], startingAt index: Int, ordered: Bool) -> (html: String, nextIndex: Int) {
        var items: [String] = []
        var cursor = index

        while cursor < lines.count {
            let trimmed = lines[cursor].trimmingCharacters(in: .whitespaces)
            guard ordered ? isOrderedListLine(trimmed) : isUnorderedListLine(trimmed) else { break }

            let text: String
            if ordered {
                text = replace(trimmed, pattern: #"^\d+\.\s+"#, template: "")
            } else {
                text = String(trimmed.dropFirst(2))
            }
            items.append("<li>\(inlineHTML(text))</li>")
            cursor += 1
        }

        let tag = ordered ? "ol" : "ul"
        return ("<\(tag)>\n\(items.joined(separator: "\n"))\n</\(tag)>", cursor)
    }

    private func isTableStart(_ lines: [String], at index: Int) -> Bool {
        guard index + 1 < lines.count else { return false }
        let header = lines[index].trimmingCharacters(in: .whitespaces)
        let separator = lines[index + 1].trimmingCharacters(in: .whitespaces)
        return header.contains("|") && range(separator, pattern: #"^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?$"#) != nil
    }

    private func parseTable(_ lines: [String], startingAt index: Int) -> (html: String, nextIndex: Int) {
        let headers = splitTableRow(lines[index])
        var cursor = index + 2
        var rows: [[String]] = []

        while cursor < lines.count {
            let line = lines[cursor].trimmingCharacters(in: .whitespaces)
            guard line.contains("|"), !line.isEmpty else { break }
            rows.append(splitTableRow(line))
            cursor += 1
        }

        let head = headers.map { "<th>\(inlineHTML($0))</th>" }.joined()
        let body = rows.map { row in
            let cells = headers.indices.map { column in
                let value = column < row.count ? row[column] : ""
                return "<td>\(inlineHTML(value))</td>"
            }.joined()
            return "<tr>\(cells)</tr>"
        }.joined(separator: "\n")

        return (
            """
            <table>
              <thead><tr>\(head)</tr></thead>
              <tbody>
            \(body)
              </tbody>
            </table>
            """,
            cursor
        )
    }

    private func splitTableRow(_ line: String) -> [String] {
        var row = line.trimmingCharacters(in: .whitespaces)
        if row.hasPrefix("|") { row.removeFirst() }
        if row.hasSuffix("|") { row.removeLast() }
        return row.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private func inlineHTML(_ text: String) -> String {
        var html = escapeHTML(text)
        html = replace(html, pattern: #"`([^`]+)`"#, template: "<code>$1</code>")
        html = replace(html, pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, template: #"<a href="$2">$1</a>"#)
        html = replace(html, pattern: #"\*\*([^*]+)\*\*"#, template: "<strong>$1</strong>")
        html = replace(html, pattern: #"__([^_]+)__"#, template: "<strong>$1</strong>")
        html = replace(html, pattern: #"\*([^*]+)\*"#, template: "<em>$1</em>")
        html = replace(html, pattern: #"_([^_]+)_"#, template: "<em>$1</em>")
        return html
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func range(_ text: String, pattern: String) -> Range<String.Index>? {
        text.range(of: pattern, options: .regularExpression)
    }

    private func replace(_ text: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}

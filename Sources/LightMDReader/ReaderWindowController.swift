import AppKit
import UniformTypeIdentifiers
import WebKit

final class ReaderWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, WKNavigationDelegate {
    private let renderer = MarkdownRenderer()
    private var documents: [MarkdownDocument] = []
    private var selectedIndex: Int?
    private var untitledDocumentCount = 0
    private var currentTheme: ReaderTheme = ReaderTheme(rawValue: UserDefaults.standard.integer(forKey: themeDefaultsKey)) ?? .blue

    private let sidebarWidth: CGFloat = 240
    private let readerOverlap: CGFloat = 22
    private let readerContainer = RoundedReaderView()
    private let tableView = NSTableView()
    private let webView = WKWebView()
    private let titleLabel = NSTextField(labelWithString: appDisplayName)
    private let detailLabel = NSTextField(labelWithString: "双击即读 Markdown")
    private let openButton = NSButton(title: "", target: nil, action: nil)
    private let newDocumentButton = NSButton(title: "新建", target: nil, action: nil)
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
        super.init(window: window)
        let contentView = ThemeAwareContentView()
        contentView.onAppearanceChange = { [weak self] in
            self?.applyThemeColors(reloadDocument: true)
        }
        window.contentView = contentView
        setupUI()
        installKeyboardShortcuts()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceChanged(_:)),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
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

    @objc func newDocument(_ sender: Any?) {
        untitledDocumentCount += 1
        let temporaryTitle = untitledDocumentCount == 1 ? "未命名" : "未命名 \(untitledDocumentCount)"
        documents.append(MarkdownDocument(temporaryTitle: temporaryTitle))
        tableView.reloadData()
        selectDocument(at: documents.count - 1)
        modeControl.selectedSegment = 1
        updateMode()
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
        webView.loadHTMLString(renderer.welcomeHTML(theme: effectiveTheme), baseURL: nil)
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = effectiveTheme.sidebarBaseColor(isDark: effectiveThemeIsDark).cgColor

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
        openButton.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "打开文件")
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
        readerContainer.fillColor = effectiveTheme.readerBackgroundColor(isDark: effectiveThemeIsDark)

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

        newDocumentButton.target = self
        newDocumentButton.action = #selector(newDocument(_:))
        newDocumentButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "新建")
        newDocumentButton.imagePosition = .imageLeading
        newDocumentButton.bezelStyle = .rounded
        newDocumentButton.controlSize = .small
        newDocumentButton.toolTip = "新建 Markdown 文档"

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

        themeControl.selectedSegment = effectiveTheme.rawValue
        themeControl.target = self
        themeControl.action = #selector(themeChanged(_:))
        themeControl.controlSize = .small
        themeControl.segmentStyle = .rounded
        for index in ReaderTheme.allCases.indices {
            themeControl.setWidth(34, forSegment: index)
        }

        let controls = NSStackView(views: [newDocumentButton, modeControl, saveButton, searchField, previousMatchButton, nextMatchButton, decreaseFontButton, increaseFontButton, exportButton, themeControl])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 6

        header.addArrangedSubview(titleStack)
        header.addArrangedSubview(controls)

        let contentSeparator = NSBox()
        contentSeparator.boxType = .separator
        contentSeparator.translatesAutoresizingMaskIntoConstraints = false

        webView.navigationDelegate = self
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
        applyThemeColors(reloadDocument: false)
    }

    private func installKeyboardShortcuts() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
                  let key = event.charactersIgnoringModifiers?.lowercased() else {
                return event
            }

            switch key {
            case "n":
                self.newDocument(nil)
                return nil
            case "s":
                self.saveCurrentDocument(nil)
                return nil
            default:
                return event
            }
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
        icon.fillColor = effectiveTheme.accentColor
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

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyFontScale()
        updateMode()
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
        webView.loadHTMLString(renderer.render(document.content, title: document.title, theme: effectiveTheme), baseURL: document.baseURL)
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
        let existingURL = documents[selectedIndex].url

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

            guard let existingURL else {
                self.promptToSaveNewDocument(content: content, selectedIndex: selectedIndex)
                return
            }

            self.saveDocument(content: content, to: existingURL, selectedIndex: selectedIndex)
        }
    }

    private func promptToSaveNewDocument(content: String, selectedIndex: Int) {
        let panel = NSSavePanel()
        panel.title = "保存 Markdown"
        panel.allowedContentTypes = [UTType(filenameExtension: "md"), UTType.plainText].compactMap { $0 }
        panel.nameFieldStringValue = documents[selectedIndex].suggestedFileName + ".md"
        panel.canCreateDirectories = true

        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.saveDocument(content: content, to: url, selectedIndex: selectedIndex)
        }
    }

    private func saveDocument(content: String, to url: URL, selectedIndex: Int) {
        guard documents.indices.contains(selectedIndex) else { return }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            documents[selectedIndex].url = url
            documents[selectedIndex].temporaryTitle = nil
            documents[selectedIndex].content = content
            tableView.reloadData()
            detailLabel.stringValue = "\(modeLabel()) · \(formattedSize(for: content)) · \(documents[selectedIndex].subtitle)"
            window?.title = documents[selectedIndex].title
            webView.loadHTMLString(renderer.render(content, title: documents[selectedIndex].title, theme: effectiveTheme), baseURL: documents[selectedIndex].baseURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.applyFontScale()
                self?.updateMode()
            }
        } catch {
            showError("无法保存文件", detail: "\(url.lastPathComponent)\n\(error.localizedDescription)")
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
        panel.nameFieldStringValue = document.suggestedFileName + "." + format.fileExtension
        panel.canCreateDirectories = true

        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let destinationURL = panel.url else { return }
            self?.export(document: document, to: destinationURL, as: format)
        }
    }

    private func export(document: MarkdownDocument, to destinationURL: URL, as format: ExportFormat) {
        currentMarkdown { [weak self] markdown in
            guard let self else { return }
            let html = self.renderer.render(markdown, title: document.title, theme: self.effectiveTheme)

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
                baseURL: document.baseURL ?? URL(fileURLWithPath: NSTemporaryDirectory()),
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
        if isEditing {
            window?.makeFirstResponder(webView)
        }
        webView.evaluateJavaScript("window.lightMDSetEditing && window.lightMDSetEditing(\(isEditing ? "true" : "false"));") { [weak self] _, _ in
            guard let self, isEditing else { return }
            self.window?.makeFirstResponder(self.webView)
        }
        detailLabel.stringValue = detailLabel.stringValue.replacingOccurrences(of: isEditing ? "只读" : "编辑", with: modeLabel())
        updateStatus()
    }

    private var systemPrefersDarkMode: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    private var effectiveTheme: ReaderTheme {
        systemPrefersDarkMode ? .night : currentTheme
    }

    private var effectiveThemeIsDark: Bool {
        effectiveTheme == .night
    }

    private func applyThemeColors(reloadDocument: Bool) {
        let theme = effectiveTheme
        let isDark = effectiveThemeIsDark
        window?.appearance = theme.windowAppearance
        window?.contentView?.layer?.backgroundColor = theme.sidebarBaseColor(isDark: isDark).cgColor
        readerContainer.fillColor = theme.readerBackgroundColor(isDark: isDark)
        themeControl.selectedSegment = theme.rawValue
        tableView.reloadData()

        if reloadDocument {
            reloadCurrentDocument()
        }
    }

    @objc private func themeChanged(_ sender: NSSegmentedControl) {
        guard let theme = ReaderTheme(rawValue: sender.selectedSegment) else { return }
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: themeDefaultsKey)
        applyThemeColors(reloadDocument: true)
    }

    @objc private func systemAppearanceChanged(_ notification: Notification) {
        applyThemeColors(reloadDocument: true)
    }

    private func reloadCurrentDocument() {
        guard let selectedIndex, documents.indices.contains(selectedIndex) else {
            webView.loadHTMLString(renderer.welcomeHTML(theme: effectiveTheme), baseURL: nil)
            return
        }

        let document = documents[selectedIndex]
        webView.loadHTMLString(renderer.render(document.content, title: document.title, theme: effectiveTheme), baseURL: document.baseURL)
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

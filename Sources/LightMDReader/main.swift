import AppKit
import UniformTypeIdentifiers
import WebKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var readerWindow: ReaderWindowController?
    private var filesPendingLaunch: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
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
            withTitle: "关于 LightMD Reader",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "退出 LightMD Reader",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(withTitle: "打开...", action: #selector(ReaderWindowController.openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "关闭当前文件", action: #selector(ReaderWindowController.closeCurrentDocument(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        NSApp.mainMenu = mainMenu
    }
}

struct MarkdownDocument: Equatable {
    let url: URL
    let content: String

    var title: String {
        url.lastPathComponent
    }

    var subtitle: String {
        url.deletingLastPathComponent().path
    }
}

final class ReaderWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let renderer = MarkdownRenderer()
    private var documents: [MarkdownDocument] = []
    private var selectedIndex: Int?

    private let splitView = NSSplitView()
    private let tableView = NSTableView()
    private let webView = WKWebView()
    private let titleLabel = NSTextField(labelWithString: "LightMD Reader")
    private let detailLabel = NSTextField(labelWithString: "双击即读 Markdown")
    private let openButton = NSButton(title: "打开", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1060, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LightMD Reader"
        window.minSize = NSSize(width: 720, height: 480)
        super.init(window: window)
        setupUI()
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

        if let firstNewIndex {
            selectDocument(at: firstNewIndex)
        } else if documents.isEmpty {
            showWelcome()
        }
    }

    func showWelcome() {
        titleLabel.stringValue = "LightMD Reader"
        detailLabel.stringValue = "打开一个 .md 文件，直接阅读渲染后的内容"
        webView.loadHTMLString(renderer.welcomeHTML(), baseURL: nil)
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        contentView.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: contentView.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let sidebar = NSView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.widthAnchor.constraint(greaterThanOrEqualToConstant: 190).isActive = true

        let sidebarHeader = NSStackView()
        sidebarHeader.orientation = .horizontal
        sidebarHeader.alignment = .centerY
        sidebarHeader.spacing = 8
        sidebarHeader.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 8, right: 10)
        sidebarHeader.translatesAutoresizingMaskIntoConstraints = false

        let appLabel = NSTextField(labelWithString: "文件")
        appLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        appLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        openButton.target = self
        openButton.action = #selector(openDocument(_:))
        openButton.bezelStyle = .rounded
        openButton.controlSize = .small
        sidebarHeader.addArrangedSubview(appLabel)
        sidebarHeader.addArrangedSubview(openButton)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        tableView.headerView = nil
        tableView.rowHeight = 48
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        scrollView.documentView = tableView

        sidebar.addSubview(sidebarHeader)
        sidebar.addSubview(scrollView)
        NSLayoutConstraint.activate([
            sidebarHeader.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            sidebarHeader.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            sidebarHeader.topAnchor.constraint(equalTo: sidebar.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: sidebarHeader.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor)
        ])

        let reader = NSStackView()
        reader.orientation = .vertical
        reader.spacing = 0
        reader.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView()
        header.orientation = .vertical
        header.spacing = 2
        header.edgeInsets = NSEdgeInsets(top: 12, left: 18, bottom: 10, right: 18)
        header.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(detailLabel)

        webView.setValue(false, forKey: "drawsBackground")
        reader.addArrangedSubview(header)
        reader.addArrangedSubview(webView)

        splitView.addArrangedSubview(sidebar)
        splitView.addArrangedSubview(reader)
        splitView.setPosition(240, ofDividerAt: 0)

        window?.center()
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

        let title = NSTextField(labelWithString: documents[row].title)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.lineBreakMode = .byTruncatingMiddle

        let path = NSTextField(labelWithString: documents[row].subtitle)
        path.font = .systemFont(ofSize: 11)
        path.textColor = .secondaryLabelColor
        path.lineBreakMode = .byTruncatingMiddle

        let stack = NSStackView(views: [title, path])
        stack.orientation = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
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
        detailLabel.stringValue = document.subtitle
        window?.title = document.title
        webView.loadHTMLString(renderer.render(document.content, title: document.title), baseURL: document.url.deletingLastPathComponent())
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
    func welcomeHTML() -> String {
        pageHTML(
            title: "LightMD Reader",
            body: """
            <main class="welcome">
              <h1>双击即读 Markdown</h1>
              <p>打开一个 <code>.md</code> 文件后，这里会直接显示排版后的阅读视图。</p>
              <p class="muted">默认只读，不会修改原文件。</p>
            </main>
            """
        )
    }

    func render(_ markdown: String, title: String) -> String {
        pageHTML(title: title, body: markdownToHTML(markdown))
    }

    private func pageHTML(title: String, body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escapeHTML(title))</title>
          <style>
            :root {
              color-scheme: light dark;
              --bg: #ffffff;
              --fg: #202124;
              --muted: #6b7280;
              --border: #d8dde6;
              --code-bg: #f5f7fb;
              --quote-bg: #f7f9fc;
              --link: #0a65cc;
            }
            @media (prefers-color-scheme: dark) {
              :root {
                --bg: #1f2023;
                --fg: #eceff4;
                --muted: #a6adbb;
                --border: #3a3f4b;
                --code-bg: #292d35;
                --quote-bg: #252a32;
                --link: #8ab4ff;
              }
            }
            body {
              margin: 0;
              background: var(--bg);
              color: var(--fg);
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
              font-size: 16px;
              line-height: 1.68;
            }
            main {
              max-width: 860px;
              margin: 0 auto;
              padding: 34px 42px 64px;
            }
            .welcome {
              padding-top: 20vh;
            }
            h1, h2, h3, h4, h5, h6 {
              line-height: 1.28;
              margin: 1.3em 0 0.55em;
            }
            h1:first-child, h2:first-child, h3:first-child {
              margin-top: 0;
            }
            h1 { font-size: 2rem; }
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
              padding: 0.7em 1em;
              border-left: 4px solid var(--border);
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
          </style>
        </head>
        <body>
          <main>
            \(body)
          </main>
        </body>
        </html>
        """
    }

    private func markdownToHTML(_ markdown: String) -> String {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var index = 0
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

            if let heading = headingHTML(for: trimmed) {
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

    private func headingHTML(for line: String) -> String? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        let text = line.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
        return "<h\(hashes)>\(inlineHTML(text))</h\(hashes)>"
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

import Foundation

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
              --bg: #1b1e25;
              --fg: #f3f6fb;
              --muted: #bac4d2;
              --border: #424b5b;
              --code-bg: #252b34;
              --quote-bg: #222a34;
              --link: #93c5ff;
              --accent: #93c5ff;
              --focus-ring: rgba(147, 197, 255, 0.32);
            }
            @media (prefers-color-scheme: dark) {
              html[data-theme="blue"] {
                --bg: #1b1e25;
                --fg: #f3f6fb;
                --muted: #bac4d2;
                --border: #424b5b;
                --code-bg: #252b34;
                --quote-bg: #222a34;
                --link: #93c5ff;
                --accent: #93c5ff;
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
              color: var(--fg);
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
            strong { color: var(--fg); }
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

import AppKit

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
        let newItem = fileMenu.addItem(withTitle: "新建", action: #selector(newDocument(_:)), keyEquivalent: "n")
        newItem.target = self
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
    @objc private func newDocument(_ sender: Any?) {
        readerWindow?.newDocument(sender)
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

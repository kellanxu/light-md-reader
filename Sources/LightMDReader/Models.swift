import AppKit
import UniformTypeIdentifiers

let appDisplayName = "LightMD"
let appBundleIdentifier = "com.kellan.lightmd"
let themeDefaultsKey = "LightMD.SelectedTheme"
let developerDisplayName = "Kellan / 许可"
let developerEmail = "kenbot818@gmail.com"

struct MarkdownDocument: Equatable {
    var url: URL?
    var temporaryTitle: String?
    var content: String

    init(url: URL, content: String) {
        self.url = url
        self.temporaryTitle = nil
        self.content = content
    }

    init(temporaryTitle: String, content: String = "") {
        self.url = nil
        self.temporaryTitle = temporaryTitle
        self.content = content
    }

    var isSaved: Bool {
        url != nil
    }

    var title: String {
        url?.lastPathComponent ?? temporaryTitle ?? "未命名"
    }

    var subtitle: String {
        url?.deletingLastPathComponent().path ?? "尚未保存"
    }

    var baseURL: URL? {
        url?.deletingLastPathComponent()
    }

    var suggestedFileName: String {
        url?.deletingPathExtension().lastPathComponent ?? temporaryTitle ?? "未命名"
    }

    var monogram: String {
        let baseName = url?.deletingPathExtension().lastPathComponent ?? temporaryTitle ?? "M"
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

    func readerBackgroundColor(isDark: Bool) -> NSColor {
        switch self {
        case .blue:
            return isDark
                ? NSColor(calibratedRed: 0.105, green: 0.118, blue: 0.145, alpha: 1)
                : NSColor(calibratedRed: 0.985, green: 0.99, blue: 0.998, alpha: 1)
        case .paper: return NSColor(calibratedRed: 0.985, green: 0.968, blue: 0.935, alpha: 1)
        case .night: return NSColor(calibratedRed: 0.105, green: 0.118, blue: 0.145, alpha: 1)
        }
    }

    func sidebarBaseColor(isDark: Bool) -> NSColor {
        switch self {
        case .blue:
            return isDark
                ? NSColor(calibratedRed: 0.145, green: 0.158, blue: 0.182, alpha: 1)
                : NSColor(calibratedWhite: 0.88, alpha: 1)
        case .paper: return NSColor(calibratedWhite: 0.86, alpha: 1)
        case .night: return NSColor(calibratedRed: 0.145, green: 0.158, blue: 0.182, alpha: 1)
        }
    }
}

extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

enum ExportFormat {
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

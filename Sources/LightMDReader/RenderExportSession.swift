import AppKit
import WebKit

final class RenderExportSession: NSObject, WKNavigationDelegate {
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

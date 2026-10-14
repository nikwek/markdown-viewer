import AppKit
import UniformTypeIdentifiers
import WebKit

/// Owns the rendered view of one document window: rendering, live reload,
/// zoom, printing and PDF export.
@MainActor
final class DocumentController: ObservableObject {
    private(set) var webView: WKWebView?
    private(set) var fileURL: URL?
    private var markdown = ""
    private var watcher: FileWatcher?
    private var pageLoaded = false

    var title: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
    }

    func attach(_ webView: WKWebView) {
        self.webView = webView
        loadPage()
    }

    func open(text: String, fileURL: URL?) {
        markdown = text
        if fileURL != self.fileURL {
            self.fileURL = fileURL
            watch()
            loadPage()
        } else {
            refresh()
        }
    }

    // MARK: Rendering

    /// Full page load. Used initially; later changes go through `refresh()`
    /// so the scroll position survives.
    private func loadPage() {
        guard let webView else { return }
        pageLoaded = false
        HTMLTemplate.load(markdown: markdown, fileURL: fileURL, into: webView)
    }

    func pageDidLoad() {
        pageLoaded = true
    }

    private func refresh() {
        guard let webView, pageLoaded else { return loadPage() }
        let body = HTMLRenderer.render(markdown)
        guard let data = try? JSONEncoder().encode(body), let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("updateContent(\(json))")
    }

    private func watch() {
        watcher = fileURL.map { url in
            FileWatcher(url: url) { [weak self] in
                guard let self, let data = try? Data(contentsOf: url) else { return }
                let text = decodeText(data)
                guard text != self.markdown else { return }
                self.markdown = text
                self.refresh()
            }
        }
    }

    // MARK: Zoom

    func zoomIn() { setZoom((webView?.pageZoom ?? 1) * 1.1) }
    func zoomOut() { setZoom((webView?.pageZoom ?? 1) / 1.1) }
    func resetZoom() { setZoom(1) }

    private func setZoom(_ zoom: CGFloat) {
        webView?.pageZoom = min(max(zoom, 0.5), 3)
    }

    // MARK: Printing & PDF

    func print() {
        guard let webView, let window = webView.window else { return }
        let operation = PDFExport.printOperation(for: webView, info: NSPrintInfo.shared.copy() as! NSPrintInfo)
        operation.jobTitle = title
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    func exportPDF() {
        guard let window = webView?.window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = title + ".pdf"
        if let directory = fileURL?.deletingLastPathComponent() {
            panel.directoryURL = directory
        }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            // Let the save sheet finish closing before attaching the print sheet.
            DispatchQueue.main.async { self?.writePDF(to: url) }
        }
    }

    private func writePDF(to url: URL) {
        guard let webView, let window = webView.window else { return }
        PDFExport.write(webView: webView, window: window, to: url)
    }
}

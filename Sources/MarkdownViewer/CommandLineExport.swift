import AppKit
import WebKit

/// Headless export: `MarkdownViewer --export input.md [output.pdf]`.
@MainActor
final class CommandLineExport: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    static func run(arguments args: [String]) -> Never {
        let flag = args.firstIndex(of: "--export")!
        guard args.count > flag + 1 else {
            FileHandle.standardError.write(Data("usage: MarkdownViewer --export input.md [output.pdf]\n".utf8))
            exit(64)
        }
        let input = URL(fileURLWithPath: args[flag + 1]).standardizedFileURL
        let output = args.count > flag + 2
            ? URL(fileURLWithPath: args[flag + 2]).standardizedFileURL
            : input.deletingPathExtension().appendingPathExtension("pdf")
        guard let data = try? Data(contentsOf: input) else {
            FileHandle.standardError.write(Data("Cannot read \(input.path)\n".utf8))
            exit(66)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let exporter = CommandLineExport(markdown: decodeText(data), input: input, output: output)
        app.delegate = exporter
        exporter.start()
        app.run()
        exit(0)
    }

    private let markdown: String
    private let input: URL
    private let output: URL
    private let window: NSWindow
    private let webView: WKWebView

    private init(markdown: String, input: URL, output: URL) {
        self.markdown = markdown
        self.input = input
        self.output = output
        // Same width as a typical document window so layout matches the GUI export.
        let frame = NSRect(x: -10_000, y: -10_000, width: 900, height: 1200)
        webView = WKWebView(frame: frame)
        window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = webView
        super.init()
        webView.navigationDelegate = self
    }

    private func start() {
        HTMLTemplate.load(markdown: markdown, fileURL: input, into: webView)
    }

    /// AppKit treats the command-line paths as files to open; ignore them.
    func application(_ sender: NSApplication, openFiles filenames: [String]) {}

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            PDFExport.write(webView: webView, window: window, to: output) { [output] success in
                if success {
                    print(output.path)
                    exit(0)
                }
                FileHandle.standardError.write(Data("Export failed\n".utf8))
                exit(1)
            }
        }
    }
}

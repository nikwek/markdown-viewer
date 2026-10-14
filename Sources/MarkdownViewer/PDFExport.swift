import AppKit
import WebKit

enum PDFExport {
    /// A paginated print operation for `webView` with standard page margins.
    @MainActor
    static func printOperation(for webView: WKWebView, info: NSPrintInfo) -> NSPrintOperation {
        let margin: CGFloat = 54  // 0.75in
        info.topMargin = margin
        info.bottomMargin = margin
        info.leftMargin = margin
        info.rightMargin = margin
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false

        let operation = webView.printOperation(with: info)
        // WKWebView's print view has a zero frame unless set; without this the
        // output comes out blank.
        operation.view?.frame = webView.bounds
        return operation
    }

    /// Writes `webView`'s content to a PDF at `url`. WebKit prints asynchronously,
    /// so this must run modally for a window rather than via `run()`.
    @MainActor
    static func write(webView: WKWebView, window: NSWindow, to url: URL, completion: ((Bool) -> Void)? = nil) {
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
        let operation = printOperation(for: webView, info: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        let delegate = CompletionDelegate(completion)
        operation.runModal(
            for: window,
            delegate: delegate,
            didRun: #selector(CompletionDelegate.printOperationDidRun(_:success:contextInfo:)),
            contextInfo: Unmanaged.passRetained(delegate).toOpaque()
        )
    }

    private final class CompletionDelegate: NSObject {
        let completion: ((Bool) -> Void)?

        init(_ completion: ((Bool) -> Void)?) {
            self.completion = completion
        }

        @objc func printOperationDidRun(_ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
            if let contextInfo {
                Unmanaged<CompletionDelegate>.fromOpaque(contextInfo).release()
            }
            completion?(success)
        }
    }
}

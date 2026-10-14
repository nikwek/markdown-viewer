import AppKit

let arguments = CommandLine.arguments

if arguments.contains("--export") {
    MainActor.assumeIsolated { CommandLineExport.run(arguments: arguments) }
} else if let flag = arguments.firstIndex(of: "--html") {
    // Prints the rendered HTML body: `MarkdownViewer --html input.md`
    let data = arguments.count > flag + 1
        ? FileManager.default.contents(atPath: arguments[flag + 1])
        : FileHandle.standardInput.readDataToEndOfFile()
    guard let data else { exit(66) }
    print(HTMLRenderer.render(decodeText(data)), terminator: "")
} else {
    MarkdownViewerApp.main()
}

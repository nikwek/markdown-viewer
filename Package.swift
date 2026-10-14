// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkdownViewer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "MarkdownViewer",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")]
        ),
    ]
)

// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PomodoroTimer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PomodoroTimer",
            path: "Sources/PomodoroTimer"
        )
    ]
)

// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VoiceBridge",
    platforms: [.iOS(.v16)],
    products: [.executable(name: "VoiceBridge", targets: ["VoiceBridge"])],
    targets: [
        .executableTarget(
            name: "VoiceBridge",
            path: "Sources"
        )
    ]
)

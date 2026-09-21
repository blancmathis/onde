// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Onde", platforms: [.macOS(.v14)],
    products: [.executable(name: "Onde", targets: ["OndeApp"]), .executable(name: "ondectl", targets: ["onde"]), .executable(name: "onde-updater", targets: ["OndeUpdateHelper"])],
    targets: [
        .target(name: "OndeDSP", publicHeadersPath: "include", cSettings: [.unsafeFlags(["-std=c11"])]),
        .target(name: "OndeCore", dependencies: ["OndeDSP"]),
        .executableTarget(name: "OndeApp", dependencies: ["OndeCore", "OndeDSP"]),
        .executableTarget(name: "onde", dependencies: ["OndeCore", "OndeDSP"]),
        .executableTarget(name: "OndeUpdateHelper", dependencies: ["OndeCore"]),
        .testTarget(name: "OndeCoreTests", dependencies: ["OndeCore", "OndeDSP"])
    ]
)

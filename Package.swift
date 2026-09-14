// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Onde", platforms: [.macOS(.v14)],
    products: [.executable(name: "Onde", targets: ["OndeApp"]), .executable(name: "ondectl", targets: ["onde"])],
    targets: [
        .target(name: "OndeDSP", publicHeadersPath: "include", cSettings: [.unsafeFlags(["-std=c11"])]),
        .target(name: "OndeCore", dependencies: ["OndeDSP"]),
        .executableTarget(name: "OndeApp", dependencies: ["OndeCore", "OndeDSP"]),
        .executableTarget(name: "onde", dependencies: ["OndeCore", "OndeDSP"]),
        .testTarget(name: "OndeCoreTests", dependencies: ["OndeCore", "OndeDSP"])
    ]
)

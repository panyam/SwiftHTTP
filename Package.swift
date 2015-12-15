import PackageDescription

let package = Package (
    name: "Swiftli",
    dependencies: [
        .Package(url: "../SwiftSocketServer", majorVersion: 1)
    ]
)


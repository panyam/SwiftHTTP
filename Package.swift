import PackageDescription

let package = Package (
    name: "Swiftli",
    dependencies: [
        .Package(url: "../SocketServer", majorVersion: 1)
    ]
)


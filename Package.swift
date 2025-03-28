// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SQLite",
  products: [
    .library(
      name: "SQLite",
      targets: ["SQLite"]
    )
  ],
  targets: [
    .target(
      name: "SQLite",
      dependencies: ["Csqlite3"]
    ),
    .testTarget(
      name: "SQLiteTests",
      dependencies: ["SQLite"]
    ),
    .systemLibrary(
      name: "Csqlite3",
      providers: [
        .apt(["libsqlite3-dev"]),
        .brew(["sqlite3"]),
      ]
    ),
  ]
)

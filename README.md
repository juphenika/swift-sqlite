# Swift SQLite

A lightweight, type-safe Swift wrapper around SQLite3 that provides a clean and Swift-friendly interface to SQLite databases.

## Requirements

- Swift 5.9 or later
- SQLite3 development libraries:
  - On macOS: `brew install sqlite3`
  - On Linux: `apt-get install libsqlite3-dev`

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/grdsdev/swift-sqlite.git", from: "1.0.0")
]
```

## Usage

### Basic Database Operations

```swift
import SQLite

// Initialize a database connection
let db = try SQLite(path: "database.sqlite")

// Create a table
try db.execute("""
    CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT,
        age INTEGER
    )
""")

// Insert data with parameters
try db.execute("INSERT INTO users (name, age) VALUES (?, ?)", 
    .text("John"), 
    .int(25)
)

// Query data
let rows = try db.execute("SELECT * FROM users WHERE age > ?", .int(18))

// Update data
try db.execute("UPDATE users SET age = ? WHERE name = ?", 
    .int(26), 
    .text("John")
)

// Delete data
try db.execute("DELETE FROM users WHERE age < ?", .int(18))
```

### Transactions

```swift
import SQLite

let db = try SQLite()

try db.withTransaction {
    try db.execute("INSERT INTO users (name, age) VALUES (?, ?)", 
        .text("John"), 
        .int(25)
    )   
    try db.execute("UPDATE users SET age = ? WHERE name = ?", 
        .int(18), 
        .text("Jane")
    )
}
```

### Database Migrations

```swift
import SQLite

let db = try SQLite(path: "database.sqlite")
let migrator = try Migrator()

// Define migrations
migrator.addMigration("create_users_table") { db in
    try db.execute("""
        CREATE TABLE users (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
}

// Apply pending migrations
try migrator.migrate(in: db)
```

## License

This project is licensed under the MIT License - see the LICENSE file for details. 
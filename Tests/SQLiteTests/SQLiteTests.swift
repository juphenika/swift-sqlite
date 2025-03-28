import Foundation
import Testing

@testable import SQLite

struct SQLiteTests {
  @Test func testInMemoryDatabase() async throws {
    let db = try SQLite()
    try db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")
    try db.execute("INSERT INTO test (id, name) VALUES (1, 'test')")

    let result = try db.execute("SELECT * FROM test")
    #expect(result.count == 1)
    #expect(result[0][0] == .int(1))
    #expect(result[0][1] == .text("test"))
  }

  @Test func testFileDatabase() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let dbPath = tempDir.appendingPathComponent("test.db").path
    defer { try? FileManager.default.removeItem(atPath: dbPath) }

    let db = try SQLite(path: dbPath)
    try db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")
    try db.execute("INSERT INTO test (id, name) VALUES (1, 'test')")

    let result = try db.execute("SELECT * FROM test")
    #expect(result.count == 1)
    #expect(result[0][0] == .int(1))
    #expect(result[0][1] == .text("test"))
  }

  @Test func testDataTypes() async throws {
    let db = try SQLite()
    try db.execute(
      """
          CREATE TABLE test (
              id INTEGER PRIMARY KEY,
              int_val INTEGER,
              real_val REAL,
              text_val TEXT,
              blob_val BLOB,
              null_val TEXT
          )
      """)

    let intVal: Int64 = 42
    let realVal = 3.14
    let textVal = "Hello, World!"
    let blobVal = "Hello, Blob!".data(using: .utf8)!

    try db.execute(
      """
          INSERT INTO test (int_val, real_val, text_val, blob_val, null_val)
          VALUES (?, ?, ?, ?, ?)
      """, .int(intVal), .real(realVal), .text(textVal), .blob(blobVal), .null)

    let result = try db.execute("SELECT * FROM test")
    #expect(result.count == 1)
    #expect(result[0][1] == .int(intVal))
    #expect(result[0][2] == .real(realVal))
    #expect(result[0][3] == .text(textVal))
    #expect(result[0][4] == .blob(blobVal))
    #expect(result[0][5] == .null)
  }

  @Test func testLastInsertRowid() async throws {
    let db = try SQLite()
    try db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")

    try db.execute("INSERT INTO test (name) VALUES ('test1')")
    #expect(db.lastInsertRowid == 1)

    try db.execute("INSERT INTO test (name) VALUES ('test2')")
    #expect(db.lastInsertRowid == 2)
  }

  @Test func testErrorHandling() async throws {
    let db = try SQLite()

    do {
      try db.execute("SELECT * FROM nonexistent_table")
      throw SQLite.Error(code: -1, description: "Expected error but got none")
    } catch let error as SQLite.Error {
      #expect(error.code != nil)
      #expect(!error.description.isEmpty)
    }
  }

  @Test func testConcurrentAccess() async throws {
    let db = try SQLite()
    try db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")

    // Test concurrent writes
    let iterations = 100
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<iterations {
        group.addTask {
          _ = try? db.execute("INSERT INTO test (name) VALUES (?)", .text("test\(i)"))
        }
      }
    }

    let result = try db.execute("SELECT COUNT(*) FROM test")
    #expect(result[0][0] == .int(Int64(iterations)))
  }
}

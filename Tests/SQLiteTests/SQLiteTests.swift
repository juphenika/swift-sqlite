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
    #expect(result[0]["id"] == .int(1))
    #expect(result[0]["name"] == .text("test"))
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
    #expect(result[0]["id"] == .int(1))
    #expect(result[0]["name"] == .text("test"))
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

  @Test func testUpdateOperations() async throws {
    let db = try SQLite()
    try db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")
    try db.execute("INSERT INTO test (id, name) VALUES (1, 'test1')")
    try db.execute("INSERT INTO test (id, name) VALUES (2, 'test2')")

    try db.execute("UPDATE test SET name = ? WHERE id = ?", .text("updated"), .int(1))

    let result = try db.execute("SELECT * FROM test WHERE id = ?", .int(1))
    #expect(result.count == 1)
    #expect(result[0]["name"] == .text("updated"))
  }

  @Test func testDeleteOperations() async throws {
    let db = try SQLite()
    try db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")
    try db.execute("INSERT INTO test (id, name) VALUES (1, 'test1')")
    try db.execute("INSERT INTO test (id, name) VALUES (2, 'test2')")

    try db.execute("DELETE FROM test WHERE id = ?", .int(1))

    let result = try db.execute("SELECT * FROM test")
    #expect(result.count == 1)
    #expect(result[0]["id"] == .int(2))
  }

  @Test func testComplexQueries() async throws {
    let db = try SQLite()
    try db.execute(
      """
        CREATE TABLE users (
          id INTEGER PRIMARY KEY,
          name TEXT
        )
      """)
    try db.execute(
      """
        CREATE TABLE orders (
          id INTEGER PRIMARY KEY,
          user_id INTEGER,
          amount REAL,
          FOREIGN KEY (user_id) REFERENCES users(id)
        )
      """)

    try db.execute("INSERT INTO users (id, name) VALUES (1, 'John'), (2, 'Jane')")
    try db.execute(
      "INSERT INTO orders (id, user_id, amount) VALUES (1, 1, 100.0), (2, 1, 200.0), (3, 2, 150.0)")

    let result = try db.execute(
      """
        SELECT u.name, COUNT(o.id) as order_count, SUM(o.amount) as total_amount
        FROM users u
        LEFT JOIN orders o ON u.id = o.user_id
        GROUP BY u.id
        HAVING total_amount >= 150
      """)

    #expect(result.count == 2)
    #expect(result[0]["name"] == .text("John"))
    #expect(result[0]["order_count"] == .int(2))
    #expect(result[0]["total_amount"] == .real(300.0))
    #expect(result[1]["name"] == .text("Jane"))
    #expect(result[1]["order_count"] == .int(1))
    #expect(result[1]["total_amount"] == .real(150.0))
  }

  @Test func testManualTransactions() async throws {
    let db = try SQLite()
    try db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")

    try db.execute("BEGIN TRANSACTION")
    try db.execute("INSERT INTO test (id, name) VALUES (1, 'test1')")
    try db.execute("INSERT INTO test (id, name) VALUES (2, 'test2')")
    try db.execute("COMMIT")

    let result = try db.execute("SELECT * FROM test")
    #expect(result.count == 2)

    try db.execute("BEGIN TRANSACTION")
    try db.execute("INSERT INTO test (id, name) VALUES (3, 'test3')")
    try db.execute("ROLLBACK")

    let resultAfterRollback = try db.execute("SELECT * FROM test")
    #expect(resultAfterRollback.count == 2)
  }

  @Test func testTransactionIsolation() async throws {
    let db = try SQLite()
    try db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")

    try db.withTransaction {
      try db.execute("INSERT INTO test (id, name) VALUES (1, 'test1')")
      try db.execute("INSERT INTO test (id, name) VALUES (2, 'test2')")
    }

    let result = try db.execute("SELECT * FROM test")
    #expect(result.count == 2)
  }

  @Test func testTransactionIsolationWithErrors() async throws {
    let db = try SQLite()
    try db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")

    do {
      try db.withTransaction {
        try db.execute("INSERT INTO test (id, name) VALUES (1, 'test1')")
        throw SQLite.Error(code: -1, description: "Test error")
      }
    } catch let error as SQLite.Error {
      #expect(error.code != nil)
      #expect(!error.description.isEmpty)
    }

    let result = try db.execute("SELECT * FROM test")
    #expect(result.count == 0)
  }

  @Test func testColumnNameCaseSensitivity() async throws {
    let db = try SQLite()
    try db.execute("CREATE TABLE test (ID INTEGER PRIMARY KEY, Name TEXT)")
    try db.execute("INSERT INTO test (ID, Name) VALUES (1, 'test')")

    let result = try db.execute("SELECT * FROM test")
    #expect(result.count == 1)
    #expect(result[0]["id"] == .int(1))
    #expect(result[0]["name"] == .text("test"))
  }

  @Test func testEmptyResultSet() async throws {
    let db = try SQLite()
    try db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")

    let result = try db.execute("SELECT * FROM test WHERE id = 999")
    #expect(result.isEmpty)
  }

  @Test func testInvalidParameterBinding() async throws {
    let db = try SQLite()
    try db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")

    do {
      try db.execute("INSERT INTO test (id, name) VALUES (?, ?)", .int(1))
      throw SQLite.Error(code: -1, description: "Expected error but got none")
    } catch let error as SQLite.Error {
      #expect(error.code != nil)
      #expect(!error.description.isEmpty)
    }
  }

  @Test func testPreparedStatementReuse() async throws {
    let db = try SQLite()
    try db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")

    let sql = "INSERT INTO test (id, name) VALUES (?, ?)"
    try db.execute(sql, .int(1), .text("test1"))
    try db.execute(sql, .int(2), .text("test2"))

    let result = try db.execute("SELECT * FROM test")
    #expect(result.count == 2)
    #expect(result[0]["name"] == .text("test1"))
    #expect(result[1]["name"] == .text("test2"))
  }
}

import Foundation

#if os(Linux)
  import Csqlite3
#else
  import SQLite3
#endif

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// A Swift wrapper around SQLite3 that provides a type-safe and Swift-friendly interface to SQLite databases.
///
/// This class handles all the low-level SQLite operations while providing a clean, Swift-native API.
/// It supports both in-memory and file-based databases, and handles all SQLite data types through the `DataType` enum.
///
/// Example usage:
/// ```swift
/// let db = try SQLite(path: "database.sqlite")
/// 
/// // Create a table
/// try db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")
/// 
/// // Insert data with parameters
/// try db.execute("INSERT INTO users (name, age) VALUES (?, ?)", .text("John"), .int(25))
/// 
/// // Query data
/// let rows = try db.execute("SELECT * FROM users WHERE age > ?", .int(18))
/// 
/// // Update data
/// try db.execute("UPDATE users SET age = ? WHERE name = ?", .int(26), .text("John"))
/// 
/// // Delete data
/// try db.execute("DELETE FROM users WHERE age < ?", .int(18))
/// ```
public final class SQLite: @unchecked Sendable {
  private let serializationQueue = DispatchQueue(label: "SQLite")

  /// The underlying SQLite database handle
  public private(set) var handle: OpaquePointer!

  /// Initializes a new SQLite database connection to a file at the specified path.
  ///
  /// - Parameter path: The path to the SQLite database file. If the file doesn't exist, it will be created.
  /// - Throws: `SQLite.Error` if the database connection cannot be established
  public init(path: String) throws {
    try self.validate(
      sqlite3_open_v2(
        path,
        &self.handle,
        SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
        nil
      )
    )
  }

  /// Initializes a new in-memory SQLite database.
  ///
  /// This creates a temporary database that exists only in memory and is deleted when the connection is closed.
  /// - Throws: `SQLite.Error` if the database connection cannot be established
  public convenience init() throws {
    try self.init(path: ":memory:")
  }

  deinit {
    sqlite3_close_v2(self.handle)
  }

  /// Executes a SQL statement with optional bindings and returns the results.
  ///
  /// This method can be used for all SQL operations including:
  /// - SELECT queries (returns array of rows)
  /// - INSERT, UPDATE, DELETE statements (returns empty array)
  /// - CREATE TABLE and other DDL statements (returns empty array)
  ///
  /// - Parameters:
  ///   - sql: The SQL statement to execute
  ///   - bindings: Optional parameters to bind to the SQL statement using ? placeholders
  /// - Returns: An array of rows, where each row is an array of `DataType` values. Empty array for statements that don't return results.
  /// - Throws: `SQLite.Error` if the statement cannot be executed or if there's an error binding parameters
  @discardableResult
  public func execute(_ sql: String, _ bindings: DataType...) throws -> [[DataType]] {
    try self.serializationQueue.sync {
      var stmt: OpaquePointer?
      try self.validate(sqlite3_prepare_v2(self.handle, sql, -1, &stmt, nil))
      defer { sqlite3_finalize(stmt) }
      for (idx, binding) in zip(Int32(1)..., bindings) {
        switch binding {
        case .null:
          try self.validate(sqlite3_bind_null(stmt, idx))
        case let .int(value):
          try self.validate(sqlite3_bind_int64(stmt, idx, value))
        case let .real(value):
          try self.validate(sqlite3_bind_double(stmt, idx, value))
        case let .text(value):
          try self.validate(sqlite3_bind_text(stmt, idx, value, -1, SQLITE_TRANSIENT))
        case let .blob(data):
          try data.withUnsafeBytes {
            _ = try self.validate(
              sqlite3_bind_blob(stmt, idx, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT))
          }
        }
      }
      let cols = sqlite3_column_count(stmt)
      var rows: [[DataType]] = []
      while try self.validate(sqlite3_step(stmt)) == SQLITE_ROW {
        rows.append(
          try (0..<cols).map { idx -> DataType in
            switch sqlite3_column_type(stmt, idx) {
            case SQLITE_BLOB:
              if let bytes = sqlite3_column_blob(stmt, idx) {
                let count = Int(sqlite3_column_bytes(stmt, idx))
                return .blob(Data(bytes: bytes, count: count))
              } else {
                return .blob(Data())
              }
            case SQLITE_FLOAT:
              return .real(sqlite3_column_double(stmt, idx))
            case SQLITE_INTEGER:
              return .int(sqlite3_column_int64(stmt, idx))
            case SQLITE_NULL:
              return .null
            case SQLITE_TEXT:
              return .text(String(cString: sqlite3_column_text(stmt, idx)))
            default:
              throw Error(description: "fatal")
            }
          }
        )
      }
      return rows
    }
  }

  /// Returns the row ID of the most recent successful INSERT operation.
  ///
  /// This is equivalent to SQLite's `last_insert_rowid()` function.
  public var lastInsertRowid: Int64 {
    self.serializationQueue.sync {
      sqlite3_last_insert_rowid(self.handle)
    }
  }

  /// Validates a SQLite return code and throws an error if it's not successful.
  ///
  /// - Parameter code: The SQLite return code to validate
  /// - Returns: The validated code if successful
  /// - Throws: `SQLite.Error` if the code indicates an error
  @discardableResult
  private func validate(_ code: Int32) throws -> Int32 {
    guard code == SQLITE_OK || code == SQLITE_ROW || code == SQLITE_DONE
    else { throw Error(code: code, db: self.handle) }
    return code
  }

  /// Represents all possible SQLite data types that can be stored or retrieved from the database.
  public enum DataType: Equatable {
    /// Binary data
    case blob(Data)
    /// Integer value
    case int(Int64)
    /// NULL value
    case null
    /// Floating-point value
    case real(Double)
    /// Text value
    case text(String)
  }

  /// Represents an error that occurred during SQLite operations.
  public struct Error: Swift.Error, Equatable {
    /// The SQLite error code, if available
    public var code: Int32?
    /// A human-readable description of the error
    public var description: String
  }
}

extension SQLite.Error {
  /// Creates a new SQLite error from a SQLite error code.
  ///
  /// - Parameters:
  ///   - code: The SQLite error code
  ///   - db: The database handle where the error occurred
  init(code: Int32, db: OpaquePointer?) {
    self.code = code
    self.description = String(cString: sqlite3_errstr(code))
  }
}

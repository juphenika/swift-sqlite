import Foundation

/// A system for managing SQLite database migrations.
///
/// This class provides a way to version and apply database schema changes in a controlled manner.
/// It maintains a migrations table to track which migrations have been applied and ensures migrations
/// are applied in the correct order.
///
/// Example usage:
/// ```swift
/// let migrator = try Migrator(db: sqlite)
///
/// // Define migrations
/// migrator.addMigration(1, "create_users_table") { db in
///     try db.execute("""
///         CREATE TABLE users (
///             id INTEGER PRIMARY KEY,
///             name TEXT NOT NULL,
///             email TEXT UNIQUE NOT NULL,
///             created_at DATETIME DEFAULT CURRENT_TIMESTAMP
///         )
///     """)
/// }
///
/// // Apply pending migrations
/// try migrator.migrate()
/// ```
public struct Migrator {
  private let migrationsTable: String
  private var migrations: [(name: String, migration: (SQLite) throws -> Void)] = []

  /// Creates a new Migrator instance.
  ///
  /// - Parameter db: The SQLite database instance to manage migrations for
  /// - Parameter migrationsTable: The name of the migrations table
  /// - Throws: `SQLite.Error` if the migrations table cannot be created
  public init(migrationsTable: String = "_migrations") {
    precondition(
      migrationsTable.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
      "migrationsTable must contain only alphanumeric characters and underscores"
    )

    self.migrationsTable = migrationsTable
  }

  /// Adds a new migration to be applied.
  ///
  /// - Parameters:
  ///   - name: A descriptive name for the migration
  ///   - migration: A closure that performs the actual migration
  public mutating func addMigration(
    _ name: String, _ migration: @escaping (SQLite) throws -> Void
  ) {
    self.migrations.append((name: name, migration: migration))
  }

  /// Applies all pending migrations in order.
  ///
  /// This method will:
  /// 1. Check which migrations have already been applied
  /// 2. Apply any pending migrations in version order
  /// 3. Record successful migrations in the migrations table
  ///
  /// - Throws: `SQLite.Error` if any migration fails
  public func migrate(in db: SQLite) throws {
    try self.createMigrationsTable(db: db)
    let appliedVersions = try self.getAppliedMigrations(db: db)

    try db.withTransaction {
      for migration in self.migrations {
        if !appliedVersions.contains(migration.name) {

          try migration.migration(db)
          try self.recordMigration(migration.name, db: db)
        }
      }
    }
  }

  /// Creates the migrations table if it doesn't exist.
  private func createMigrationsTable(db: SQLite) throws {
    try db.execute(
      """
      CREATE TABLE IF NOT EXISTS \(self.migrationsTable) (
          name TEXT PRIMARY KEY
      )
      """)
  }

  /// Records a successful migration in the migrations table.
  private func recordMigration(_ name: String, db: SQLite) throws {
    try db.execute(
      "INSERT INTO \(self.migrationsTable) (name) VALUES (?)",
      .text(name)
    )
  }

  /// Returns the set of migration names that have already been applied.
  private func getAppliedMigrations(db: SQLite) throws -> Set<String> {
    let rows = try db.execute("SELECT name FROM \(self.migrationsTable)")
    return Set(rows.compactMap { row in row["name"]?.stringValue })
  }
}

import Testing

@testable import SQLite

struct MigratorTests {
  @Test func testMigrator() async throws {
    let migrationsTable = "_migrations"
    let db = try SQLite()
    var migrator = Migrator(migrationsTable: migrationsTable)

    migrator.addMigration("create_users_table") { db in
      try db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    }

    migrator.addMigration("create_posts_table") { db in
      try db.execute("CREATE TABLE posts (id INTEGER PRIMARY KEY, title TEXT)")
    }

    try migrator.migrate(in: db)

    let migrations = try db.execute("SELECT * FROM \(migrationsTable)")
    #expect(migrations.count == 2)
    #expect(migrations[0]["name"]?.stringValue == "create_users_table")
    #expect(migrations[1]["name"]?.stringValue == "create_posts_table")

    let tables = try db.execute(
      "SELECT name FROM sqlite_master WHERE type='table'")
    #expect(tables.contains { $0["name"]?.stringValue == "users" })
    #expect(tables.contains { $0["name"]?.stringValue == "posts" })
  }

  @Test func testMigratorWithErrorInMigration() async throws {
    let migrationsTable = "_migrations"
    let db = try SQLite()
    var migrator = Migrator(migrationsTable: migrationsTable)

    migrator.addMigration("create_users_table") { db in
      try db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
      throw SQLite.Error(code: 1, description: "Test error")
    }

    do {
      try migrator.migrate(in: db)
    } catch let error as SQLite.Error {
      #expect(error.code == 1)
      #expect(error.description == "Test error")
    }

    let migrations = try db.execute("SELECT COUNT(*) FROM \(migrationsTable)")
    #expect(migrations[0]["COUNT(*)"]?.intValue == 0)

    // users table should not be created
    let tables = try db.execute(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='users'")
    #expect(tables.count == 0)
  }
}

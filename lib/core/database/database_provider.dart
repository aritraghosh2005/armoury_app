import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseProvider {
  Future<Database>? _opening;

  Future<Database> get database async {
    final pending = _opening ??= _open();
    try {
      return await pending;
    } catch (_) {
      if (identical(_opening, pending)) _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(
      p.join(root, 'armoury_local.db'),
      version: 5,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA synchronous = NORMAL');
        await db.execute('PRAGMA cache_size = -4000');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE components (
            id TEXT PRIMARY KEY, namespace TEXT NOT NULL,
            category TEXT NOT NULL, subcategory TEXT NOT NULL,
            name TEXT NOT NULL, qty INTEGER NOT NULL, desc TEXT NOT NULL,
            pic TEXT NOT NULL, image TEXT, location TEXT NOT NULL,
            specs TEXT NOT NULL, status TEXT NOT NULL, tags TEXT NOT NULL,
            created TEXT NOT NULL, updated TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE TABLE app_content (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
        );
        await _createSyncTables(db);
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createIndexes(db);
        if (oldVersion < 3) await _createSyncTables(db);
        if (oldVersion < 4) await _createSyncVersionTable(db);
        if (oldVersion >= 3 && oldVersion < 5) {
          await db.execute(
            'ALTER TABLE sync_operations ADD COLUMN actor_key TEXT',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_sync_operations_actor '
            'ON sync_operations(actor_key, queue_id)',
          );
        }
      },
    );
  }

  Future<void> _createSyncTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_operations (
        queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_id TEXT NOT NULL UNIQUE,
        component_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        actor_key TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_operations_component '
      'ON sync_operations(component_id, queue_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_operations_actor '
      'ON sync_operations(actor_key, queue_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_tombstones (
        component_id TEXT PRIMARY KEY,
        revision INTEGER NOT NULL
      )
    ''');
    await _createSyncVersionTable(db);
  }

  Future<void> _createSyncVersionTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_versions (
        component_id TEXT PRIMARY KEY,
        revision INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_components_namespace ON components(namespace)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_components_updated ON components(updated DESC, id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_components_category ON components(category)',
    );
  }
}

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
      version: 2,
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
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createIndexes(db);
      },
    );
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

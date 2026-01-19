import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/budget.dart';
import '../models/budget_item.dart';
import '../models/sub_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sugo.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // bump database version to add new columns
    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE budgets(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        start TEXT NOT NULL,
        end TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_items(
        id TEXT PRIMARY KEY,
        budget_id TEXT NOT NULL,
        name TEXT NOT NULL,
        frequency TEXT DEFAULT 'once',
        amount REAL,
        start_date TEXT,
        has_sub_items INTEGER DEFAULT 0,
        is_saving INTEGER DEFAULT 0,
        FOREIGN KEY (budget_id) REFERENCES budgets (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sub_items(
        id TEXT PRIMARY KEY,
        budget_item_id TEXT NOT NULL,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        is_completed INTEGER DEFAULT 0,
        frequency TEXT DEFAULT 'once',
        start_date TEXT,
        FOREIGN KEY (budget_item_id) REFERENCES budget_items (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // add new columns to budget_items
      try {
        await db.execute(
          "ALTER TABLE budget_items ADD COLUMN frequency TEXT DEFAULT 'once'",
        );
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE budget_items ADD COLUMN amount REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE budget_items ADD COLUMN start_date TEXT');
      } catch (_) {}
    }

    if (oldVersion < 3) {
      // Create sub_items table
      await db.execute('''
        CREATE TABLE sub_items(
          id TEXT PRIMARY KEY,
          budget_item_id TEXT NOT NULL,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          is_completed INTEGER DEFAULT 0,
          frequency TEXT DEFAULT 'once',
          FOREIGN KEY (budget_item_id) REFERENCES budget_items (id) ON DELETE CASCADE
        )
      ''');
    }
    
    if (oldVersion < 4) {
      // Add has_sub_items column to budget_items table if it doesn't exist
      try {
        await db.execute('ALTER TABLE budget_items ADD COLUMN has_sub_items INTEGER DEFAULT 0');
      } catch (_) {
        // Column may already exist, ignore error
      }
      // Add frequency column to existing sub_items table if it doesn't exist  
      try {
        await db.execute('ALTER TABLE sub_items ADD COLUMN frequency TEXT DEFAULT \'once\'');
      } catch (_) {
        // Column may already exist, ignore error
      }
    }
    
    if (oldVersion < 5) {
      // Add start_date column to existing sub_items table if it doesn't exist
      try {
        await db.execute('ALTER TABLE sub_items ADD COLUMN start_date TEXT');
      } catch (_) {
        // Column may already exist, ignore error
      }
    }

    if (oldVersion < 6) {
      // Add is_saving column to budget_items table for savings tracking
      try {
        await db.execute('ALTER TABLE budget_items ADD COLUMN is_saving INTEGER DEFAULT 0');
      } catch (_) {
        // Column may already exist, ignore error
      }
    }
  }

  // Budget operations
  Future<String> insertBudget(Budget budget) async {
    final db = await instance.database;
    await db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return budget.id;
  }

  Future<Budget?> getBudget(String id) async {
    final db = await instance.database;
    final maps = await db.query('budgets', where: 'id = ?', whereArgs: [id]);

    if (maps.isEmpty) return null;

    final budget = Budget.fromMap(maps.first);
    // Load budget items (which will include sub-items)
    final items = await getBudgetItems(id);
    budget.items = items;
    return budget;
  }

  Future<List<Budget>> getAllBudgets() async {
    final db = await instance.database;
    final budgetMaps = await db.query('budgets');
    final budgets = budgetMaps.map((map) => Budget.fromMap(map)).toList();

    // Load items for each budget (which will include sub-items)
    for (var budget in budgets) {
      budget.items = await getBudgetItems(budget.id);
    }

    return budgets;
  }

  Future<int> updateBudget(Budget budget) async {
    final db = await instance.database;
    return db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteBudget(String id) async {
    final db = await instance.database;
    // Items will be deleted automatically due to CASCADE
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // BudgetItem operations
  Future<String> insertBudgetItem(String budgetId, BudgetItem item) async {
    final db = await instance.database;
    final itemMap = item.toMap();
    itemMap['budget_id'] = budgetId;
    await db.insert(
      'budget_items',
      itemMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return item.id;
  }

  Future<List<BudgetItem>> getBudgetItems(String budgetId) async {
    final db = await instance.database;
    final maps = await db.query(
      'budget_items',
      where: 'budget_id = ?',
      whereArgs: [budgetId],
    );

    final items = maps.map((map) => BudgetItem.fromMap(map)).toList();

    // Load sub-items for each budget item
    for (var item in items) {
      item.subItems = await getSubItems(item.id);
    }

    return items;
  }

  Future<int> updateBudgetItem(BudgetItem item) async {
    final db = await instance.database;
    return db.update(
      'budget_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteBudgetItem(String id) async {
    final db = await instance.database;
    return await db.delete('budget_items', where: 'id = ?', whereArgs: [id]);
  }

  // SubItem operations
  Future<String> insertSubItem(String budgetItemId, SubItem subItem) async {
    final db = await instance.database;
    final subItemMap = subItem.toMap();
    subItemMap['budget_item_id'] = budgetItemId;
    await db.insert(
      'sub_items',
      subItemMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return subItem.id;
  }

  Future<List<SubItem>> getSubItems(String budgetItemId) async {
    final db = await instance.database;
    final maps = await db.query(
      'sub_items',
      where: 'budget_item_id = ?',
      whereArgs: [budgetItemId],
    );

    return maps.map((map) => SubItem.fromMap(map)).toList();
  }

  Future<int> updateSubItem(SubItem subItem) async {
    final db = await instance.database;
    return db.update(
      'sub_items',
      subItem.toMap(),
      where: 'id = ?',
      whereArgs: [subItem.id],
    );
  }

  Future<int> deleteSubItem(String id) async {
    final db = await instance.database;
    return await db.delete('sub_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}

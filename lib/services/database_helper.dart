import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/budget.dart';
import '../models/budget_item.dart';

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

    // bump database version to 2 to add frequency/start_date to budget_items
    return await openDatabase(
      path,
      version: 2,
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
        FOREIGN KEY (budget_id) REFERENCES budgets (id) ON DELETE CASCADE
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
    // Load budget items
    final items = await getBudgetItems(id);
    budget.items = items;
    return budget;
  }

  Future<List<Budget>> getAllBudgets() async {
    final db = await instance.database;
    final budgetMaps = await db.query('budgets');
    final budgets = budgetMaps.map((map) => Budget.fromMap(map)).toList();

    // Load items for each budget
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

    return maps.map((map) => BudgetItem.fromMap(map)).toList();
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

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}

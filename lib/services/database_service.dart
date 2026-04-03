import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/chat_message.dart';
import '../models/plant_analysis.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('agrismart.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Table users
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        phone TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Table chat_messages
    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        image_url TEXT
      )
    ''');

    // Table plant_analyses
    await db.execute('''
      CREATE TABLE plant_analyses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        diagnosis TEXT,
        confidence REAL,
        recommendations TEXT,
        analyzed_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
  }

  // User CRUD operations
  Future<int> createUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toJson());
  }

  Future<User?> getUser(int id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
  }

  // Chat messages CRUD
  Future<int> saveChatMessage(ChatMessage message) async {
    final db = await database;
    return await db.insert('chat_messages', message.toJson());
  }

  Future<List<ChatMessage>> getChatMessages() async {
    final db = await database;
    final maps = await db.query(
      'chat_messages',
      orderBy: 'timestamp DESC',
      limit: 100,
    );

    return maps.map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<void> clearChatMessages() async {
    final db = await database;
    await db.delete('chat_messages');
  }

  // Plant analyses CRUD
  Future<int> savePlantAnalysis(PlantAnalysis analysis) async {
    final db = await database;
    return await db.insert('plant_analyses', analysis.toJson());
  }

  Future<List<PlantAnalysis>> getPlantAnalyses(int userId) async {
    final db = await database;
    final maps = await db.query(
      'plant_analyses',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'analyzed_at DESC',
    );

    return maps.map((json) => PlantAnalysis.fromJson(json)).toList();
  }

  Future<PlantAnalysis?> getPlantAnalysis(int id) async {
    final db = await database;
    final maps = await db.query(
      'plant_analyses',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return PlantAnalysis.fromJson(maps.first);
    }
    return null;
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

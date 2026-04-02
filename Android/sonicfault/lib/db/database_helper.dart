import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  DatabaseHelper._();

  Database? _db;

  Future<void> init() async {
    _db ??= await _openDb();
  }

  Future<Database> get db async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final path = join(await getDatabasesPath(), 'sonic_fault.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            name TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'user',
            created_at TEXT NOT NULL
          )
        ''');
        // Pre-seed admin
        await db.insert('users', {
          'email': 'admin@sctce.com',
          'password': 'sctce',          // In production, hash this!
          'name': 'Admin',
          'role': 'admin',
          'created_at': DateTime.now().toIso8601String(),
        });
      },
    );
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<User?> login(String email, String password) async {
    final d = await db;
    final rows = await d.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email.trim().toLowerCase(), password],
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<bool> register(String email, String password, String name) async {
    try {
      final d = await db;
      await d.insert('users', {
        'email': email.trim().toLowerCase(),
        'password': password,
        'name': name,
        'role': 'user',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false; // duplicate email
    }
  }

  Future<bool> emailExists(String email) async {
    final d = await db;
    final rows = await d.query('users',
        where: 'email = ?', whereArgs: [email.trim().toLowerCase()]);
    return rows.isNotEmpty;
  }

  // ── Admin: list all users ─────────────────────────────────────────────────

  Future<List<User>> getAllUsers() async {
    final d = await db;
    final rows = await d.query('users', orderBy: 'created_at DESC');
    return rows.map(User.fromMap).toList();
  }

  Future<void> deleteUser(int id) async {
    final d = await db;
    await d.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
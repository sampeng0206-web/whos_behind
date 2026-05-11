import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class EvidenceRecord {
  final int? id;
  final String type; // 'phone' or 'image'
  final String? content; // phone number
  final String? imagePath;
  final String timestamp;

  EvidenceRecord({
    this.id,
    required this.type,
    this.content,
    this.imagePath,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'content': content,
      'imagePath': imagePath,
      'timestamp': timestamp,
    };
  }

  factory EvidenceRecord.fromMap(Map<String, dynamic> map) {
    return EvidenceRecord(
      id: map['id'],
      type: map['type'],
      content: map['content'],
      imagePath: map['imagePath'],
      timestamp: map['timestamp'],
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('evidences.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE evidences (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  content TEXT,
  imagePath TEXT,
  timestamp TEXT NOT NULL
)
''');
  }

  Future<int> insertEvidence(EvidenceRecord record) async {
    final db = await instance.database;
    return await db.insert('evidences', record.toMap());
  }

  Future<List<EvidenceRecord>> fetchEvidences() async {
    final db = await instance.database;
    final maps = await db.query(
      'evidences',
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => EvidenceRecord.fromMap(map)).toList();
  }

  Future<int> deleteEvidence(int id) async {
    final db = await instance.database;
    return await db.delete(
      'evidences',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';

/// Secure local message storage with AES-256 encryption.
/// Message content is encrypted at rest using a key derived from the user's X25519 private key.
class MessageStore {
  static Database? _db;
  static const String _tableName = 'messages';

  /// Initialize the database
  static Future<void> init() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'securechat_messages.db');

    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            conversationId TEXT NOT NULL,
            fromUserId TEXT NOT NULL,
            toUserId TEXT NOT NULL,
            encryptedContent TEXT NOT NULL,
            iv TEXT NOT NULL,
            mac TEXT NOT NULL,
            type TEXT NOT NULL,
            sentAt INTEGER NOT NULL,
            expiresAt INTEGER NOT NULL,
            readAt INTEGER,
            isMe INTEGER NOT NULL,
            delivered INTEGER DEFAULT 0,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_conversation ON $_tableName(conversationId, sentAt)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_tableName ADD COLUMN mac TEXT DEFAULT ""');
        }
      },
    );
  }

  /// Derive an encryption key from the user's private key for local storage
  static Future<SecretKey> _deriveStorageKey() async {
    final keyPair = await KeyStore.loadKeyPair();
    if (keyPair == null) throw Exception('No key pair found');

    // Extract private key bytes and hash them to get a 256-bit key
    final privateKeyData = await keyPair.extract() as SimpleKeyPairData;
    final hash = await Sha256().hash(privateKeyData.bytes);
    return SecretKey(hash.bytes);
  }

  /// Encrypt message content for local storage
  static Future<Map<String, String>> _encryptContent(String content) async {
    final key = await _deriveStorageKey();
    return CryptoService.encrypt(content, key);
  }

  /// Decrypt message content from local storage
  static Future<String> _decryptContent(
    String ciphertext,
    String nonce,
    String mac,
  ) async {
    final key = await _deriveStorageKey();
    return CryptoService.decrypt({
      'ciphertext': ciphertext,
      'nonce': nonce,
      'mac': mac,
    }, key);
  }

  /// Save a message to local storage
  static Future<void> saveMessage({
    required Message message,
    required String conversationId,
    required bool isMe,
  }) async {
    await init();

    // Encrypt the message text
    final encrypted = await _encryptContent(message.text);

    await _db!.insert(
      _tableName,
      {
        'id': message.id,
        'conversationId': conversationId,
        'fromUserId': message.fromUserId,
        'toUserId': conversationId, // The peer's ID
        'encryptedContent': encrypted['ciphertext'],
        'iv': encrypted['nonce'],
        'mac': encrypted['mac'],
        'type': message.type == MessageType.text ? 'text' : 'media',
        'sentAt': message.sentAt.millisecondsSinceEpoch,
        'expiresAt': message.expiresAt.millisecondsSinceEpoch,
        'readAt': message.readAt?.millisecondsSinceEpoch,
        'isMe': isMe ? 1 : 0,
        'delivered': message.delivered ? 1 : 0,
        'synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get messages for a conversation
  static Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 100,
    int offset = 0,
  }) async {
    await init();

    final rows = await _db!.query(
      _tableName,
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'sentAt DESC',
      limit: limit,
      offset: offset,
    );

    // Decrypt messages
    final messages = <Map<String, dynamic>>[];
    for (final row in rows) {
      try {
        final decrypted = await _decryptContent(
          row['encryptedContent'] as String,
          row['iv'] as String,
          row['mac'] as String,
        );

        messages.add({
          ...row,
          'text': decrypted,
          'isMe': row['isMe'] == 1,
          'delivered': row['delivered'] == 1,
          'read': row['readAt'] != null,
        });
      } catch (e) {
        // Skip messages that can't be decrypted
        print('❌ Failed to decrypt message ${row['id']}: $e');
      }
    }

    return messages;
  }

  /// Mark a message as read
  static Future<void> markAsRead(String messageId) async {
    await init();

    await _db!.update(
      _tableName,
      {'readAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Mark a message as delivered
  static Future<void> markAsDelivered(String messageId) async {
    await init();

    await _db!.update(
      _tableName,
      {'delivered': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Get unread count for a conversation
  static Future<int> getUnreadCount(String conversationId) async {
    await init();

    final result = await _db!.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE conversationId = ? AND readAt IS NULL AND isMe = 0',
      [conversationId],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  /// Delete expired messages
  static Future<void> deleteExpiredMessages() async {
    await init();

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db!.delete(
      _tableName,
      where: 'expiresAt < ?',
      whereArgs: [now],
    );
  }

  /// Clear all messages (for logout)
  static Future<void> clearAll() async {
    await init();
    await _db!.delete(_tableName);
  }

  /// Close database connection
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

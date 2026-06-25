import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_store.dart';

class MessageStore {
  static Database? _db;
  static bool _initAttempted = false;
  static const String _tableName = 'messages_v11';

  static Future<void> init() async {
    if (_db != null || _initAttempted) return;
    _initAttempted = true;
    if (kIsWeb) return;
    try {
      final dbPath = await getDatabasesPath();
      _db = await openDatabase(
        join(dbPath, 'securechat_v11.db'),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_tableName (
              id TEXT PRIMARY KEY,
              conversationId TEXT NOT NULL,
              fromUserId TEXT NOT NULL,
              encryptedContent TEXT NOT NULL,
              iv TEXT NOT NULL,
              mac TEXT NOT NULL,
              type TEXT NOT NULL,
              sentAt INTEGER NOT NULL,
              expiresAt INTEGER NOT NULL,
              readAt INTEGER,
              isMe INTEGER NOT NULL,
              delivered INTEGER DEFAULT 0,
              mediaUrl TEXT
            )
          ''');
          await db.execute('CREATE INDEX idx_vault_v11 ON $_tableName(conversationId, sentAt)');
        },
      );
      await deleteExpiredMessages();
    } catch (e) {
      debugPrint('❌ Vault Error: $e');
    }
  }

  static Future<SecretKey> _deriveVaultKey() async {
    final userId = await KeyStore.getUserId();
    if (userId == null) throw Exception('Cannot derive vault key: no userId');
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return await hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(userId)),
      nonce: utf8.encode('v11_production_salt'),
    );
  }

  static Future<void> saveMessage({required Message message, required String conversationId, required bool isMe}) async {
    await init();
    try {
      final vaultKey = await _deriveVaultKey();
      final encrypted = await CryptoService.encrypt(message.text, vaultKey);

      String msgType = 'text';
      if (message.mediaUrl != null) {
        if (message.text.contains('[image]')) msgType = 'image';
        else if (message.text.contains('[voice]')) msgType = 'voice';
        else msgType = 'media';
      }

      await _db?.insert(_tableName, {
        'id': message.id,
        'conversationId': conversationId,
        'fromUserId': message.fromUserId,
        'encryptedContent': encrypted['ciphertext'],
        'iv': encrypted['nonce'],
        'mac': encrypted['mac'],
        'type': msgType,
        'sentAt': message.sentAt.millisecondsSinceEpoch,
        'expiresAt': message.expiresAt.millisecondsSinceEpoch,
        'readAt': message.readAt?.millisecondsSinceEpoch,
        'isMe': isMe ? 1 : 0,
        'delivered': message.delivered ? 1 : 0,
        'mediaUrl': message.mediaUrl,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('❌ Vault Save Error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    await init();
    final rows = await _db?.query(_tableName,
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'sentAt DESC',
      limit: 100
    ) ?? [];

    final vaultKey = await _deriveVaultKey();
    final results = <Map<String, dynamic>>[];

    for (var row in rows) {
      try {
        final text = await CryptoService.decrypt({
          'ciphertext': row['encryptedContent'],
          'nonce': row['iv'],
          'mac': row['mac'],
        }, vaultKey);
        results.add({
          ...row,
          'text': text,
          'isMe': row['isMe'] == 1,
          'delivered': row['delivered'] == 1,
          'readAt': row['readAt'] != null ? DateTime.fromMillisecondsSinceEpoch(row['readAt'] as int) : null,
        });
      } catch (e) {
        debugPrint('❌ Decrypt Error: $e');
      }
    }
    return results;
  }

  static Future<void> markAsRead(String conversationId) async {
    await init();
    await _db?.update(_tableName,
      {'readAt': DateTime.now().millisecondsSinceEpoch},
      where: 'conversationId = ? AND isMe = 0',
      whereArgs: [conversationId]
    );
  }

  static Future<void> markMessageAsRead(String messageId) async {
    await init();
    await _db?.update(_tableName,
      {'readAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [messageId]
    );
  }

  static Future<void> markAsDelivered(String messageId) async {
    await init();
    await _db?.update(_tableName, {'delivered': 1}, where: 'id = ?', whereArgs: [messageId]);
  }

  static Future<Map<String, Map<String, dynamic>>> getLastMessages(List<String> userIds) async {
    final results = <String, Map<String, dynamic>>{};
    for (var id in userIds) {
      final msgs = await getMessages(id);
      if (msgs.isNotEmpty) results[id] = msgs.first;
    }
    return results;
  }

  static Future<int> getUnreadCount(String conversationId) async {
    await init();
    final res = await _db?.rawQuery('SELECT COUNT(*) as count FROM $_tableName WHERE conversationId = ? AND readAt IS NULL AND isMe = 0', [conversationId]);
    return (res?.first['count'] as int?) ?? 0;
  }

  static Future<Map<String, int>> getUnreadCounts(List<String> userIds) async {
    await init();
    final results = <String, int>{};
    for (var id in userIds) {
      results[id] = await getUnreadCount(id);
    }
    return results;
  }

  /// Reset for testing
  static Future<void> reset() async {
    await init();
    await _db?.delete(_tableName);
  }

  static Future<void> deleteExpiredMessages() async {
    await init();
    final now = DateTime.now().millisecondsSinceEpoch;
    final twentyFourHoursAgo = now - Duration(hours: 24).inMilliseconds;
    await _db?.delete(_tableName,
      where: 'expiresAt < ? AND sentAt < ?',
      whereArgs: [now, twentyFourHoursAgo],
    );
  }

  /// PERFECTION FIX: V1 MUST WIPE LOCAL HISTORY ON LOGOUT
  static Future<void> clearAll() async {
    await init();
    await _db?.delete(_tableName);
    debugPrint('🗑️ Vault Purged: Local history wiped.');
  }
}

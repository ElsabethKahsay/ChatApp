import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securechat/core/constants.dart';
import 'package:securechat/services/api_service.dart';

http.Client _mockClient(http.Response Function(http.Request) handler) {
  return MockClient((request) async {
    return handler(request);
  });
}

void main() {
  setUp(() {
    Constants.serverUrl = 'http://test.example.com';
  });

  tearDown(() {
    ApiService.resetHttpClient();
  });

  group('register', () {
    test('succeeds on 201', () async {
      ApiService.resetHttpClient(_mockClient((request) {
        expect(request.url.toString(), 'http://test.example.com/api/register');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body);
        expect(body['userId'], 'user1');
        expect(body['username'], 'testuser');
        return http.Response('{"success": true}', 201);
      }));

      await expectLater(
        ApiService.register(
          userId: 'user1',
          username: 'testuser',
          publicKey: 'base64key==',
          password: 'password123',
        ),
        completes,
      );
    });

    test('throws on 409 conflict', () async {
      ApiService.resetHttpClient(_mockClient((_) {
        return http.Response('{"error": "Username already taken"}', 409);
      }));

      await expectLater(
        ApiService.register(
          userId: 'user1',
          username: 'testuser',
          publicKey: 'base64key==',
          password: 'password123',
        ),
        throwsA(predicate((e) => e.toString().contains('already taken'))),
      );
    });

    test('throws on 400 validation error', () async {
      ApiService.resetHttpClient(_mockClient((_) {
        return http.Response('{"error": "Invalid input"}', 400);
      }));

      await expectLater(
        ApiService.register(
          userId: 'user1',
          username: 'ab',
          publicKey: 'key',
          password: '123',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('login', () {
    test('returns token on 200', () async {
      ApiService.resetHttpClient(_mockClient((request) {
        expect(request.url.toString(), 'http://test.example.com/api/login');
        expect(request.method, 'POST');
        return http.Response(
          '{"token": "jwt-token", "userId": "user1", "username": "testuser"}',
          200,
        );
      }));

      final result = await ApiService.login('testuser', 'password123');
      expect(result['token'], 'jwt-token');
      expect(result['userId'], 'user1');
    });

    test('throws on 401', () async {
      ApiService.resetHttpClient(_mockClient((_) {
        return http.Response('{"error": "Invalid credentials"}', 401);
      }));

      await expectLater(
        ApiService.login('wrong', 'wrong'),
        throwsA(predicate((e) => e.toString().contains('Invalid'))),
      );
    });
  });

  group('getPublicKey', () {
    test('returns public key on 200', () async {
      ApiService.resetHttpClient(_mockClient((request) {
        expect(
          request.url.toString(),
          startsWith('http://test.example.com/api/public-key/user1'),
        );
        expect(request.headers['authorization'], 'Bearer test-token');
        return http.Response(
          '{"publicKey": "base64key==", "username": "testuser"}',
          200,
        );
      }));

      final key = await ApiService.getPublicKey('user1', 'test-token');
      expect(key, 'base64key==');
    });

    test('throws on 404', () async {
      ApiService.resetHttpClient(_mockClient((_) {
        return http.Response('{"error": "User not found"}', 404);
      }));

      await expectLater(
        ApiService.getPublicKey('nonexistent', 'test-token'),
        throwsA(predicate((e) => e.toString().contains('Peer Key Unavailable'))),
      );
    });
  });

  group('getUsers', () {
    test('returns list of users on 200', () async {
      ApiService.resetHttpClient(_mockClient((request) {
        expect(request.url.toString(), 'http://test.example.com/api/users');
        return http.Response(
          '{"users": [{"userId": "u1", "username": "alice"}]}',
          200,
        );
      }));

      final users = await ApiService.getUsers('test-token');
      expect(users.length, 1);
      expect(users[0].userId, 'u1');
      expect(users[0].username, 'alice');
    });

    test('returns empty list on 401', () async {
      ApiService.resetHttpClient(_mockClient((_) {
        return http.Response('{"error": "Unauthorized"}', 401);
      }));

      final users = await ApiService.getUsers('bad-token');
      expect(users, isEmpty);
    });
  });

  group('getOnlineUsers', () {
    test('returns online users on 200', () async {
      ApiService.resetHttpClient(_mockClient((request) {
        expect(
          request.url.toString(),
          'http://test.example.com/api/online-users',
        );
        return http.Response(
          '{"onlineUsers": [{"userId": "u1", "username": "alice"}]}',
          200,
        );
      }));

      final users = await ApiService.getOnlineUsers('test-token');
      expect(users.length, 1);
      expect(users[0].userId, 'u1');
    });
  });

  group('createGroup', () {
    test('succeeds on 201', () async {
      ApiService.resetHttpClient(_mockClient((request) {
        expect(request.url.toString(), 'http://test.example.com/api/groups');
        expect(request.method, 'POST');
        return http.Response('{"_id": "g1"}', 201);
      }));

      await expectLater(
        ApiService.createGroup(
          token: 'test-token',
          name: 'Test Group',
          members: ['u1', 'u2'],
          encryptedKeys: {
            'u1': {'ciphertext': 'ct', 'nonce': 'n', 'mac': 'm'},
            'u2': {'ciphertext': 'ct2', 'nonce': 'n2', 'mac': 'm2'},
          },
          creatorPublicKey: 'test-public-key',
        ),
        completes,
      );
    });
  });

  group('getGroups', () {
    test('returns groups on 200', () async {
      ApiService.resetHttpClient(_mockClient((_) {
        return http.Response('[{"_id": "g1", "name": "Group 1"}]', 200);
      }));

      final groups = await ApiService.getGroups('test-token');
      expect(groups.length, 1);
      expect(groups[0]['name'], 'Group 1');
    });
  });
}

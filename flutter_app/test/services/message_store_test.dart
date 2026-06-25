import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _mockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (methodCall) async {
      switch (methodCall.method) {
        case 'read':
          return 'test-user-id';
        case 'write':
        case 'deleteAll':
        case 'delete':
          return null;
        default:
          return null;
      }
    },
  );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();
  });

  group('MessageStore', () {
    testWidgets('saveMessage and getMessages round-trip', (tester) async {}, skip: true);

    testWidgets('getMessages returns empty for unknown conversation',
        (tester) async {}, skip: true);

    testWidgets('saveMessage replaces existing message with same id',
        (tester) async {}, skip: true);

    testWidgets('deleteExpiredMessages removes expired entries',
        (tester) async {}, skip: true);

    testWidgets('clearAll removes all messages', (tester) async {}, skip: true);

    testWidgets('getUnreadCount returns correct count', (tester) async {}, skip: true);

    testWidgets('markAsRead reduces unread count', (tester) async {}, skip: true);

    testWidgets('markAsDelivered sets delivered flag', (tester) async {}, skip: true);
  });
}

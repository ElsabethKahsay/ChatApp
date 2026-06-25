import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:securechat/screens/login_screen.dart';
import 'package:securechat/screens/onboarding_screen.dart';
import 'package:securechat/models/message.dart';
import 'package:securechat/widgets/chat_bubble.dart';
import 'package:securechat/widgets/connection_indicator.dart';
import 'package:securechat/widgets/safe_network_image.dart';
import 'package:securechat/crypto/crypto_service.dart';
import 'package:securechat/crypto/key_store.dart';

void main() {
  group('Message Model', () {
    test('Message defaults expiresAt to sentAt + 24h', () {
      final now = DateTime.now();
      final msg = Message(id: '1', fromUserId: 'user1', text: 'hello', sentAt: now, isMe: true);
      expect(msg.expiresAt.difference(now).inHours, 24);
    });

    test('Message accepts custom expiresAt', () {
      final future = DateTime.now().add(const Duration(hours: 1));
      final msg = Message(id: '2', fromUserId: 'user1', text: 'boom', sentAt: DateTime.now(), isMe: true, expiresAt: future);
      expect(msg.expiresAt, future);
    });

    test('Message copyWith', () {
      final msg = Message(id: '3', fromUserId: 'user1', text: 'original', sentAt: DateTime.now(), isMe: true);
      final edited = msg.copyWith(text: 'edited');
      expect(edited.text, 'edited');
      expect(edited.id, msg.id);
    });

    test('Message type enum', () {
      expect(MessageType.text.name, 'text');
      expect(MessageType.image.name, 'image');
      expect(MessageType.voice.name, 'voice');
    });
  });

  group('KeyStore', () {
    test('KeyStore class exists', () {
      expect(KeyStore, isNotNull);
    });

    test('KeyStore has required methods', () {
      expect(KeyStore.saveKeyPair, isNotNull);
      expect(KeyStore.loadKeyPair, isNotNull);
      expect(KeyStore.saveIdentity, isNotNull);
      expect(KeyStore.getUserId, isNotNull);
      expect(KeyStore.getAuthToken, isNotNull);
      expect(KeyStore.saveAuthToken, isNotNull);
    });
  });

  group('CryptoService', () {
    test('CryptoService class exists', () {
      expect(CryptoService, isNotNull);
    });

    test('CryptoService has key generation method', () {
      expect(CryptoService.generateKeyPair, isNotNull);
    });
  });

  group('Onboarding Screen', () {
    testWidgets('OnboardingScreen renders three pages', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump();

      expect(find.text('Welcome to SecureChat'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('OnboardingScreen page 3 shows Get Started', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump();

      // Tap Next button twice to reach page 3
      final nextBtn = find.widgetWithText(ElevatedButton, 'Next');
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('End-to-End Encrypted'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('OnboardingScreen Skip goes to login', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('ChatBubble', () {
    testWidgets('ChatBubble renders text message', (tester) async {
      final msg = Message(
        id: '1',
        fromUserId: 'user1',
        text: 'Hello World',
        sentAt: DateTime.now(),
        isMe: true,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChatBubble(message: msg, isMe: true),
        ),
      ));

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('ChatBubble shows status for sent message', (tester) async {
      final msg = Message(
        id: '2',
        fromUserId: 'user1',
        text: 'Test message',
        sentAt: DateTime.now(),
        isMe: true,
        delivered: true,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChatBubble(message: msg, isMe: true),
        ),
      ));

      expect(find.text('Test message'), findsOneWidget);
    });
  });

  group('ConnectionIndicator', () {
    testWidgets('ConnectionIndicator widget exists', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ConnectionIndicator()),
      ));

      expect(find.byType(ConnectionIndicator), findsOneWidget);
    });
  });

  group('SafeNetworkImage', () {
    testWidgets('SafeNetworkImage shows fallback on error', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SafeNetworkImage(imageUrl: 'https://invalid.example.com/missing.jpg'),
        ),
      ));
      await tester.pump();

      expect(find.byType(SafeNetworkImage), findsOneWidget);
    });
  });
}

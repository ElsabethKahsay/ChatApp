import 'package:flutter_test/flutter_test.dart';
import 'package:securechat/services/socket_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SocketService', () {
    test('isConnected returns false before connect', () {
      expect(SocketService.isConnected, false);
    });

    test('messageStream is a broadcast stream', () {
      final stream = SocketService.messageStream;
      expect(stream.isBroadcast, true);
    });

    test('deliveryStream is a broadcast stream', () {
      final stream = SocketService.deliveryStream;
      expect(stream.isBroadcast, true);
    });

    test('connectionStream is a broadcast stream', () {
      final stream = SocketService.connectionStream;
      expect(stream.isBroadcast, true);
    });

    test('messageStream can be listened to without error', () {
      final sub = SocketService.messageStream.listen((_) {});
      sub.cancel();
    });

    test('deliveryStream can be listened to without error', () {
      final sub = SocketService.deliveryStream.listen((_) {});
      sub.cancel();
    });

    test('connectionStream can be listened to without error', () {
      final sub = SocketService.connectionStream.listen((_) {});
      sub.cancel();
    });

    test('disconnect clears state without throwing', () {
      expect(() => SocketService.disconnect(), returnsNormally);
    });

    test('sendMessage does not throw when disconnected', () {
      expect(
        () => SocketService.sendMessage(
          toUserId: 'user-2',
          encryptedPayload: {'ciphertext': 'abc'},
          messageId: 'test-msg',
        ),
        returnsNormally,
      );
    });
  });
}

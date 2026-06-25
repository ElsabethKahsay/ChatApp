# SecureChat V1 — Socket.IO Critical Fixes

## Issues Found & Fixed

### 1. Server: Disconnect didn't clear Redis online status
- **File**: `server/src/socket.js:149-155`
- **Fix**: Added `redisClient.hdel(ONLINE_HASH, socket.userId)` in the `disconnect` handler
- **Impact**: Prevents stale online entries from persisting after disconnect

### 2. Server: `send_group_message` lacked error handling
- **File**: `server/src/socket.js:110-117`
- **Fix**: Wrapped `Group.findById` in try/catch, returns error ack on failure
- **Impact**: Prevents unhandled promise rejections from crashing the socket handler when MongoDB is down or groupId is invalid

### 3. Client: `sendGroupMessage` silently dropped when offline
- **File**: `flutter_app/lib/services/socket_service.dart:180-184`
- **Fix**: Now queues to `_outgoingQueue` with `{'event': 'send_group_message', 'data': ...}` when disconnected
- **Impact**: Group messages sent offline are no longer lost

### 4. Client: `_flushQueue` hardcoded `'send_message'` event
- **File**: `flutter_app/lib/services/socket_service.dart:194-199`
- **Fix**: Now reads `item['event']` from the queued item instead of hardcoding `'send_message'`
- **Impact**: Previously, any queued group messages would be sent with the wrong event type

## Already Present (pre-existing fixes from prior work)
- `isBlocked` check on both `send_message` and `send_group_message` (server)
- `// SECURITY FIX: Clean up Redis` comment on disconnect handler
- `processPayload` refactored out in `_handleIncoming` (client)

## Verification
- All 9 existing Flutter unit tests pass (`flutter test test/services/socket_service_test.dart`)

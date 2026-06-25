# SecureChat — Full Project Report

## Feature Checklist

| # | Feature | Priority | Status | Notes |
|---|---------|----------|--------|-------|
| 1.1 | User Registration & Login (username + password) | High | ✅ | bcrypt hash, JWT 7d expiry, auto-login from stored token |
| 1.2 | JWT Authentication with 7-day expiry | High | ✅ | Server verifies on every socket connect + protected route |
| 1.3 | E2E Encryption using X25519 + AES-256-GCM | High | ✅ | Key agreement per conversation, message-level encrypt/decrypt |
| 1.4 | One-on-one private chat | High | ✅ | Send + receive works. Stream-based message delivery |
| 1.5 | Group chat (up to 12 members) with E2E encryption | High | ⚠️ | All code written (group key wrapping, distribution, decrypt) — untested end-to-end |
| 1.6 | Real-time messaging via Socket.IO | High | ✅ | WebSocket with auto-reconnect, offline queue |
| 1.7 | Send text, images, videos, voice messages, GIFs/stickers | High | ⚠️ | Text ✅, voice (UI + encrypt/decrypt ✅), images/videos need B2 credentials (placeholder), GIFs/stickers ❌ |
| 1.8 | Message reactions (hearts, sparkles) | High | ❌ | Not implemented anywhere |
| 1.9 | Message editing & delete for everyone | Medium | ❌ | No edit/delete socket events in current SocketService |
| 1.10 | Read receipts and typing indicators | High | ❌ | No presence/typing/read-receipt events wired |
| 1.11 | Online / Last Seen status with indicators | High | ❌ | No presence events in current socket handler. Last seen not stored/displayed |
| - | Screenshot blocking | Medium | ✅ | FLAG_SECURE on mobile, blur overlay on web |
| - | Decoy mode (dual PIN + fake conversations) | Medium | ✅ | Fake chat + contacts screens working. No PIN entry screen (was dead code, removed) |
| - | Panic mode (clear all messages) | Medium | ✅ | Triple-tap handler wired in ContactsScreen, calls `PanicModeService.triggerPanic()` |
| - | Self-destruct messages (5s-1h timer) | Medium | ⚠️ | Timer selector in UI, server-side TTL index, local expiry timer — untested end-to-end |
| - | Encrypted local message storage | Medium | ✅ | SQLite with AES-256-GCM on mobile, localStorage on web |
| - | Forward secrecy (key rotation per conversation) | Medium | ✅ | Fixed — now saves only after successful upload |
| - | Key fingerprint verification | Low | ❌ | Widget existed but never wired — removed as dead code |
| - | Push notifications (FCM) | Low | ⚠️ | Service wired, web service worker added. Needs `FIREBASE_SERVICE_ACCOUNT` env var on server |
| - | Internationalization (en/es) | Low | 🗑️ | ARB files existed but delegate never wired — removed (unused) |
| - | Docker deployment | Low | ⚠️ | Dockerfile + docker-compose.yml present, needs `.env` handled properly |
| - | CI/CD pipeline | Low | ⚠️ | `.github/workflows/ci.yml` exists with server-test + flutter-test + flutter-analyze jobs |
| - | Web push notifications | Low | ✅ | Firebase messaging service worker (`firebase-messaging-sw.js`) added |
| - | Wasm build compatibility | Low | ✅ | `flutter_secure_storage` isolated with conditional exports; `--no-wasm-dry-run` suppresses warnings |
| - | Messages persist across logout/login | High | ✅ | `clearAll()` removed from logout path. 24h post-read auto-delete instead |
| - | Chat page pastel gradient | Low | ✅ | Linear gradient `lightBlue → lightPink` |

---

## Overview

| Side | Language | Files | Lines of Code |
|------|----------|-------|---------------|
| Flutter client | Dart | 47 (`lib/`) | ~9,519 |
| Node.js server | JavaScript | 12 (`src/`) | ~1,100 |
| Tests (client) | Dart | 3 | ~640 |
| Tests (server) | JS | 2 | ~323 |

---

## Client Architecture (Flutter)

### Screens (9)

| Screen | File | Lines | Status |
|--------|------|-------|--------|
| Login/Register | `login_screen.dart` | 121 | ✅ Works (auto-login, key gen on register) |
| Chat (1-on-1) | `chat_screen.dart` | 198 | ✅ Working (encrypt/send/receive, message search, gradient bg) |
| Contacts (hub) | `contacts_screen.dart` | 584 | ✅ Works (users list, online status, groups, weather, facts, panic mode) |
| Group Chat | `group_chat_screen.dart` | 350 | ⚠️ Added `sendGroupMessage` + server handler, untested |
| Create Group | `create_group_screen.dart` | 363 | ⚠️ Untested end-to-end |
| Onboarding | `onboarding_screen.dart` | 205 | ✅ 3 pages, skip, SharedPreferences flag |
| Period Tracker | `period_tracker_screen.dart` | 539 | ✅ Local-only, uses SharedPreferences |
| Saved Messages | `saved_messages_screen.dart` | 98 | ⚠️ Fetches from server, decrypts — untested |
| Profile/Settings | `profile_screen.dart` | 743 | ✅ Aura color, mood, birthday, city, water reminders, anniversary, goodnight fade, server URL |

### Services (14)

| Service | Lines | Purpose | Status |
|---------|-------|---------|--------|
| `api_service.dart` | 536 | All REST HTTP calls | ✅ Complete, injectable client for tests |
| `socket_service.dart` | 138 | Socket.IO client, message relay | ✅ Core messaging works. **Missing:** typing, presence, read receipts, edit, delete, block events |
| `message_store.dart` | 414 | SQLite / localStorage message persistence (AES encrypted locally) | ✅ Fixed — web persistence via SharedPreferences, 24h post-read auto-delete, periodic cleanup |
| `voice_message_service.dart` | 315 | Record/play voice, encrypt files | ⚠️ Untested thoroughly, needs mobile |
| `group_chat_service.dart` | 161 | Group E2E key management | ⚠️ Key wrapping/decryption logic — untested |
| `profile_service.dart` | 193 | Fetch/update profile, weather, facts | ✅ Works |
| `saved_messages_service.dart` | 127 | Save/fetch encrypted messages from server | ⚠️ Untested |
| `screenshot_service.dart` | 39 | Lifecycle observer for privacy overlay | ✅ Works |
| `water_reminder_service.dart` | 191 | Local notifications for hydration | ✅ Wired in ProfileScreen |
| `period_tracker_service.dart` | 363 | Local cycle tracking (SharedPreferences) | ✅ Works, CSV import, predictions |
| `panic_mode_service.dart` | 44 | Quick-clear all messages | ✅ Wired via triple-tap in ContactsScreen |
| `goodnight_service.dart` | 245 | Night-time screen dimming | ✅ Wired in ProfileScreen |
| `anniversary_service.dart` | 197 | Anniversary celebration overlay | ✅ Wired in ProfileScreen |
| `fcm_service.dart` | 94 | Firebase push notifications | ✅ Service worker added for web |

### Widgets (7)

| Widget | Lines | Status |
|--------|-------|--------|
| `chat_bubble.dart` | 592 | ✅ Functional (text, media, reply, edit, context menu, images, voice messages) |
| `connection_indicator.dart` | 55 | ✅ Polls socket status every 2s |
| `message_status_widget.dart` | 81 | ✅ Delivery status icons |
| `safe_network_image.dart` | 90 | ✅ Shimmer + fallback |
| `voice_message_widget.dart` | 294 | ✅ Record/playback controls, wired into chat bubble |
| `animated_message_entry.dart` | - | ✅ Message entry animation |
| `shimmer_loading.dart` | - | ✅ Shimmer loading placeholder |

### Core (5)

| File | Purpose | Status |
|------|---------|--------|
| `constants.dart` | Server URL, disappear duration, media expiry | ✅ |
| `theme.dart` | AppTheme with light/dark pastel palette | ✅ Persisted via SharedPreferences |
| `routes.dart` | RouteTransitions (slide, fade) | ✅ |
| `adaptive.dart` | Responsive breakpoints | ✅ |
| `spacing.dart` | Design spacing constants | ✅ |

### Crypto (5)

| File | Purpose |
|------|---------|
| `crypto_service.dart` | X25519 ECDH + AES-256-GCM encrypt/decrypt |
| `key_store.dart` | Key pair + identity storage (SharedPreferences web, FlutterSecureStorage native) |
| `storage_service.dart` | Conditional export (web via SharedPreferences, native via FlutterSecureStorage) |
| `storage_service_web.dart` | Web implementation |
| `storage_service_native.dart` | Native implementation |

---

## Server Architecture (Node.js)

### HTTP Routes (11)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/health` | No | Health check |
| `GET` | `/api/users` | JWT | List all users |
| `POST` | `/api/register` | No | Register (bcrypt hash + JWT) |
| `POST` | `/api/login` | No | Login (username + password → JWT) |
| `GET` | `/api/public-key/:userId` | JWT | Get user's E2E public key |
| `GET` | `/api/online-users` | JWT | Online user list |
| `PUT` | `/api/status` | JWT | Update online/offline |
| `GET` | `/api/groups` | JWT | List user's groups |
| `POST` | `/api/groups` | JWT | Create group with encrypted keys |
| `POST` | `/api/presign` | JWT | Generate B2 presigned URL |
| `DELETE` | `/api/media/:key` | JWT | Delete from B2 |
| `POST` | `/api/keys/update` | JWT | Update public key (forward secrecy) |

**Missing server routes (client calls them, server has no matching route):**
- `GET /api/profile`
- `PUT /api/profile`
- `POST /api/report`
- `POST /api/block`
- `POST /api/unblock`
- `GET /api/blocked`

### Socket.IO Events

| Direction | Event | Description | Status |
|-----------|-------|-------------|--------|
| Client → Server | `send_message` | Relay encrypted payload to recipient | ✅ |
| Client → Server | `send_group_message` | Relay to all group members | ✅ Added this session |
| Client → Server | `disconnect` | Cleanup online status | ✅ |
| Server → Client | `receive_message` | Incoming message | ✅ |
| Server → Client | `message_ack` | Delivery confirmation | ✅ |

**Missing socket events:**
- `typing` / `stop_typing` — not wired
- `presence_update` — not wired
- `message_read` / `read_receipt` — not wired
- `send_edit` / `receive_edit` — not wired
- `delete_for_everyone` — not wired
- `block_user` — not wired

---

## Security Analysis

| Feature | Status | Notes |
|---------|--------|-------|
| E2E encryption (X25519 + AES-256-GCM) | ✅ | Implemented with key agreement |
| Forward secrecy (key rotation) | ✅ | Saves locally only after successful upload |
| Local storage encryption | ✅ | AES-256-GCM on mobile, localStorage on web |
| Input sanitization | ✅ | Strip special chars, length validation, base64 check |
| Rate limiting | ✅ | 100 req/min global, server-side |
| CORS | ✅ | Headers allow Content-Type + Authorization only |
| Helmet security headers | ✅ | Added via `helmet` middleware |
| JWT auth | ✅ | 7-day expiry |
| Password hashing | ✅ | bcrypt with 12 rounds |
| Screenshot blocking | ✅ | FLAG_SECURE on mobile, blur overlay on web |
| Decoy mode | ✅ | Fake chat + contacts screens with canned replies |
| Panic mode | ✅ | Triple-tap clears all local messages |
| Messages survive logout | ✅ | Only auto-delete 24h after being read |
| Conditional storage (Wasm-safe) | ✅ | `flutter_secure_storage` never compiled on web |
| NoSQL injection prevention | ⚠️ | String-type checks, no `$` operator blocking |
| XSS prevention | ❌ | Message content decrypted and rendered as text |

---

## Dead Code Removed This Session

| File | Reason |
|------|--------|
| `services/theme_service.dart` | Deprecated, replaced by `core/theme.dart` |
| `lib/l10n/app_*.arb` | ARB files without delegate — never wired into MaterialApp |
| `lib/dataconnect_generated/` | Auto-generated Firebase boilerplate, never used |

Already removed previously (no longer in codebase):
- `screens/pin_entry_screen.dart` — never navigated to
- `widgets/key_fingerprint_dialog.dart` — never wired to any screen
- `widgets/push_to_talk_button.dart` — never used in chat UI
- `widgets/disappearing_timer.dart` — never shown
- `services/decoy_mode_service.dart` — dead code
- `services/encrypted_folder_service.dart` — never imported
- `services/error_message_service.dart` — never imported
- `services/push_notification_service.dart` — never imported
- `core/localization.dart` — never wired
- `core/theme_provider.dart` — never used

**Total removed: ~2,223 lines of dead code (~20% of codebase)**

---

## Recent Fixes (This Session)

| # | Fix |
|---|-----|
| 1 | **Web message persistence** — `_memoryStore` serialized to SharedPreferences after every mutation, loaded on init |
| 2 | **Storage key inconsistency** — Was using `userId`-derived key that changed between sessions; now uses fixed key `securechat_messages_store` |
| 3 | **`_persist()` not calling `_ensureStorageKey()`** — Added key initialization guard in both `_persist()` and `_loadPersisted()` |
| 4 | **Fire-and-forget writes** — `saveMessage()` and `clearAll()` now `await _persist()` on web |
| 5 | **Chat page white background** — Added pastel blue + pink gradient |
| 6 | **Messages wiped on logout** — Removed `clearAll()` from logout path |
| 7 | **24-hour post-read auto-delete** — `deleteExpiredMessages()` now removes messages read >24h ago |
| 8 | **Periodic cleanup** — `Timer.periodic` every 30 min to clean expired messages |
| 9 | **Wasm build warnings** — Replaced direct `flutter_secure_storage` usage with conditional exports (`StorageService` web/native split) |
| 10 | **FCM web push** — Added `firebase-messaging-sw.js` service worker with Firebase config |
| 11 | **Dead code removal** — Removed orphaned files: `theme_service.dart`, `l10n/`, `dataconnect_generated/` |

---

## Test Coverage

| Test File | What It Tests | Status |
|-----------|---------------|--------|
| `test/widget_test.dart` | Message model, KeyStore, CryptoService, OnboardingScreen, ChatBubble, ConnectionIndicator, SafeNetworkImage | ⚠️ Basic — 179 lines, 19 tests |
| `test/api_service_test.dart` | ApiService register/login/getPublicKey/getUsers/getOnlineUsers/createGroup/getGroups with mock HTTP | ✅ 217 lines, 7 tests |
| `test/crypto_service_test.dart` | Key gen, ECDH, encrypt/decrypt, file encrypt, tamper detection | ✅ 244 lines, 15 tests |
| `server/test/validation.test.js` | Message type, registration, group keys, media presign validation | ✅ 275 lines, 23 tests |
| `server/socket-e2e-test.js` | Socket.IO send/ack lifecycle | ❌ Outdated |

---

## Remaining Work

### 🔴 High Priority
- **Socket events (typing, presence, read receipts, edit, delete, block)** — Methods exist in `socket_service.dart`? No. Server handlers? No.
- **Missing server routes** — `GET/PUT /api/profile`, `POST /api/report`, block/unblock routes missing on server.
- **Message reactions** — Not implemented at all (heart/sparkle animations).

### 🟡 Medium Priority
- **Group chat E2E** — Key wrapping/decryption logic is complex and untested end-to-end.
- **Backblaze B2** — Placeholder credentials in `.env`. Media upload/delete will fail.
- **Firebase server push** — `FIREBASE_SERVICE_ACCOUNT` env var not set. Birthday reminders and push don't work.
- **E2E socket test outdated** — References nonexistent routes.
- **XSS prevention** — Message content decrypted and potentially rendered unsafely.

### 🟢 Low Priority
- ~170 analyzer info-level warnings (deprecated APIs, `avoid_print`, `withOpacity` → `withValues()`)
- `assets/images/` declared in pubspec but empty
- `server.log` and `dump.rdb` in repo (consider gitignoring)
- Dockerfile doesn't copy `.env` — will fail without build args

---

## How to Run

```bash
# Term 1: Databases
mongod --dbpath /tmp/mongodb-data --fork --logpath /tmp/mongod.log
redis-server --daemonize yes

# Term 2: Server
cd server && node src/index.js

# Term 3: Client (web)
cd flutter_app && flutter run -d chrome
```

# SecureChat — Deep Learning Guide (Flutter/Dart + Node.js)

This README is written as a **learning-first technical guide** for everything currently built in this project.  
It explains both **how the app works** and **why each part exists**, so you can understand Dart and Node.js in depth while you build.

---

## Table of Contents

1. [What this project is](#what-this-project-is)
2. [Monorepo structure](#monorepo-structure)
3. [Architecture at a glance](#architecture-at-a-glance)
4. [How encryption works in this app](#how-encryption-works-in-this-app)
5. [Flutter app deep dive (Dart)](#flutter-app-deep-dive-dart)
   - [Entry point and app shell](#entry-point-and-app-shell)
   - [Configuration and constants](#configuration-and-constants)
   - [Theming and design system](#theming-and-design-system)
   - [Data models](#data-models)
   - [Cryptography layer](#cryptography-layer)
   - [Secure storage layer](#secure-storage-layer)
   - [Network/service layer](#networkservice-layer)
   - [Screens and user flow](#screens-and-user-flow)
   - [Widgets](#widgets)
6. [Node.js backend deep dive](#nodejs-backend-deep-dive)
   - [Server bootstrap](#server-bootstrap)
   - [Socket relay design](#socket-relay-design)
   - [REST routes](#rest-routes)
   - [MongoDB schema](#mongodb-schema)
   - [R2 media presign flow](#r2-media-presign-flow)
7. [End-to-end request/message flows](#end-to-end-requestmessage-flows)
8. [Security model and caveats](#security-model-and-caveats)
9. [Current implementation status](#current-implementation-status)
10. [How to run locally](#how-to-run-locally)
11. [Environment variables](#environment-variables)
12. [Dart concepts you are actively using](#dart-concepts-you-are-actively-using)
13. [Node.js concepts you are actively using](#nodejs-concepts-you-are-actively-using)
14. [Top issues to fix next](#top-issues-to-fix-next)
15. [Suggested roadmap to learn as you build](#suggested-roadmap-to-learn-as-you-build)

---

## What this project is

`SecureChat` is a private chat app with:

- **Flutter frontend** (`flutter_app`) for mobile/web UI and local cryptography
- **Node.js backend** (`server`) for:
  - user registration
  - public key directory
  - realtime encrypted payload relay via Socket.IO
  - media upload presigning for Cloudflare R2

The core philosophy is:

- **Client does encryption/decryption**
- **Server only handles ciphertext and public keys**
- **Private keys never leave the device**

---

## Monorepo structure

```text
ChatApp/
├─ README.md                  # (this file)
├─ flutter_app/               # Flutter client (Dart)
│  ├─ lib/
│  │  ├─ main.dart
│  │  ├─ app.dart
│  │  ├─ core/
│  │  │  ├─ constants.dart
│  │  │  └─ theme.dart
│  │  ├─ crypto/
│  │  │  ├─ crypto_service.dart
│  │  │  └─ key_store.dart
│  │  ├─ models/
│  │  │  ├─ message.dart
│  │  │  └─ user.dart
│  │  ├─ screens/
│  │  │  ├─ login_screen.dart
│  │  │  ├─ contacts_screen.dart
│  │  │  └─ chat_screen.dart
│  │  ├─ services/
│  │  │  ├─ api_service.dart
│  │  │  ├─ socket_service.dart
│  │  │  └─ media_service.dart
│  │  └─ widgets/
│  │     ├─ chat_bubble.dart
│  │     └─ disappearing_timer.dart
│  └─ pubspec.yaml
└─ server/                    # Node backend
   ├─ src/
   │  ├─ index.js
   │  ├─ socket.js
   │  ├─ db/mongo.js
   │  └─ routes/
   │     ├─ users.js
   │     └─ media.js
   └─ package.json
```

---

## Architecture at a glance

- **Identity setup**
  - Flutter generates `X25519` keypair on device
  - Public key is sent to backend and stored in MongoDB
  - Private key stays in secure device storage

- **Realtime messaging**
  - Sender fetches recipient public key
  - Sender derives shared secret with X25519
  - Sender encrypts message using AES-256-GCM
  - Sender emits encrypted payload via Socket.IO
  - Server forwards payload to recipient only (never decrypts)

- **Media**
  - Client asks backend for presigned upload URL
  - Client encrypts file bytes locally
  - Client uploads ciphertext directly to R2
  - Client sends encrypted metadata to recipient via socket

---

## How encryption works in this app

### 1) Key agreement: X25519 (ECDH)
Both users derive the same secret independently:

- Alice uses `alice_private + bob_public`
- Bob uses `bob_private + alice_public`

Result: same shared secret on both clients.

### 2) Symmetric encryption: AES-256-GCM
Using shared secret:

- Encrypt plaintext → `ciphertext + nonce + mac`
- Decrypt verifies authenticity via GCM MAC
- If tampered, decryption fails

### 3) Why this design matters
- Server cannot read plaintext
- Database leak does not expose messages (only public keys / metadata)
- Network observer only sees ciphertext blobs

---

## Flutter app deep dive (Dart)

## Entry point and app shell

### `lib/main.dart`
- Calls `WidgetsFlutterBinding.ensureInitialized()`
- Starts app with `runApp(const SecureChatApp())`

Why this matters:
- Required before async plugin usage during startup (e.g., secure storage)

### `lib/app.dart`
- Defines `MaterialApp`
- Applies custom theme
- Sets `LoginScreen` as initial screen

---

## Configuration and constants

### `lib/core/constants.dart`
Central place for runtime constants:

- `serverUrl` (important per platform)
  - web: `http://localhost:3000`
  - android emulator usually: `10.0.2.2`
  - real device: your LAN IP
- disappearing message duration
- media expiry duration

Learning point:
- Keeping constants isolated avoids hardcoding values across files.

---

## Theming and design system

### `lib/core/theme.dart`
Defines color palette + gradient styles + global widget theme:

- uses Material 3 (`useMaterial3: true`)
- custom `ColorScheme`
- Google Fonts (`Quicksand`)
- standardized `InputDecorationTheme` and button style

Learning point:
- Theme centralization gives consistency and easier UI refactors.

---

## Data models

### `lib/models/message.dart`
`Message` entity includes:

- `id`
- `fromUserId`
- `text`
- `sentAt`
- `expiresAt` computed from TTL
- `type` (`text` or `media`)
- `mediaUrl` (optional)
- `isExpired` getter

Learning point:
- Computed fields in constructors (`expiresAt = sentAt.add(...)`) are idiomatic Dart.

### `lib/models/user.dart`
`AppUser` model with:

- `userId`
- `username`
- optional `publicKey`
- optional `lastSeen`
- `factory AppUser.fromJson(...)` parser

Learning point:
- Factory constructors are common for JSON mapping in Dart.

---

## Cryptography layer

### `lib/crypto/crypto_service.dart`

Main responsibilities:

1. Generate keypair (`X25519().newKeyPair()`)
2. Export/import public keys as Base64
3. Derive shared secret (`sharedSecretKey`)
4. Encrypt/decrypt text with AES-GCM
5. Encrypt/decrypt binary data for media

Design quality:
- Crypto logic isolated from UI, which is excellent architecture.
- Functions are pure async operations and easy to test.

---

## Secure storage layer

### `lib/crypto/key_store.dart`

Stores sensitive and identity data with `flutter_secure_storage`:

- Private key (Base64)
- Public key (Base64)
- `user_id`
- `username`

Platform behavior:
- iOS Keychain
- Android Keystore + encrypted shared preferences

Learning point:
- Never use normal preferences for private keys.
- You correctly use secure hardware-backed storage paths.

---

## Network/service layer

### `lib/services/api_service.dart`
Current status: **stub / TODO**

Intended responsibilities:
- `register(...)`
- `getPublicKey(userId)`
- `getUsers()`

Important note:
- It currently references `AppUser` but does not import it (needs fix when implementing).

### `lib/services/socket_service.dart`
Current status: **stub / TODO**

Intended responsibilities:
- connect/register user
- send encrypted messages
- receive message events
- typing indicators
- disconnect lifecycle

### `lib/services/media_service.dart`
Most complete service currently:

- calls `/api/presign`
- encrypts file bytes locally
- uploads ciphertext to R2 via presigned `PUT`
- provides download/decrypt helper

Learning point:
- This is a strong pattern: backend issues short-lived upload permission; client uploads directly.

---

## Screens and user flow

### `lib/screens/login_screen.dart`
Current UI:
- User ID + display name form
- button triggers placeholder registration flow
- navigates to contacts

Current gap:
- no actual key generation / secure store write / API registration yet

### `lib/screens/contacts_screen.dart`
Current UI:
- placeholder user list
- refresh and logout actions
- opens chat with selected user

Current gap:
- not calling backend yet

### `lib/screens/chat_screen.dart`
Current UI:
- message list
- input bar
- send action adds local placeholder message

Current gap:
- no socket hookup
- no encrypt/decrypt path
- sender identity hardcoded as `'me'`

---

## Widgets

### `lib/widgets/chat_bubble.dart`
Simple visual bubble based on `isMe`.

### `lib/widgets/disappearing_timer.dart`
Live countdown timer per message.

Learning point:
- Demonstrates `StatefulWidget` lifecycle + `Timer.periodic` + cleanup in `dispose`.

---

## Node.js backend deep dive

## Server bootstrap

### `server/src/index.js`
Responsibilities:

- loads env
- creates Express app + HTTP server
- creates Socket.IO server with CORS
- mounts routes:
  - `/api` users
  - `/api` media
- initializes socket handlers
- connects MongoDB
- starts server on configured port

Learning point:
- Socket.IO attaches to raw HTTP server, not directly to Express app.

---

## Socket relay design

### `server/src/socket.js`

Behavior:

- tracks online users in in-memory `Map<userId, socketId>`
- on `register`, maps user to socket
- forwards:
  - `typing`
  - `send_message` → `receive_message`
  - `send_media` → `receive_media`
  - `message_ack`
- removes mapping on disconnect

Important design characteristic:
- Ephemeral in-memory online map, so restart clears presence state.
- Offline messages are currently dropped by design.

---

## REST routes

## `server/src/routes/users.js`

Implemented endpoints:

- `POST /api/register`
- `GET /api/public-key/:userId`
- `GET /api/users`

Important bug to notice:
- `register` validates `bday` as required, but update payload does not save `bday`.
- Error message says birthday required.
- Flutter currently does not send birthday.

This mismatch will break real registration unless corrected.

## `server/src/routes/media.js`

Implemented endpoints:

- `POST /api/presign` for R2 upload URL
- `DELETE /api/media/:key(*)` to remove object

Note:
- comment says “5-min URL” but code uses very large `expiresIn` value.
- should be reviewed for realistic/secure expiry value.

---

## MongoDB schema

### `server/src/db/mongo.js`

`User` schema fields:

- required: `userId`, `username`, `publicKey`
- optional extras: `note`, `avatar`, `bday`, `status`
- metadata: `createdAt`, `lastSeen`

Learning point:
- Mongoose schema is your contract layer for validation and indexing.

---

## R2 media presign flow

1. Flutter sends file extension/contentType to `/api/presign`
2. Server generates unique object key and signed `PUT` URL
3. Flutter encrypts bytes and uploads ciphertext to signed URL
4. Flutter shares encrypted metadata through chat socket
5. Recipient downloads ciphertext and decrypts locally

Why this is scalable:
- binary transfer bypasses your Node server data path
- backend remains control-plane, not data-plane

---

## End-to-end request/message flows

## Registration flow (intended)
1. Flutter generates keypair
2. Flutter stores keys locally
3. Flutter POSTs `{ userId, username, publicKey }`
4. Backend upserts user
5. Flutter socket-connects and emits `register`

## Send text flow (intended)
1. Fetch recipient public key
2. Derive shared secret
3. Encrypt plaintext
4. Emit `send_message` with opaque payload
5. Recipient decrypts on receive

## Send media flow (intended)
1. Derive shared secret
2. Presign upload URL
3. Encrypt file
4. Upload ciphertext
5. Send encrypted metadata payload via socket
6. Recipient downloads + decrypts

---

## Security model and caveats

### Good decisions already present
- Modern primitives (`X25519`, `AES-256-GCM`)
- Private keys remain on client
- Server is relay/directory, not decryption endpoint
- Encrypted media before cloud upload

### Current caveats / improvements needed
- No forward secrecy per message/session yet
- No replay protection metadata
- No signed identity verification / fingerprint verification UX
- No persistence strategy for secure offline message queue
- Some implementation stubs still bypass real cryptographic flow in UI layer

---

## Current implementation status

### Strongly implemented
- crypto service
- secure key storage utility
- backend relay and core routes
- media encryption/upload foundation
- app theme and base screens

### Partially implemented
- chat/contacts/login flows (UI exists, logic incomplete)
- API and socket services are placeholders

### Not implemented yet
- full auth/session lifecycle
- production-grade error handling
- robust state management and tests
- key verification UX
- group chat

---

## How to run locally

## Backend
1. Go to `server`
2. Install dependencies: `npm install`
3. Create `.env` from example template
4. Start dev server: `npm run dev`

## Flutter
1. Go to `flutter_app`
2. Install packages: `flutter pub get`
3. Run: `flutter run`

If app cannot connect:
- adjust `Constants.serverUrl` based on your runtime target.

---

## Environment variables

Backend expects values for:

- `PORT`
- `MONGO_URI`
- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_BUCKET_NAME`
- `R2_PUBLIC_URL`

Best practice:
- keep secrets in environment only
- never commit real credentials

---

## Dart concepts you are actively using

- `StatelessWidget` vs `StatefulWidget`
- async/await futures
- factory constructors for JSON
- nullable types and null safety
- immutable model patterns with `final`
- constructor initializer lists
- service-layer abstraction
- platform-secure storage integration
- typed enums for domain behavior

To go deeper next:
- Streams for socket events
- state management (Provider/Riverpod/BLoC)
- isolates/background processing for heavy crypto/media operations

---

## Node.js concepts you are actively using

- Express app + middleware pipeline
- route modularization
- Socket.IO event-driven architecture
- in-memory presence map
- Mongoose model/schema design
- S3-compatible presigned URL flows
- environment-driven config
- process bootstrap patterns

To go deeper next:
- schema validation with Zod/Joi at route boundary
- authentication middleware
- structured logging + observability
- horizontal scaling strategy for sockets (Redis adapter)

---

## Top issues to fix next

1. **Implement real `ApiService` and `SocketService`**
   - wire Flutter to backend endpoints/events
2. **Fix registration contract mismatch**
   - either remove required `bday` from backend route validation or send/store it consistently
3. **Complete login flow**
   - generate/load keypair and register user properly
4. **Complete contact loading**
   - fetch actual users from `/api/users`
5. **Complete chat encryption path**
   - encrypt before send, decrypt on receive, real sender identity
6. **Add robust error states**
   - snackbars, retry states, connection indicators
7. **Review presigned URL expiry**
   - align code and comments with secure practical expiration

---

## Suggested roadmap to learn as you build

### Phase 1 — Make the current app truly functional
- finish API + socket integration
- make E2E encrypted text messaging work fully
- add typed DTOs for payload contracts

### Phase 2 — Improve architecture quality
- introduce state management
- add repository layer and dependency injection
- add unit tests:
  - crypto
  - API parsing
  - socket event handling

### Phase 3 — Security hardening
- message/session key rotation
- replay prevention fields (nonce tracking / timestamps / IDs)
- key fingerprint verification UX
- optional message signatures

### Phase 4 — Product polish
- proper auth/session UX
- delivery/read states
- media previews and safe local cache policy
- profile/contact management

---

## Final learning note

This codebase is a **great practical lab** for learning both Dart and Node deeply:

- In Dart, you are learning UI state, async programming, secure storage, typed models, and crypto integration.
- In Node, you are learning API design, realtime sockets, data modeling, and cloud object storage workflows.

If you keep this learning-first approach, every feature you implement can teach one core concept from both frontend and backend at the same time.
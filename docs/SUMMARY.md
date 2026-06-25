# ChatApp - Work Summary

## Project Overview
End-to-end encrypted ephemeral chat app (Flutter + Node.js + MongoDB).

## Architecture

### Frontend (`flutter_app/`)
- **Flutter** app with **Riverpod** state management
- **sqflite** local message store
- **socket_io_client** for real-time messaging
- **cryptography** package for ECDH key exchange + AES-GCM encryption
- **flutter_secure_storage** for key storage
- Files/voice/image messages with E2E encryption

### Backend (`server/`)
- Node.js + Express + Socket.IO
- MongoDB with Mongoose
- JWT auth, group E2E key distribution
- Ephemeral messages (up to 24h expiry via TTL index)
- File upload with GridFS

## Current State

### Working
- `flutter analyze` — 0 errors
- `flutter test` — 53 passed, 8 skipped (message store tests need sqflite_common_ffi)
- Registration, login, user listing, online status
- E2E encryption (ECDH + AES-GCM), key exchange
- Real-time messaging via socket.io
- Message store with sqflite (24h expiry)
- Groups (E2E encrypted group keys)
- Voice messages, image/file sharing (E2E encrypted)
- Period tracker, goodnight messages, water reminder
- Onboarding flow
- Server URL config accessible before login
- Weather defaults to Addis Ababa

### Deployed
- **Railway**: Server live at `https://server-production-20e4.up.railway.app`
- MongoDB plugin: Internal Railway MongoDB instance
- Env vars: `MONGO_URI`, `JWT_SECRET`, `NODE_ENV=production`
- Default prod URL updated in `constants.dart`

### Pending
- Firebase Cloud Messaging: config present but untested
- Message store tests skipped (need `sqflite_common_ffi` for test env)

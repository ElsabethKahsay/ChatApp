# SecureChat

End-to-end encrypted messaging app with ephemeral messages, group chat, and privacy-focused features.

## Architecture

- **`flutter_app/`** — Flutter mobile app (Android/iOS/Web)
- **`server/`** — Node.js relay server (Express + Socket.IO + MongoDB)
- **`docs/`** — Project documentation

## Quick Start

```bash
# Server
cd server
cp .env.example .env    # Edit with your settings
node src/index.js

# App (separate terminal)
cd flutter_app
flutter run             # Or: flutter build apk --release
```

## Features

- End-to-end encryption (X25519 + AES-256)
- Ephemeral messages with self-destruct timers
- Group chat with encrypted relay
- Period tracker, mood tracker, birthday reminders
- Panic mode, screenshot detection
- Voice messages, media sharing
- Weather and fun facts

## Deployment

See `docs/PROGRESS.md` for production readiness checklist.

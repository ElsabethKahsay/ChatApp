# SecureChat - Private Messaging App 🔐

A secure, end-to-end encrypted messaging application designed for private communication among 5 people. Built with Flutter (mobile) and Node.js (backend), featuring ephemeral messaging and zero-knowledge architecture.

## 🏗️ Architecture Overview

### Frontend (Flutter)
- **Framework**: Flutter 3.3.0+
- **Language**: Dart
- **Target**: iOS/Android mobile apps
- **Location**: `/flutter_app/`

### Backend (Node.js)
- **Runtime**: Node.js 20.0.0+
- **Framework**: Express + Socket.IO
- **Database**: MongoDB Atlas
- **Storage**: Cloudflare R2 (media files)
- **Location**: `/server/`

## 🔐 Security Features

### End-to-End Encryption
- **Key Exchange**: X25519 Elliptic Curve Diffie-Hellman (ECDH)
- **Symmetric Encryption**: AES-256-GCM (Authenticated Encryption)
- **Key Storage**: Device secure storage (Keychain/Keystore)
- **Zero-Knowledge**: Server never sees plaintext messages or keys

### Privacy Features
- **Ephemeral Messages**: Messages exist only in memory during transmission
- **No Message History**: Server doesn't store message content
- **Offline Messages**: Currently dropped (by design for privacy)
- **Public Key Directory**: Server only stores public keys for key discovery

## 📱 Current Implementation Status

### ✅ Completed Features

#### Core Infrastructure
- **User Registration & Authentication**
  - Local X25519 key pair generation
  - Secure key storage using flutter_secure_storage
  - Public key registration on server
  - Session persistence

- **Cryptographic Foundation**
  - Complete X25519 key agreement implementation
  - AES-256-GCM encryption/decryption for text
  - File encryption/decryption for media
  - Secure key import/export functions

- **Backend API**
  - User registration endpoint (`POST /api/register`)
  - Public key discovery (`GET /api/public-key/:userId`)
  - User directory listing (`GET /api/users`)
  - MongoDB integration with user model
  - Health check endpoint

- **Real-time Communication**
  - Socket.IO server setup with CORS support
  - User registration and online tracking
  - Encrypted message relay system
  - Typing indicators
  - Message acknowledgments
  - Media metadata relay

#### UI Components
- **Login Screen**
  - User ID and display name input
  - Key generation on registration
  - Session restoration
  - Beautiful gradient design with proper theming

#### Configuration
- Environment configuration template
- Package dependencies properly configured
- Development scripts ready

### 🚧 In Progress / Partially Implemented

#### Chat Interface
- Contact selection screen exists but needs implementation
- Chat screen structure exists but needs message display
- Message input and encryption flow needs completion

#### Media Handling
- Server routes for media upload exist
- File encryption functions implemented
- Media picker integration in Flutter app
- Cloudflare R2 integration configured but not fully implemented

#### Message History
- Currently ephemeral (no storage)
- Consider implementing optional local message history
- TTL-based offline message queue consideration

### ❌ Not Yet Implemented

#### Advanced Features
- **Group Chat**: Currently only 1-on-1 messaging
- **Message Deletion**: Burn after reading timer
- **File Sharing**: Complete media upload/download flow
- **Push Notifications**: For offline message alerts
- **Message Status**: Delivered/Read receipts beyond basic ACK
- **Contact Management**: Block/unblock functionality
- **Profile Management**: Avatar upload, status updates

#### Security Enhancements
- **Key Rotation**: Periodic key refresh
- **Perfect Forward Secrecy**: Per-session keys
- **Message Verification**: Digital signatures
- **Key Verification**: QR code key verification
- **Security Audit**: Third-party security review

#### User Experience
- **Onboarding**: Security explanation for users
- **Settings**: Encryption settings, privacy options
- **Backup**: Encrypted backup/restore functionality
- **Multi-device**: Synchronization across devices

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.3.0+
- Node.js 20.0.0+
- MongoDB Atlas account
- Cloudflare R2 account (for media)

### Backend Setup
1. Clone and navigate to server directory:
   ```bash
   cd server
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Configure environment:
   ```bash
   cp .env.example .env
   # Edit .env with your MongoDB and R2 credentials
   ```

4. Start development server:
   ```bash
   npm run dev
   ```

### Frontend Setup
1. Clone and navigate to Flutter app:
   ```bash
   cd flutter_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## 📋 Next Development Steps

### Immediate Priorities (Week 1)
1. **Complete Chat Interface**
   - Implement message display with decryption
   - Add message input with encryption
   - Integrate real-time message updates

2. **Contact Management**
   - Complete contacts screen with user listing
   - Add contact selection and chat initiation
   - Implement online status indicators

3. **Media Sharing**
   - Complete file upload to Cloudflare R2
   - Implement encrypted media download
   - Add image preview and file handling

### Short Term (Week 2-3)
1. **Message History**
   - Implement optional local message storage
   - Add message search functionality
   - Implement message deletion options

2. **User Experience**
   - Add proper error handling and loading states
   - Implement settings screen
   - Add user onboarding flow

### Medium Term (Month 2)
1. **Group Chat Support**
   - Implement group creation and management
   - Add group encryption (multiple recipients)
   - Design group chat interface

2. **Security Enhancements**
   - Implement key rotation
   - Add message verification codes
   - Implement perfect forward secrecy

## 🔧 Technical Details

### Encryption Flow
1. **Registration**: User generates X25519 key pair locally
2. **Key Exchange**: Public keys stored on server for discovery
3. **Message Encryption**: 
   - Sender fetches recipient's public key
   - Performs ECDH to derive shared secret
   - Encrypts message with AES-256-GCM
   - Sends encrypted payload via Socket.IO
4. **Message Decryption**: Recipient derives same shared secret and decrypts

### Data Flow
- **Server**: Only routes encrypted payloads, never sees plaintext
- **Storage**: Only public keys and user metadata stored on server
- **Messages**: Ephemeral, exist only during transmission
- **Keys**: Private keys never leave device

## 🛡️ Security Considerations

### Current Security Model
- ✅ End-to-end encryption for all messages
- ✅ Zero-knowledge server architecture
- ✅ Secure key storage on device
- ✅ Authenticated encryption (AES-256-GCM)
- ✅ Ephemeral messaging

### Potential Security Improvements
- ⚠️ No forward secrecy yet (shared secrets reused)
- ⚠️ No key rotation mechanism
- ⚠️ No message authentication beyond MAC
- ⚠️ No protection against replay attacks
- ⚠️ No device compromise protection

## 📞 Contact & Support

This is a private messaging application designed for secure communication among a small group of users. For technical questions or security concerns, please refer to the code documentation or create an issue in the project repository.

---

**Note**: This application is designed for educational and private use. While it implements strong cryptographic primitives, it has not undergone a professional security audit. For mission-critical communications, consider using established encrypted messaging apps.

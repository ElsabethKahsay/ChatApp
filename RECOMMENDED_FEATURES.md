# Recommended Features for Future Implementation

## Priority 1: Core Messaging Enhancements

### 1.1 Message Persistence (Server-Side)
**Current State:** Messages are only relayed in real-time. If both users are offline, messages may be lost.

**Implementation:**
- Add `Message` schema to MongoDB with fields: `messageId`, `from`, `to`, `payload`, `createdAt`, `delivered`, `read`
- Store encrypted messages on server until recipient retrieves them
- Delete messages after successful delivery (or set TTL)
- Add endpoint: `GET /api/messages?before=...&limit=50` for message history

**Estimate:** 2-3 days

### 1.2 Push Notifications
**Current State:** FCM token is stored but not used for notifications.

**Implementation:**
- Add FCM integration in Node.js using `firebase-admin` SDK
- Send push notification when message received but recipient offline
- Include `data` payload with message metadata (don't include plaintext)
- Handle notification tap to open chat
- Add notification settings (mute, DND hours)

**Files to modify:**
- `server/src/socket.js` - trigger notification on `send_message`
- `flutter_app/lib/services/push_notification_service.dart`

**Estimate:** 2-3 days

---

## Priority 2: Media & File Sharing

### 2.1 Image Sharing
**Current State:** Backblaze B2 is configured, but Flutter app doesn't implement media sending.

**Implementation:**
- Use `image_picker` to select images
- Encrypt image bytes before upload using existing `CryptoService.encryptBytes()`
- Get presigned URL from `/api/presign`
- Upload encrypted file directly to B2
- Send `send_media` socket event with download URL
- Download, decrypt, and display in chat

**Files to modify:**
- `flutter_app/lib/services/media_service.dart` (exists but empty)
- `flutter_app/lib/screens/chat_screen.dart` - add image picker

**Estimate:** 2-3 days

### 2.2 File Sharing
- Extend media service to support documents
- Add file picker UI
- Show file metadata (name, size, type)
- Download progress indicator

**Estimate:** 1-2 days

---

## Priority 3: User Experience

### 3.1 Message Status Indicators
**Current State:** Basic delivered/read tracking exists.

**Enhancements:**
- Visual indicators in chat bubbles:
  - Single checkmark: Sent
  - Double checkmark: Delivered to server
  - Blue double checkmark: Delivered to recipient
  - "Read" text with timestamp
- Show "last seen" time under contact names
- Add "message not sent" retry button

**Estimate:** 1-2 days

### 3.2 Typing Indicators
**Current State:** Already implemented in backend and frontend.

**Improvements:**
- Add "Someone is typing..." toast for new messages
- Show typing indicator in contact list
- Debounce typing events (300ms delay)

**Status:** ✅ Mostly done

### 3.3 Contact Management
**Current State:** Shows all registered users.

**Enhancements:**
- Add "Add Contact" by username search
- Create `contacts` collection with `userId`, `contactId`, `addedAt`
- Show only added contacts in list
- Block/unblock users
- Contact profiles with avatar upload

**Estimate:** 2-3 days

---

## Priority 4: Security & Privacy

### 4.1 Disappearing Messages
**Current State:** UI shows timer but auto-delete not implemented.

**Implementation:**
- Add `expiresAt` field to messages
- Auto-delete from local storage when timer expires
- Add "self-destruct" option for sent messages
- Prevent screenshots (Android FLAG_SECURE)

**Estimate:** 1-2 days

### 4.2 Screen Security
- Prevent screenshots in chat screen
- Hide message content in app switcher
- Biometric authentication for app unlock

**Estimate:** 1 day

### 4.3 Key Verification
**Current State:** No verification of peer's public key.

**Implementation:**
- Display key fingerprint (SHA-256 hash of public key)
- QR code for in-person verification
- "Verified" badge when keys match
- Warning if key changes (possible MITM)

**Estimate:** 2 days

---

## Priority 5: Group Chat

### 5.1 Basic Group Chat
- Create `Group` schema: `groupId`, `name`, `creator`, `members[]`, `createdAt`
- Socket room for each group
- Group encryption using pairwise keys or shared group key
- Admin controls (add/remove members, delete group)

**Estimate:** 3-5 days

### 5.2 Group Features
- Group icon/avatar
- Member roles (admin, moderator, member)
- Group settings (mute, leave, delete)
- @mentions

**Estimate:** 2-3 days

---

## Priority 6: Platform Features

### 6.1 iOS Support
**Current State:** Code is mostly platform-agnostic.

**Needed:**
- Test on iOS simulator/device
- Configure push notifications with APNs
- Update iOS-specific network security config
- Test keychain integration

**Estimate:** 2-3 days

### 6.2 Web/Desktop Support
- Flutter web build
- Different key storage strategy (IndexedDB)
- WebSocket connection handling
- Service worker for background sync

**Estimate:** 3-5 days

---

## Priority 7: Advanced Features

### 7.1 Message Replies
- Swipe-to-reply gesture
- Quote original message
- Threaded conversation view

**Estimate:** 2 days

### 7.2 Message Reactions
- Add emoji reactions to messages
- Show reaction count
- Notification for reactions

**Estimate:** 1-2 days

### 7.3 Voice Messages
- Audio recording using `flutter_sound`
- Encrypt audio file before sending
- Waveform visualization
- Playback controls

**Estimate:** 2-3 days

### 7.4 Location Sharing
- Share current location
- Open in maps app
- Live location sharing (15 min)

**Estimate:** 2 days

---

## Priority 8: Backup & Recovery

### 8.1 Encrypted Backup
- Export encrypted message history
- Backup to cloud (iCloud/Google Drive)
- Import on new device

**Estimate:** 2-3 days

### 8.2 Account Recovery
- Recovery phrase (BIP39 mnemonic)
- Re-generate keys from phrase
- Emergency contact recovery

**Estimate:** 3-4 days

---

## Development Priority Ranking

### Week 1-2: Core Stability
1. Message persistence (server-side)
2. Push notifications
3. Image sharing

### Week 3-4: UX Improvements
4. Message status indicators
5. Contact management
6. Disappearing messages

### Week 5-6: Security
7. Key verification
8. Screen security
9. Group chat (basic)

### Week 7+: Advanced
10. iOS support
11. Voice messages
12. Message replies/reactions

---

## Technical Debt to Address

1. **Add comprehensive tests**
   - Unit tests for crypto functions
   - Widget tests for screens
   - Integration tests for API

2. **Error logging**
   - Integrate Sentry or similar for crash reporting
   - Add structured logging in backend

3. **Performance optimization**
   - Message pagination in chat
   - Image caching
   - Lazy loading for contact list

4. **Code organization**
   - Extract business logic from UI
   - Create repositories for data access
   - Add state management (Riverpod/Bloc)

---

## Summary

The app is production-ready for basic 1:1 encrypted messaging. Priority features to add value:

1. **Message persistence** - Reliability
2. **Push notifications** - User engagement
3. **Image sharing** - Core chat feature
4. **Group chat** - User retention
5. **iOS support** - Market coverage

Each feature includes file locations and effort estimates for planning sprints.

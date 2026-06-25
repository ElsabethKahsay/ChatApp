const mongoose = require('mongoose');

/**
 * User schema with embedded subdocuments for saved content.
 * Subdocument schemas are defined inline before model compilation
 * to ensure Mongoose properly registers them.
 */
const savedMessageSchema = new mongoose.Schema({
  content: {
    ciphertext: { type: String, required: true },
    nonce: { type: String, required: true },
    mac: { type: String, required: true },
  },
  label: { type: String },
  createdAt: { type: Date, default: Date.now },
});

const userSchema = new mongoose.Schema({
  userId:    { type: String, unique: true, required: true, index: true },
  username:  { type: String, required: true },
  passwordHash: { type: String, required: true },
  bday: { type: Date },                        // Birthday for reminders
  mood: { type: String, default: '😊' },         // Pet mood emoji
  auraColor: { type: String, default: '#F5A6D4' }, // Custom accent color (hex)
  city: { type: String },                      // City for weather
  status: { type: Boolean },
  publicKey: { type: String, required: true }, // base64-encoded X25519 public key
  fcmToken: { type: String },                  // Firebase Cloud Messaging token
  fcmTokenUpdatedAt: { type: Date },           // When FCM token was last updated
  createdAt: { type: Date, default: Date.now },
  lastSeen:  { type: Date, default: Date.now },
  savedMessages: [savedMessageSchema],
  blockedUsers: [String],                      // User IDs this user has blocked
});

const reportSchema = new mongoose.Schema({
  messageId: { type: String, required: true },
  reason: { type: String, required: true },
  reportedUserId: { type: String, required: true },
  reportedBy: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
});

const User = mongoose.model('User', userSchema);
const Report = mongoose.model('Report', reportSchema);

module.exports = { User, Report };

const mongoose = require('mongoose');

/**
 * User schema.
 * The server only stores userId, username, and the PUBLIC key.
 * Private keys NEVER leave the client device.
 */
const userSchema = new mongoose.Schema({
  userId:    { type: String, unique: true, required: true, index: true },
  username:  { type: String, required: true },
  passwordHash: { type: String, required: true },
  note: { type: String },
  avatar: { type: String },
  bday: { type: Date },
  status: { type: Boolean },
  publicKey: { type: String, required: true }, // base64-encoded X25519 public key
  fcmToken: { type: String },                  // Firebase Cloud Messaging token
  fcmTokenUpdatedAt: { type: Date },           // When FCM token was last updated
  createdAt: { type: Date, default: Date.now },
  lastSeen:  { type: Date, default: Date.now },
});

const User = mongoose.model('User', userSchema);

const SavedMessageSchema = new mongoose.Schema({
  messageId: { type: String, required: true },
  payload: { type: Object, required: true },
  sentAt: { type: Date, default: Date.now },
});

const SavedMediaSchema = new mongoose.Schema({
  mediaId: { type: String, required: true },
  url: { type: String, required: true },
  uploadedAt: { type: Date, default: Date.now },
});

const SavedFileSchema = new mongoose.Schema({
  fileId: { type: String, required: true },
  url: { type: String, required: true },
  uploadedAt: { type: Date, default: Date.now },
});
 const ReminderSchema = new mongoose.Schema({
  reminderId: { type: String, required: true },
  content: { type: String, required: true },
  remindAt: { type: Date, required: true },
  createdAt: { type: Date, default: Date.now },
});
userSchema.add({
  savedMessages: [SavedMessageSchema],
  savedMedia: [SavedMediaSchema],
  savedFiles: [SavedFileSchema],
  reminders: [ReminderSchema],  
});


module.exports = mongoose.model('User', userSchema);

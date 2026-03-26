const mongoose = require('mongoose');

/**
 * User schema.
 * The server only stores userId, username, and the PUBLIC key.
 * Private keys NEVER leave the client device.
 */
const userSchema = new mongoose.Schema({
  userId:    { type: String, unique: true, required: true, index: true },
  username:  { type: String, required: true },
  note: {type: String},
  avatar: {type: String},
  bday: {type: Date},
  status: {type: Boolean},
  publicKey: { type: String, required: true }, // base64-encoded X25519 public key
  createdAt: { type: Date, default: Date.now },
  lastSeen:  { type: Date, default: Date.now },
});

module.exports = mongoose.model('User', userSchema);

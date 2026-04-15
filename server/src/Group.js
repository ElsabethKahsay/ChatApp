const mongoose = require('mongoose');

const groupSchema = new mongoose.Schema({
  name: { type: String, required: true },
  creator: { type: String, required: true },
  members: [{ type: String }], // Array of userIds
  // Store the Group Key encrypted specifically for each member
  // Map: userId -> { ciphertext, nonce, mac }
  encryptedKeys: {
    type: Map,
    of: {
      ciphertext: String,
      nonce: String,
      mac: String
    }
  },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Group', groupSchema);
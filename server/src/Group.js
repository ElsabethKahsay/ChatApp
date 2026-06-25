const mongoose = require('mongoose');

const groupSchema = new mongoose.Schema({
  name: { type: String, required: true },
  creator: { type: String, required: true },
  creatorPublicKey: { type: String, required: true }, // V1 REQUIREMENT: Needed for members to derive keys
  members: [{ type: String }],
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

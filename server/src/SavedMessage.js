const mongoose = require('mongoose');

const savedMessageSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  content: {
    ciphertext: { type: String, required: true },
    nonce: { type: String, required: true },
  },
  label: { type: String }, // Optional title for the saved message
  createdAt: { type: Date, default: Date.now }
});

savedMessageSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('SavedMessage', savedMessageSchema);
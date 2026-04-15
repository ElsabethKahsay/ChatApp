/**
 * Message schema for server-side message persistence.
 * Messages are stored temporarily until delivered.
 * Content is encrypted - server never sees plaintext.
 */
const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  messageId: { type: String, required: true, index: true },
  from: { type: String, required: true, index: true },
  to: { type: String, required: true, index: true },
  payload: { type: Object, required: true }, // encrypted content
  type: { type: String, enum: ['text', 'media', 'file'], default: 'text' },
  delivered: { type: Boolean, default: false },
  deliveredAt: { type: Date },
  read: { type: Boolean, default: false },
  readAt: { type: Date },
  expiresAt: { type: Date }, // for auto-deletion
  createdAt: { type: Date, default: Date.now },
});

// Compound index for efficient queries
messageSchema.index({ to: 1, delivered: 1, createdAt: -1 });
messageSchema.index({ from: 1, to: 1, createdAt: -1 });

// Auto-delete messages after 30 days (configurable)
messageSchema.index({ createdAt: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 30 });

const Message = mongoose.model('Message', messageSchema);

/**
 * Save a message to the database
 */
async function saveMessage(messageData) {
  try {
    const message = new Message(messageData);
    await message.save();
    return message;
  } catch (err) {
    console.error('Error saving message:', err);
    throw err;
  }
}

/**
 * Get undelivered messages for a user
 */
async function getUndeliveredMessages(userId) {
  try {
    return await Message.find({
      to: userId,
      delivered: false,
    }).sort({ createdAt: 1 });
  } catch (err) {
    console.error('Error getting undelivered messages:', err);
    return [];
  }
}

/**
 * Mark messages as delivered
 */
async function markDelivered(messageIds) {
  try {
    await Message.updateMany(
      { messageId: { $in: messageIds } },
      { delivered: true, deliveredAt: new Date() }
    );
  } catch (err) {
    console.error('Error marking messages delivered:', err);
  }
}

/**
 * Mark a message as read
 */
async function markRead(messageId) {
  try {
    await Message.findOneAndUpdate(
      { messageId },
      { read: true, readAt: new Date() }
    );
  } catch (err) {
    console.error('Error marking message read:', err);
  }
}

/**
 * Get message history between two users
 */
async function getMessageHistory(userId1, userId2, options = {}) {
  const { before, limit = 50 } = options;

  try {
    const query = {
      $or: [
        { from: userId1, to: userId2 },
        { from: userId2, to: userId1 },
      ],
    };

    if (before) {
      query.createdAt = { $lt: new Date(before) };
    }

    return await Message.find(query)
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean();
  } catch (err) {
    console.error('Error getting message history:', err);
    return [];
  }
}

/**
 * Delete old delivered messages (cleanup)
 */
async function cleanupOldMessages(days = 7) {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);

  try {
    const result = await Message.deleteMany({
      delivered: true,
      deliveredAt: { $lt: cutoff },
    });
    console.log(`Cleaned up ${result.deletedCount} old messages`);
    return result.deletedCount;
  } catch (err) {
    console.error('Error cleaning up messages:', err);
    return 0;
  }
}

module.exports = {
  Message,
  saveMessage,
  getUndeliveredMessages,
  markDelivered,
  markRead,
  getMessageHistory,
  cleanupOldMessages,
};

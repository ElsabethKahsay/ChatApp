const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  messageId: { type: String, required: true, index: true },
  from: { type: String, required: true, index: true },
  to: { type: String, required: true, index: true }, // Peer ID or Group ID
  payload: { type: Object, required: true },
  type: { type: String, enum: ['text', 'media', 'group'], default: 'text' },
  delivered: { type: Boolean, default: false },
  sentAt: { type: Number, required: true },
  deleteAt: { type: Date, required: true },
  createdAt: { type: Date, default: Date.now },
});

messageSchema.index({ deleteAt: 1 }, { expireAfterSeconds: 0 });
messageSchema.index({ to: 1, sentAt: -1 });

const Message = mongoose.model('Message', messageSchema);

async function saveMessage(messageData) {
  if (!messageData.sentAt) messageData.sentAt = Date.now();
  if (!messageData.deleteAt) {
    messageData.deleteAt = new Date(messageData.sentAt + 24 * 60 * 60 * 1000);
  }
  const message = new Message(messageData);
  return await message.save();
}

module.exports = {
  Message,
  saveMessage,
  getUndeliveredMessages: async (userId) => await Message.find({ to: userId, delivered: false }),
  markDelivered: async (ids) => await Message.updateMany({ messageId: { $in: ids } }, { delivered: true }),

  // V1 FIX: Fetch private history
  getMessageHistory: async (u1, u2) => await Message.find({
    $or: [
      { from: u1, to: u2 },
      { from: u2, to: u1 }
    ]
  }).sort({ sentAt: -1 }).limit(50),

  // V1 FIX: Fetch group history
  getGroupHistory: async (groupId) => await Message.find({ to: groupId }).sort({ sentAt: -1 }).limit(100),

  findMessageById: async (id) => await Message.findOne({ messageId: id }),
};

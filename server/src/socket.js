const jwt = require('jsonwebtoken');
const Redis = require('ioredis');
const { createAdapter } = require('@socket.io/redis-adapter');
const { User } = require('./db/mongo');
const Group = require('./Group');
const { saveMessage } = require('./db/message');

// SECURITY: Check if senderId is in recipientId's blockedUsers list
const isBlocked = async (senderId, recipientId) => {
  try {
    const recipient = await User.findOne({ userId: recipientId }, { blockedUsers: 1 });
    return recipient?.blockedUsers?.includes(senderId) === true;
  } catch { return false; }
};
const { sendPushNotification } = require('./firebase');

module.exports = (io, jwtSecret) => {
  let redisClient;
  const onlineUsers = new Map();
  const offlineQueue = new Map();
  const redisAvailable = Boolean(process.env.REDIS_URL);
  const ONLINE_HASH = 'securechat:onlineUsers';

  if (redisAvailable) {
    redisClient = new Redis(process.env.REDIS_URL);
    const subClient = redisClient.duplicate();
    io.adapter(createAdapter(redisClient, subClient));
  }

  const getOnline = async (userId) => {
    if (redisClient) return await redisClient.hget(ONLINE_HASH, userId);
    return onlineUsers.get(userId);
  };

  const queueOfflinePayload = async (toUserId, payload) => {
    if (!toUserId) return;
    if (redisClient) {
      const key = `securechat:pending:${toUserId}`;
      await redisClient.lpush(key, JSON.stringify(payload));
      await redisClient.expire(key, 86400);
    } else {
      if (!offlineQueue.has(toUserId)) offlineQueue.set(toUserId, []);
      offlineQueue.get(toUserId).push(payload);
    }

    // Trigger Push Notification for new messages
    if (payload.event === 'receive_message' || payload.event === 'receive_group_message') {
      try {
        const recipient = await User.findOne({ userId: toUserId });
        if (recipient && recipient.fcmToken) {
          sendPushNotification(recipient.fcmToken, {
            title: 'New Message',
            body: 'You have a new encrypted message.',
            data: { type: 'new_message' }
          });
        }
      } catch (e) { console.error('Push Error:', e.message); }
    }
  };

  const drainQueuedMessages = async (userId, socket) => {
    let items = [];
    if (redisClient) {
      const key = `securechat:pending:${userId}`;
      const rawItems = await redisClient.lrange(key, 0, -1);
      items = rawItems.map(JSON.parse).reverse();
      await redisClient.del(key);
    } else {
      items = offlineQueue.get(userId) || [];
      offlineQueue.delete(userId);
    }
    for (const item of items) socket.emit(item.event, item.body);
  };

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token) return next(new Error('Missing token'));
      const decoded = jwt.verify(token, jwtSecret);
      socket.userId = decoded.userId;
      next();
    } catch (err) {
      next(new Error('Authentication error'));
    }
  });

  io.on('connection', async (socket) => {
    onlineUsers.set(socket.userId, socket.id);
    if (redisClient) await redisClient.hset(ONLINE_HASH, socket.userId, socket.id);
    await drainQueuedMessages(socket.userId, socket);

    socket.on('send_message', async (data) => {
      // SECURITY: Drop message if sender is blocked by recipient
      if (await isBlocked(socket.userId, data.to)) return;

      const recipientSocketId = await getOnline(data.to);
      const sentAt = data.sentAt || Date.now();
      const msg = { from: socket.userId, to: data.to, payload: data.payload, messageId: data.messageId, sentAt, deleteAt: new Date(sentAt + 86400000) };

      await saveMessage(msg);

      if (recipientSocketId) {
        io.to(recipientSocketId).emit('receive_message', msg);
        socket.emit('message_ack', { messageId: data.messageId });
      } else {
        await queueOfflinePayload(data.to, { event: 'receive_message', body: msg });
      }
    });

    socket.on('send_group_message', async (data) => {
      let group;
      try {
        group = await Group.findById(data.groupId);
      } catch (e) {
        return socket.emit('message_ack', { messageId: data.messageId, error: 'Group lookup failed' });
      }
      if (!group) return socket.emit('message_ack', { messageId: data.messageId, error: 'Group not found' });
      const sentAt = data.sentAt || Date.now();
      const msg = { from: socket.userId, to: data.groupId, payload: data.payload, messageId: data.messageId, sentAt, type: 'group', deleteAt: new Date(sentAt + 86400000) };
      await saveMessage(msg);

      for (const memberId of group.members) {
        if (memberId === socket.userId) continue;
        // SECURITY: Skip delivery to members who blocked the sender
        if (await isBlocked(socket.userId, memberId)) continue;
        const memberSocketId = await getOnline(memberId);
        if (memberSocketId) {
          io.to(memberSocketId).emit('receive_group_message', { ...msg, groupId: data.groupId });
        } else {
          await queueOfflinePayload(memberId, { event: 'receive_group_message', body: { ...msg, groupId: data.groupId } });
        }
      }
      socket.emit('message_ack', { messageId: data.messageId });
    });

    // V1 PRODUCTION RELAY: Read Receipts
    socket.on('message_read', async (data) => {
      const recipientSocketId = await getOnline(data.toUserId);
      const payload = { from: socket.userId, messageId: data.messageId, readAt: Date.now() };
      if (recipientSocketId) {
        io.to(recipientSocketId).emit('message_read', payload);
      } else {
        await queueOfflinePayload(data.toUserId, { event: 'message_read', body: payload });
      }
    });

    socket.on('message_ack', async (data) => {
      const fromSocketId = await getOnline(data.to); // Relaying ack back to sender
      if (fromSocketId) {
        io.to(fromSocketId).emit('message_ack', { messageId: data.messageId, from: socket.userId });
      }
    });

    // ── Typing Indicators ─────────────────────────────────────────────
    socket.on('typing', async (data) => {
      const { toUserId, groupId } = data;
      if (groupId) {
        // Group typing: relay to all online group members
        const group = await Group.findById(groupId).catch(() => null);
        if (!group) return;
        for (const memberId of group.members) {
          if (memberId === socket.userId) continue;
          const memberSocketId = await getOnline(memberId);
          if (memberSocketId) {
            io.to(memberSocketId).emit('typing', { from: socket.userId, groupId });
          }
        }
      } else if (toUserId) {
        const recipientSocketId = await getOnline(toUserId);
        if (recipientSocketId) {
          io.to(recipientSocketId).emit('typing', { from: socket.userId });
        }
      }
    });

    socket.on('stop_typing', async (data) => {
      const { toUserId, groupId } = data;
      if (groupId) {
        const group = await Group.findById(groupId).catch(() => null);
        if (!group) return;
        for (const memberId of group.members) {
          if (memberId === socket.userId) continue;
          const memberSocketId = await getOnline(memberId);
          if (memberSocketId) {
            io.to(memberSocketId).emit('stop_typing', { from: socket.userId, groupId });
          }
        }
      } else if (toUserId) {
        const recipientSocketId = await getOnline(toUserId);
        if (recipientSocketId) {
          io.to(recipientSocketId).emit('stop_typing', { from: socket.userId });
        }
      }
    });

    socket.on('disconnect', async () => {
      onlineUsers.delete(socket.userId);
      // SECURITY FIX: Clean up Redis online registry to prevent orphaned entries
      if (redisClient) {
        try { await redisClient.hdel(ONLINE_HASH, socket.userId); } catch (_) {}
      }
    });
  });
};

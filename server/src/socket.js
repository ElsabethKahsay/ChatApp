/**
 * socket.js — Pure relay. The server NEVER sees plaintext.
 * It only forwards opaque encrypted payloads between connected clients.
 */
const jwt = require('jsonwebtoken');
const Redis = require('ioredis');
const { createAdapter } = require('@socket.io/redis-adapter');
const User = require('./db/mongo');

module.exports = (io, jwtSecret) => {
  let redisClient;
  const onlineUsers = new Map();
  const redisAvailable = Boolean(process.env.REDIS_URL);
  const ONLINE_HASH = 'securechat:onlineUsers';

  if (redisAvailable) {
    redisClient = new Redis(process.env.REDIS_URL);
    const subClient = redisClient.duplicate();

    io.adapter(createAdapter(redisClient, subClient));

    redisClient.on('error', (err) => console.error('Redis error:', err));
    redisClient.on('connect', () => console.log('Redis connected for socket adapter'));
  } else {
    console.warn('Redis URL not configured, falling back to in-memory session store. Horizontal scaling disabled.');
  }

  const setOnline = async (userId, socketId) => {
    if (redisClient) {
      await redisClient.hset(ONLINE_HASH, userId, socketId);
    } else {
      onlineUsers.set(userId, socketId);
    }
  };

  const getOnline = async (userId) => {
    if (redisClient) {
      return await redisClient.hget(ONLINE_HASH, userId);
    }
    return onlineUsers.get(userId);
  };

  const removeOnline = async (userId) => {
    if (redisClient) {
      await redisClient.hdel(ONLINE_HASH, userId);
    } else {
      onlineUsers.delete(userId);
    }
  };

  const queueOfflinePayload = async (toUserId, payload) => {
    if (!redisClient) return;
    const key = `securechat:pending:${toUserId}`;
    await redisClient.lpush(key, JSON.stringify(payload));
    await redisClient.expire(key, 60 * 60 * 24); // 24h auto-expiry
  };

  const drainQueuedMessages = async (userId, socket) => {
    if (!redisClient) return;
    const key = `securechat:pending:${userId}`;
    const items = await redisClient.lrange(key, 0, -1);
    if (!items.length) return;

    await redisClient.del(key);

    for (const raw of items.reverse()) {
      try {
        const item = JSON.parse(raw);
        socket.emit(item.event, item.body);
      } catch (err) {
        console.error('Invalid queued message payload:', err);
      }
    }
  };

  const validateSocketPayload = (event, data) => {
    if (!data || typeof data !== 'object') {
      return `Invalid payload for ${event}`;
    }

    if (event === 'typing') {
      if (typeof data.to !== 'string' || typeof data.isTyping !== 'boolean') {
        return 'Malformed typing event';
      }
    } else if (['send_message', 'send_media'].includes(event)) {
      if (typeof data.to !== 'string' || typeof data.messageId !== 'string' || !data.payload) {
        return 'Malformed message/media payload';
      }
      const jsonSize = Buffer.byteLength(JSON.stringify(data.payload), 'utf8');
      if (jsonSize > 10240) {
        return 'Payload exceeds 10KB limit';
      }
    } else if (event === 'message_ack') {
      if (typeof data.to !== 'string' || typeof data.messageId !== 'string') {
        return 'Malformed ack payload';
      }
    }

    return null;
  };

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token) {
        return next(new Error('Authentication error: missing token'));
      }

      const decoded = jwt.verify(token, jwtSecret);
      if (!decoded || typeof decoded !== 'object' || !decoded.userId) {
        return next(new Error('Authentication error: invalid token'));
      }

      const user = await User.findOne({ userId: decoded.userId });
      if (!user) {
        return next(new Error('Authentication error: user not found'));
      }

      socket.userId = decoded.userId;
      console.log(` Authenticated socket ${socket.id} as ${socket.userId}`);
      return next();
    } catch (err) {
      console.error('Socket auth failed:', err.message || err);
      return next(new Error('Authentication error'));
    }
  });

  io.on('connection', async (socket) => {
    console.log(` Socket connected: ${socket.id}`);

    if (!socket.userId) {
      socket.disconnect(true);
      return;
    }

    // allow single active socket per user; terminate the previous one
    const existingSocketId = await getOnline(socket.userId);
    if (existingSocketId && existingSocketId !== socket.id) {
      const existingSocket = io.sockets.sockets.get(existingSocketId);
      existingSocket?.emit('session_replaced', { reason: 'new_connection' });
      existingSocket?.disconnect(true);
    }

    await setOnline(socket.userId, socket.id);
    await User.findOneAndUpdate({ userId: socket.userId }, { status: true, lastSeen: new Date() });
    io.emit('presence_update', { userId: socket.userId, online: true });

    socket.emit('registered', { success: true, socketId: socket.id, userId: socket.userId });

    await drainQueuedMessages(socket.userId, socket);

    socket.on('typing', async (data) => {
      const err = validateSocketPayload('typing', data);
      if (err) return socket.emit('error', { message: err });

      const recipientSocketId = await getOnline(data.to);
      if (recipientSocketId) {
        io.to(recipientSocketId).emit('typing', {
          from: socket.userId,
          isTyping: data.isTyping,
        });
      } else {
        socket.emit('user_offline', { to: data.to});
      }
    });

    socket.on('set_status', async (data) => {
      if (!data || typeof data.status !== 'boolean') {
        return socket.emit('error', { message: 'Malformed set_status event' });
      }

      await User.findOneAndUpdate({ userId: socket.userId }, { status: data.status, lastSeen: new Date() });
      io.emit('presence_update', { userId: socket.userId, online: data.status });
      socket.emit('status_updated', { status: data.status });
    });

    const forwardMessage = (eventIn, eventOut) => {
      socket.on(eventIn, async (data) => {
        const err = validateSocketPayload(eventIn, data);
        if (err) return socket.emit('error', { message: err });

        const recipientSocketId = await getOnline(data.to);
        const msg = {
          from: socket.userId,
          payload: data.payload,
          messageId: data.messageId,
          sentAt: Date.now(),
        };

        if (recipientSocketId) {
          io.to(recipientSocketId).emit(eventOut, msg);
        } else {
          await queueOfflinePayload(data.to, { event: eventOut, body: msg });
          socket.emit('offline_queued', {
            to: data.to,
            messageId: data.messageId,
            status: 'queued',
          });
        }
      });
    };

    forwardMessage('send_message', 'receive_message');
    forwardMessage('send_media', 'receive_media');

    socket.on('message_ack', async (data) => {
      const err = validateSocketPayload('message_ack', data);
      if (err) return socket.emit('error', { message: err });

      const recipientSocketId = await getOnline(data.to);
      if (recipientSocketId) {
        io.to(recipientSocketId).emit('message_ack', {
          from: socket.userId,
          messageId: data.messageId,
        });
      } else {
        socket.emit('error', { message: 'Recipient offline for ack' });
      }
    });

    socket.on('disconnect', async () => {
      if (socket.userId) {
        await removeOnline(socket.userId);
        await User.findOneAndUpdate({ userId: socket.userId }, { status: false, lastSeen: new Date() });
        io.emit('presence_update', { userId: socket.userId, online: false });
        console.log(`  Disconnected: ${socket.userId}`);
      }
    });
  });
};

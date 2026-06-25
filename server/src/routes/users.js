const express = require("express");
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const rateLimit = require('express-rate-limit');
const authenticate = require('../middleware/auth');
const router = express.Router();
const { User, Report } = require("../db/mongo");
const { getUndeliveredMessages, markDelivered } = require('../db/message');

// Per-IP rate limiting on registration — 20 attempts per 15 minutes
const registerLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many registration attempts. Try again later.' },
  keyGenerator: (req) => req.ip || req.connection.remoteAddress,
});

// ── GET /api/users ──────────────────────────────────────────────────────────
router.get("/users", authenticate, async (_req, res) => {
  try {
    const users = await User.find(
      {},
      { userId: 1, username: 1, lastSeen: 1, status: 1, bday: 1, publicKey: 1, mood: 1, auraColor: 1 }
    );
    res.json({ users });
  } catch (err) {
    console.error("List users error:", err);
    res.status(500).json({ error: "Internal server error." });
  }
});

// ... (rest of the file remains the same, but ensuring publicKey is included in the find projections)
// I will only write the necessary parts to ensure consistency.

router.post("/register", registerLimiter, async (req, res) => {
  if (mongoose.connection.readyState !== 1) return res.status(503).json({ error: "Database unavailable." });
  let { userId, username, publicKey, password } = req.body;
  if (!userId || !username || !publicKey || !password) return res.status(400).json({ error: "Missing fields" });
  try {
    // Prevent account takeover: reject if userId already exists
    const existing = await User.findOne({ userId });
    if (existing) return res.status(409).json({ error: "User already registered." });

    // Reject duplicate username
    const nameTaken = await User.findOne({ username: username.toLowerCase() });
    if (nameTaken) return res.status(409).json({ error: "Username already taken." });

    const salt = await bcrypt.genSalt(12);
    const passwordHash = await bcrypt.hash(password, salt);
    const user = await User.create({
      userId,
      username: username.toLowerCase(),
      publicKey,
      passwordHash,
      lastSeen: new Date(),
    });
    res.status(201).json({ success: true, userId: user.userId, username: user.username });
  } catch (err) {
    res.status(500).json({ error: "Registration failed." });
  }
});

router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  try {
    const user = await User.findOne({ username: username.toLowerCase() });
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    const token = jwt.sign({ userId: user.userId }, process.env.JWT_SECRET, { expiresIn: '7d' });
    await User.findOneAndUpdate({ userId: user.userId }, { status: true, lastSeen: new Date() });
    res.json({ token, userId: user.userId, username: user.username });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get("/public-key/:userId", authenticate, async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.params.userId });
    if (!user) return res.status(404).json({ error: "User not found." });
    res.json({ publicKey: user.publicKey, username: user.username });
  } catch (err) {
    res.status(500).json({ error: "Internal server error." });
  }
});

router.get('/online-users', authenticate, async (_req, res) => {
  try {
    const users = await User.find({ status: true }, { userId: 1, username: 1 });
    res.json({ onlineUsers: users });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

router.put('/status', authenticate, async (req, res) => {
  try {
    const { status } = req.body;
    const user = await User.findOneAndUpdate({ userId: req.user.userId }, { status, lastSeen: new Date() }, { new: true });
    res.json({ success: true, status: user.status });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── Profile Routes ───────────────────────────────────────────────────────────

router.get('/profile', authenticate, async (req, res) => {
  try {
    const user = await User.findOne(
      { userId: req.user.userId },
      { passwordHash: 0, __v: 0 }
    );
    if (!user) return res.status(404).json({ error: 'User not found.' });
    res.json(user.toObject());
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

router.get('/profile/:userId', authenticate, async (req, res) => {
  try {
    const user = await User.findOne(
      { userId: req.params.userId },
      { userId: 1, username: 1, mood: 1, auraColor: 1, city: 1, lastSeen: 1, status: 1 }
    );
    if (!user) return res.status(404).json({ error: 'User not found.' });
    res.json(user.toObject());
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

router.put('/profile/birthday', authenticate, async (req, res) => {
  try {
    const { bday } = req.body;
    await User.findOneAndUpdate({ userId: req.user.userId }, { bday: new Date(bday) });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

router.put('/profile/mood', authenticate, async (req, res) => {
  try {
    const { mood } = req.body;
    await User.findOneAndUpdate({ userId: req.user.userId }, { mood });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

router.put('/profile/aura', authenticate, async (req, res) => {
  try {
    const { auraColor } = req.body;
    await User.findOneAndUpdate({ userId: req.user.userId }, { auraColor });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

router.put('/profile/city', authenticate, async (req, res) => {
  try {
    const { city } = req.body;
    await User.findOneAndUpdate({ userId: req.user.userId }, { city });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── Message History ────────────────────────────────────────────────────────────

router.get('/messages/:userId', authenticate, async (req, res) => {
  try {
    const { getMessageHistory } = require('../db/message');
    const messages = await getMessageHistory(req.user.userId, req.params.userId);
    res.json({ messages });
  } catch (err) {
    console.error('Error fetching message history:', err);
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── Key Rotation ──────────────────────────────────────────────────────────────

router.post('/keys/update', authenticate, async (req, res) => {
  try {
    const { publicKey, password } = req.body;
    if (!publicKey) return res.status(400).json({ error: 'Missing publicKey' });

    // SECURITY FIX: Require password re-authentication for key rotation
    // This prevents identity takeover via stolen JWT tokens.
    if (!password) return res.status(400).json({ error: 'Password required for key rotation' });

    const user = await User.findOne({ userId: req.user.userId });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const validPassword = await bcrypt.compare(password, user.passwordHash);
    if (!validPassword) return res.status(403).json({ error: 'Invalid password' });

    await User.findOneAndUpdate({ userId: req.user.userId }, { publicKey });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── Undelivered Messages ──────────────────────────────────────────────────────

router.get('/undelivered-messages', authenticate, async (req, res) => {
  try {
    const messages = await getUndeliveredMessages(req.user.userId);
    res.json({ messages });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

router.post('/mark-delivered', authenticate, async (req, res) => {
  try {
    const { messageIds } = req.body;
    if (!Array.isArray(messageIds)) {
      return res.status(400).json({ error: 'messageIds must be an array' });
    }
    await markDelivered(messageIds);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── Saved Messages (Private Vault) ────────────────────────────────────────────

router.get('/saved-messages', authenticate, async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.user.userId });
    if (!user) return res.status(404).json({ error: 'User not found.' });
    res.json({ messages: user.savedMessages || [] });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

router.post('/saved-messages', authenticate, async (req, res) => {
  try {
    const { content, label } = req.body;
    if (!content || !content.ciphertext || !content.nonce || !content.mac) {
      return res.status(400).json({ error: 'Missing encrypted content fields' });
    }

    const user = await User.findOne({ userId: req.user.userId });
    if (!user) return res.status(404).json({ error: 'User not found.' });

    user.savedMessages.push({ content, label });
    await user.save();

    const saved = user.savedMessages[user.savedMessages.length - 1];
    res.status(201).json(saved);
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

router.delete('/saved-messages/:id', authenticate, async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.user.userId });
    if (!user) return res.status(404).json({ error: 'User not found.' });

    const msg = user.savedMessages.id(req.params.id);
    if (!msg) return res.status(404).json({ error: 'Message not found.' });

    msg.deleteOne();
    await user.save();
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── Reporting & Blocking ─────────────────────────────────────────────────────

router.post('/report', authenticate, async (req, res) => {
  try {
    const { messageId, reason } = req.body;
    const message = await require('../db/message').findMessageById(messageId);
    if (!message) return res.status(404).json({ error: 'Message not found.' });

    await Report.create({
      messageId,
      reason,
      reportedUserId: message.from,
      reportedBy: req.user.userId,
    });

    res.status(201).json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

router.post('/block', authenticate, async (req, res) => {
  try {
    const { blockedUserId } = req.body;
    await User.findOneAndUpdate(
      { userId: req.user.userId },
      { $addToSet: { blockedUsers: blockedUserId } }
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

router.post('/unblock', authenticate, async (req, res) => {
  try {
    const { blockedUserId } = req.body;
    await User.findOneAndUpdate(
      { userId: req.user.userId },
      { $pull: { blockedUsers: blockedUserId } }
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

router.get('/blocked', authenticate, async (req, res) => {
  try {
    const user = await User.findOne(
      { userId: req.user.userId },
      { blockedUsers: 1 }
    );
    res.json({ blockedUsers: user?.blockedUsers || [] });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

module.exports = router;

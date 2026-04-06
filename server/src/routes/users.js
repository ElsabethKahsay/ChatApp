const express = require("express");
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const authenticate = require('../middleware/auth');
const router = express.Router();
const User = require("../db/mongo");

// ── POST /api/register ──────────────────────────────────────────────────────
router.post("/register", async (req, res) => {
  const { userId, username, publicKey, password, bday } = req.body;

  // Validation rules
  if (!userId || !username || !publicKey || !password) {
    return res.status(400).json({
      error: "All fields are required: userId, username, publicKey, and password.",
    });
  }

  // Username validation
  if (username.length < 3 || username.length > 20) {
    return res.status(400).json({
      error: "Username must be between 3 and 20 characters.",
    });
  }
  if (!/^[a-zA-Z0-9_]+$/.test(username)) {
    return res.status(400).json({
      error: "Username can only contain letters, numbers, and underscores.",
    });
  }

  // Password validation
  if (password.length < 6) {
    return res.status(400).json({
      error: "Password must be at least 6 characters long.",
    });
  }

  try {
    // Check if username already exists (case-insensitive)
    const existingUser = await User.findOne({ 
      username: { $regex: new RegExp(`^${username}$`, 'i') } 
    });
    if (existingUser) {
      return res.status(409).json({ error: "Username already taken. Please choose another." });
    }

    const salt = await bcrypt.genSalt(12);
    const passwordHash = await bcrypt.hash(password, salt);

    const updateFields = {
      userId,
      username: username.toLowerCase().trim(),
      publicKey,
      passwordHash,
      lastSeen: new Date(),
    };

    if (bday) {
      const parsedBday = new Date(bday);
      if (!isNaN(parsedBday.getTime())) {
        updateFields.bday = parsedBday;
      }
    }

    const user = await User.findOneAndUpdate(
      { userId },
      updateFields,
      {
        upsert: true,
        new: true,
        setDefaultsOnInsert: true,
      }
    );

    res.status(201).json({
      success: true,
      message: "Account created successfully!",
      userId: user.userId,
      username: user.username,
    });
  } catch (err) {
    console.error("Register error:", err);
    res.status(500).json({ error: "Registration failed. Please try again later." });
  }
});

// ── POST /api/login ──────────────────────────────────────────────────────────
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  
  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }

  const jwtSecret = process.env.JWT_SECRET || 'dev-secret-please-change';

  try {
    const user = await User.findOne({ username });
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign({ userId: user.userId }, jwtSecret, { expiresIn: '7d' });

    // Update status to online on login
    await User.findOneAndUpdate({ userId: user.userId }, { status: true, lastSeen: new Date() });

    res.json({
      message: 'Login successful',
      token,
      userId: user.userId,
      username: user.username
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ── POST /api/auth (Socket.IO Token) ─────────────────────────────────────────
router.post('/auth', async (req, res) => {
  const { userId, password } = req.body;
  const jwtSecret = process.env.JWT_SECRET || 'dev-secret-please-change';

  if (!userId) {
    return res.status(400).json({ error: 'userId is required' });
  }

  try {
    const user = await User.findOne({ userId });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (password) {
      const match = await bcrypt.compare(password, user.passwordHash);
      if (!match) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }
    }

    const token = jwt.sign({ userId }, jwtSecret, { expiresIn: '2h' });
    await User.findOneAndUpdate({ userId }, { status: true, lastSeen: new Date() });
    res.json({ token, userId: user.userId, username: user.username });
  } catch (err) {
    console.error('Auth error:', err);
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── GET /api/public-key/:userId ─────────────────────────────────────────────
router.get("/public-key/:userId", authenticate, async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.params.userId });
    if (!user) return res.status(404).json({ error: "User not found." });

    res.json({ publicKey: user.publicKey, username: user.username });
  } catch (err) {
    console.error("Public-key fetch error:", err);
    res.status(500).json({ error: "Internal server error." });
  }
});

// ── GET /api/users ──────────────────────────────────────────────────────────
router.get("/users", authenticate, async (_req, res) => {
  try {
    const users = await User.find(
      {},
      { userId: 1, username: 1, lastSeen: 1, status: 1, bday: 1 }
    );
    res.json({ users });
  } catch (err) {
    console.error("List users error:", err);
    res.status(500).json({ error: "Internal server error." });
  }
});

// ── GET /api/users/search ───────────────────────────────────────────────────
router.get('/users/search', authenticate, async (req, res) => {
  try {
    const { q } = req.query;
    if (!q || typeof q !== 'string' || q.length < 2) {
      return res.status(400).json({ error: 'Query must be at least 2 characters' });
    }

    // Sanitize query - remove special characters
    const sanitized = q.replace(/[^a-zA-Z0-9\-_]/g, '').substring(0, 30);

    const users = await User.find(
      {
        username: { $regex: sanitized, $options: 'i' },
        userId: { $ne: req.user.userId }, // Exclude current user
      },
      { userId: 1, username: 1, lastSeen: 1, status: 1 }
    ).limit(20);

    res.json({ users });
  } catch (err) {
    console.error('Search users error:', err);
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── GET /api/online-users ────────────────────────────────────────────────────
router.get('/online-users', authenticate, async (_req, res) => {
  try {
    const users = await User.find({ status: true }, { userId: 1, username: 1 });
    res.json({ onlineUsers: users });
  } catch (err) {
    console.error('Online users error:', err);
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── GET /api/presence/:userId ────────────────────────────────────────────────
router.get('/presence/:userId', authenticate, async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.params.userId }, { userId: 1, username: 1, status: 1, lastSeen: 1 });
    if (!user) return res.status(404).json({ error: 'User not found.' });
    res.json({ user });
  } catch (err) {
    console.error('Presence error:', err);
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── PUT /api/status ──────────────────────────────────────────────────────────
router.put('/status', authenticate, async (req, res) => {
  try {
    const { status } = req.body;
    if (status === undefined || typeof status !== 'boolean') {
      return res.status(400).json({ error: 'status boolean required' });
    }

    const user = await User.findOneAndUpdate({ userId: req.user.userId }, { status, lastSeen: new Date() }, { new: true });
    if (!user) return res.status(404).json({ error: 'User not found.' });

    res.json({ success: true, status: user.status, lastSeen: user.lastSeen });
  } catch (err) {
    console.error('Update status error:', err);
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── POST /api/fcm-token ────────────────────────────────────────────────────
router.post('/fcm-token', authenticate, async (req, res) => {
  try {
    const { token } = req.body;
    if (!token || typeof token !== 'string') {
      return res.status(400).json({ error: 'FCM token is required' });
    }

    // Store FCM token for push notifications
    await User.findOneAndUpdate(
      { userId: req.user.userId },
      { fcmToken: token, fcmTokenUpdatedAt: new Date() },
      { new: true }
    );

    res.json({ success: true });
  } catch (err) {
    console.error('FCM token update error:', err);
    res.status(500).json({ error: 'Internal server error.' });
  }
});

module.exports = router;

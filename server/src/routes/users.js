const express = require("express");
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const authenticate = require('../middleware/auth');
const router = express.Router();
const User = require("../db/mongo"); // Ensure this exports a Mongoose model

// ── POST /api/register ──────────────────────────────────────────────────────
// Stores (or updates) a user's public key and optional birthday.
// `bday` is optional – only provided if the user chooses to share it.
router.post("/register", async (req, res) => {
  const { userId, username, publicKey, password, bday } = req.body;

  // All fields except bday are required
  if (!userId || !username || !publicKey || !password) {
    return res.status(400).json({
      error: "userId, username, publicKey, and password are required.",
    });
  }

  // Prepare update payload
  const updateFields = {
    userId,
    username,
    publicKey,
    lastSeen: new Date(),
  };

  // Hash the password in a secure way
  if (password) {
    const salt = await bcrypt.genSalt(12);
    updateFields.passwordHash = await bcrypt.hash(password, salt);
  }

  // If bday is provided, validate and add
  if (bday !== undefined && bday !== null && bday !== "") {
    const parsedBday = new Date(bday);
    if (isNaN(parsedBday.getTime())) {
      return res.status(400).json({
        error: "Invalid bday format. Use an ISO date string (e.g. 1998-06-15).",
      });
    }
    updateFields.bday = parsedBday;
  }

  try {
    const user = await User.findOneAndUpdate(
      { userId },
      updateFields,
      {
        upsert: true,
        new: true,
        setDefaultsOnInsert: true,
      }
    );

    res.json({
      success: true,
      userId: user.userId,
      username: user.username,
      bday: user.bday ?? null,
    });
  } catch (err) {
    console.error("Register error:", err);
    res.status(500).json({ error: "Internal server error." });
  }
});

// ── GET /api/public-key/:userId ─────────────────────────────────────────────
// Returns a peer's public key (and username) for ECDH key exchange.
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
// Returns a list of all registered users (for contact selection).
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

// ── POST /api/login ──────────────────────────────────────────────────────────
// Login with userId and password and issue a JWT for Socket.IO.
router.post('/login', async (req, res) => {
  const { userId, password } = req.body;
  const jwtSecret = process.env.JWT_SECRET || 'dev-secret-please-change';

  if (!userId || !password) {
    return res.status(400).json({ error: 'userId and password are required' });
  }

  try {
    const user = await User.findOne({ userId });
    if (!user || !user.passwordHash) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const match = await bcrypt.compare(password, user.passwordHash);
    if (!match) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign({ userId }, jwtSecret, { expiresIn: '2h' });
    await User.findOneAndUpdate({ userId }, { status: true, lastSeen: new Date() });
    res.json({ token, userId: user.userId, username: user.username });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── POST /api/auth ───────────────────────────────────────────────────────────
// Issue a short-lived JWT for Socket.IO authentication.
// Accepts either userId + password (fallback) or existing user token.
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

    // If caller presented a password, verify it (strong mode)
    if (password) {
      const match = await bcrypt.compare(password, user.passwordHash || '');
      if (!match) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }
    } else {
      // Legacy behavior: token by userId. Shy away in production.
      console.warn('Auth endpoint used without password (legacy fallback).');
    }

    const token = jwt.sign({ userId }, jwtSecret, { expiresIn: '2h' });
    await User.findOneAndUpdate({ userId }, { status: true, lastSeen: new Date() });
    res.json({ token, userId: user.userId, username: user.username });
  } catch (err) {
    console.error('Auth error:', err);
    res.status(500).json({ error: 'Internal server error.' });
  }
});

module.exports = router;
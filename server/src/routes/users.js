const express = require('express');
const router = express.Router();
const User = require('../db/mongo');

// ── POST /api/register ──────────────────────────────────────────────────────
// Flutter calls this on first launch (or when key pair changes).
// Stores (or updates) the user's public key for other clients to discover.
router.post('/register', async (req, res) => {
  const { userId, username, publicKey, bday} = req.body;

  if (!userId || !username || !publicKey || !bday) {
    return res.status(400).json({ error: 'userId, username, birthday and publicKey are all required.' });
  }

  try {
    const user = await User.findOneAndUpdate(
      { userId },
      { userId, username, publicKey, lastSeen: new Date() },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
    res.json({ success: true, userId: user.userId, username: user.username });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── GET /api/public-key/:userId ─────────────────────────────────────────────
// Flutter calls this to get a peer's public key before starting ECDH.
router.get('/public-key/:userId', async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.params.userId });
    if (!user) return res.status(404).json({ error: 'User not found.' });

    res.json({ publicKey: user.publicKey, username: user.username });
  } catch (err) {
    console.error('Public-key fetch error:', err);
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// ── GET /api/users ──────────────────────────────────────────────────────────
// List all registered users (for choosing who to chat with).
router.get('/users', async (_req, res) => {
  try {
    const users = await User.find({}, { userId: 1, username: 1, lastSeen: 1 });
    res.json({ users });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error.' });
  }
});

module.exports = router;

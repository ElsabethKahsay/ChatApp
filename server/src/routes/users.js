const express = require("express");
const router = express.Router();
const User = require("../db/mongo");

// ── POST /api/register ──────────────────────────────────────────────────────
// Flutter calls this on first launch (or when key pair changes).
// Stores (or updates) the user's public key for other clients to discover.
// Birthday is optional, and will be persisted when provided.
router.post("/register", async (req, res) => {
  const { userId, username, publicKey, bday } = req.body;

  if (!userId || !username || !publicKey) {
    return res.status(400).json({
      error: "userId, username, and publicKey are required.",
    });
  }

  // Build update payload dynamically so optional fields are only set if provided.
  const update = {
    userId,
    username,
    publicKey,
    lastSeen: new Date(),
  };

  if (bday !== undefined && bday !== null && bday !== "") {
    const parsedBday = new Date(bday);
    if (Number.isNaN(parsedBday.getTime())) {
      return res.status(400).json({
        error: "Invalid bday format. Use an ISO date string (e.g. 1998-06-15).",
      });
    }
    update.bday = parsedBday;
  }

  try {
    const user = await User.findOneAndUpdate({ userId }, update, {
      upsert: true,
      new: true,
      setDefaultsOnInsert: true,
    });

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
// Flutter calls this to get a peer's public key before starting ECDH.
router.get("/public-key/:userId", async (req, res) => {
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
// List all registered users (for choosing who to chat with).
router.get("/users", async (_req, res) => {
  try {
    const users = await User.find({}, { userId: 1, username: 1, lastSeen: 1 });
    res.json({ users });
  } catch (err) {
    res.status(500).json({ error: "Internal server error." });
  }
});

module.exports = router;

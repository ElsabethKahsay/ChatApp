const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const SavedMessage = require('../SavedMessage');

// Save a new message
router.post('/saved-messages', auth, async (req, res) => {
  try {
    const saved = new SavedMessage({
      userId: req.user.userId,
      content: req.body.content, // Expects { ciphertext, nonce }
      label: req.body.label
    });
    await saved.save();
    res.status(201).json(saved);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Retrieve all saved messages for the user
router.get('/saved-messages', auth, async (req, res) => {
  try {
    const messages = await SavedMessage.find({ userId: req.user.userId })
      .sort({ createdAt: -1 });
    res.json(messages);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Group = require('../Group');

// Create a new group with wrapped keys for members
router.post('/groups', auth, async (req, res) => {
  try {
    const { name, members, encryptedKeys } = req.body;
    const group = new Group({
      name,
      creator: req.user.userId,
      members: [...members, req.user.userId],
      encryptedKeys
    });
    await group.save();
    res.status(201).json(group);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get all groups the user is a member of
router.get('/groups', auth, async (req, res) => {
  try {
    const groups = await Group.find({ members: req.user.userId });
    res.json(groups);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
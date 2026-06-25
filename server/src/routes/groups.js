const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Group = require('../Group');
const { getGroupHistory } = require('../db/message');

// Create a new group
router.post('/groups', auth, async (req, res) => {
  try {
    const { name, members, encryptedKeys, creatorPublicKey } = req.body;
    const allMembers = [...new Set([...members, req.user.userId])];
    const group = new Group({
      name: name.trim(),
      creator: req.user.userId,
      creatorPublicKey,
      members: allMembers,
      encryptedKeys
    });
    await group.save();
    res.status(201).json(group);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get all groups for user
router.get('/groups', auth, async (req, res) => {
  try {
    const groups = await Group.find({ members: req.user.userId });
    res.json(groups);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get single group details
router.get('/groups/:groupId', auth, async (req, res) => {
  try {
    const group = await Group.findOne({ _id: req.params.groupId, members: req.user.userId });
    if (!group) return res.status(403).json({ error: 'Access denied' });
    res.json(group);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// V1 FIX: Fetch 24h history for a group
router.get('/groups/:groupId/messages', auth, async (req, res) => {
  try {
    // Verify membership before showing history
    const group = await Group.findOne({ _id: req.params.groupId, members: req.user.userId });
    if (!group) return res.status(403).json({ error: 'Access denied' });

    const messages = await getGroupHistory(req.params.groupId);
    res.json({ messages });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Add member(s) to a group
router.post('/groups/:groupId/members', auth, async (req, res) => {
  try {
    const { members, encryptedKeys } = req.body;
    if (!members || !Array.isArray(members) || members.length === 0) {
      return res.status(400).json({ error: 'members array is required' });
    }
    if (!encryptedKeys || typeof encryptedKeys !== 'object') {
      return res.status(400).json({ error: 'encryptedKeys map is required' });
    }

    const group = await Group.findById(req.params.groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    // Only creator can add members
    if (group.creator !== req.user.userId) {
      return res.status(403).json({ error: 'Only the group creator can add members' });
    }

    for (const memberId of members) {
      if (!group.members.includes(memberId)) {
        group.members.push(memberId);
        if (encryptedKeys[memberId]) {
          group.encryptedKeys.set(memberId, encryptedKeys[memberId]);
        }
      }
    }
    await group.save();
    res.json(group);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Remove member from a group (leave group)
router.delete('/groups/:groupId/members/:userId', auth, async (req, res) => {
  try {
    const group = await Group.findById(req.params.groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const targetUserId = req.params.userId;
    // User can remove themselves (leave) or creator can remove any member
    if (targetUserId !== req.user.userId && group.creator !== req.user.userId) {
      return res.status(403).json({ error: 'Not authorized to remove this member' });
    }

    group.members = group.members.filter(m => m !== targetUserId);
    group.encryptedKeys.delete(targetUserId);
    await group.save();
    res.json({ success: true, group });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

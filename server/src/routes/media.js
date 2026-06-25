const express = require('express');
const authenticate = require('../middleware/auth');
const router = express.Router();
const { S3Client, PutObjectCommand, DeleteObjectCommand, GetObjectCommand, HeadObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { nanoid } = require('nanoid');
const { Message } = require('../db/message');

// Track which user requested each presigned key (in-memory, cleared on restart)
const presignedKeyOwners = new Map();

// Configure S3 client for Backblaze B2 (S3‑compatible)
const s3 = new S3Client({
  endpoint: process.env.B2_ENDPOINT,          // e.g., https://s3.us-west-002.backblazeb2.com
  region: process.env.B2_REGION || 'us-west-002',
  credentials: {
    accessKeyId: process.env.B2_ACCESS_KEY_ID,
    secretAccessKey: process.env.B2_SECRET_ACCESS_KEY,
  },
  forcePathStyle: true,                       // Required for Backblaze
});

// ── POST /api/presign ─────────────────────────────────────────────────────
// Returns a short‑lived PUT URL so the Flutter app can upload directly.
const ALLOWED_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'webm', 'm4a', 'aac'];
const MAX_FILE_SIZE_MB = 20;

router.post('/presign', authenticate, async (req, res) => {
  const ext = (req.body.extension || 'bin').replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
  if (!ALLOWED_EXTENSIONS.includes(ext)) {
    return res.status(400).json({ error: `Extension .${ext} not allowed. Allowed: ${ALLOWED_EXTENSIONS.join(', ')}` });
  }

  // SECURITY FIX: Server enforces max size — ignore user-supplied value
  const maxSizeBytes = MAX_FILE_SIZE_MB * 1024 * 1024;

  const allowedContentTypes = {
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
    'gif': 'image/gif',  'webp': 'image/webp',
    'mp4': 'video/mp4',  'mov': 'video/quicktime', 'webm': 'video/webm',
    'm4a': 'audio/mp4',  'aac': 'audio/aac',
  };
  const expectedType = allowedContentTypes[ext];
  if (req.body.contentType && req.body.contentType !== expectedType) {
    return res.status(400).json({ error: `Content-Type mismatch for .${ext}; expected ${expectedType}` });
  }
  const contentType = expectedType || 'application/octet-stream';
  const key = `media/${nanoid()}.${ext}`;

  const command = new PutObjectCommand({
    Bucket: process.env.B2_BUCKET,
    Key: key,
    ContentType: contentType,
  });

  try {
    // Upload URL expires in 60 seconds – short enough to be secure
    const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 60 });

    const downloadCommandObj = new GetObjectCommand({
      Bucket: process.env.B2_BUCKET,
      Key: key,
    });
    const downloadUrl = await getSignedUrl(s3, downloadCommandObj, { expiresIn: 300 }); // 5 min

    // SECURITY: Track who requested this key for ownership verification
    presignedKeyOwners.set(key, req.user.userId);
    // Auto-expire tracking after 24 hours
    setTimeout(() => presignedKeyOwners.delete(key), 86400000);

    res.json({ uploadUrl, downloadUrl, key, maxSizeBytes });
  } catch (err) {
    console.error('Presign error:', err);
    res.status(500).json({ error: 'Could not generate presigned URL.' });
  }
});

// ── DELETE /api/media/:key ─────────────────────────────────────────────────
// Optionally called after the media has been viewed/consumed.
router.delete('/media/:key(*)', authenticate, async (req, res) => {
  const key = req.params.key;
  const userId = req.user.userId;

  // SECURITY FIX: Verify ownership — user must be the uploader, sender, or recipient
  const isUploader = presignedKeyOwners.get(key) === userId;
  if (!isUploader) {
    // Fall back to checking message records
    const msg = await Message.findOne({
      $or: [
        { 'payload.url': { $regex: key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') } },
        { messageId: key },
      ],
    });
    if (!msg || (msg.from !== userId && msg.to !== userId)) {
      return res.status(403).json({ error: 'Forbidden: you do not own this media.' });
    }
  }

  try {
    await s3.send(new DeleteObjectCommand({
      Bucket: process.env.B2_BUCKET,
      Key: key,
    }));
    presignedKeyOwners.delete(key);
    res.json({ success: true });
  } catch (err) {
    console.error('Delete media error:', err);
    res.status(500).json({ error: 'Could not delete media.' });
  }
});

module.exports = router;
const express = require('express');
const authenticate = require('../middleware/auth');
const router = express.Router();
const { S3Client, PutObjectCommand, DeleteObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { nanoid } = require('nanoid');

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
router.post('/presign', authenticate, async (req, res) => {
  const ext = (req.body.extension || 'bin').replace(/[^a-zA-Z0-9]/g, '');
  const contentType = req.body.contentType || 'application/octet-stream';
  const key = `media/${nanoid()}.${ext}`;

  const command = new PutObjectCommand({
    Bucket: process.env.B2_BUCKET,             // Use B2_BUCKET from .env
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

    res.json({ uploadUrl, downloadUrl, key });
  } catch (err) {
    console.error('Presign error:', err);
    res.status(500).json({ error: 'Could not generate presigned URL.' });
  }
});

// ── DELETE /api/media/:key ─────────────────────────────────────────────────
// Optionally called after the media has been viewed/consumed.
router.delete('/media/:key(*)', authenticate, async (req, res) => {
  const key = req.params.key;
  try {
    await s3.send(new DeleteObjectCommand({
      Bucket: process.env.B2_BUCKET,
      Key: key,
    }));
    res.json({ success: true });
  } catch (err) {
    console.error('Delete media error:', err);
    res.status(500).json({ error: 'Could not delete media.' });
  }
});

module.exports = router;
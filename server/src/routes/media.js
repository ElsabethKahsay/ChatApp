const express = require('express');
const router = express.Router();
const { S3Client, PutObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { nanoid } = require('nanoid');

// Cloudflare R2 is S3-compatible. Use the account-specific endpoint.
const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
  },
});

// ── POST /api/presign ─────────────────────────────────────────────────────
// Returns a short-lived (5-min) PUT URL so the Flutter app can
// upload an encrypted blob directly to R2 without going through the server.
//
// Body: { extension: 'jpg' | 'mp4' | 'bin', contentType: 'image/jpeg' | ... }
router.post('/presign', async (req, res) => {
  const ext = (req.body.extension || 'bin').replace(/[^a-zA-Z0-9]/g, '');
  const contentType = req.body.contentType || 'application/octet-stream';
  const key = `media/${nanoid()}.${ext}`;

  const command = new PutObjectCommand({
    Bucket: process.env.R2_BUCKET_NAME,
    Key: key,
    ContentType: contentType,
  });

  try {
    // Upload URL expires in 1440 minutes
    const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 864000 });
    // Download URL is the public R2 URL (set your bucket to public or use a Worker)
    const downloadUrl = `${process.env.R2_PUBLIC_URL}/${key}`;

    res.json({ uploadUrl, downloadUrl, key });
  } catch (err) {
    console.error('Presign error:', err);
    res.status(500).json({ error: 'Could not generate presigned URL.' });
  }
});

// ── DELETE /api/media/:key ─────────────────────────────────────────────────
// Optionally called when a recipient has viewed (=saved or discarded) media.
// This enables "view once" — server deletes the file immediately.
router.delete('/media/:key(*)', async (req, res) => {
  const key = req.params.key;
  try {
    await s3.send(new DeleteObjectCommand({
      Bucket: process.env.R2_BUCKET_NAME,
      Key: key,
    }));
    res.json({ success: true });
  } catch (err) {
    console.error('Delete media error:', err);
    res.status(500).json({ error: 'Could not delete media.' });
  }
});

module.exports = router;

const cron = require('node-cron');
const { Message } = require('../db/message');
const { S3Client, DeleteObjectCommand } = require('@aws-sdk/client-s3');

// Configure S3 client (Backblaze B2)
let s3;
if (process.env.B2_ACCESS_KEY_ID) {
  s3 = new S3Client({
    endpoint: process.env.B2_ENDPOINT,
    region: process.env.B2_REGION || 'us-west-002',
    credentials: {
      accessKeyId: process.env.B2_ACCESS_KEY_ID,
      secretAccessKey: process.env.B2_SECRET_ACCESS_KEY,
    },
    forcePathStyle: true,
  });
}

const cleanupExpiredContent = async () => {
  try {
    const now = new Date();
    // HISTORY FIX: Only find messages where the 24h+ window has actually passed
    const expired = await Message.find({ deleteAt: { $lt: now } });
    
    if (expired.length === 0) return;
    
    console.log(`🧹 Sweeping ${expired.length} expired items from history...`);
    
    for (const msg of expired) {
      // 1. Delete associated media from S3 if it exists
      if (s3 && msg.payload && msg.payload.key) {
        try {
          await s3.send(new DeleteObjectCommand({
            Bucket: process.env.B2_BUCKET,
            Key: msg.payload.key,
          }));
        } catch (err) {
          console.error(`Failed to delete B2 object ${msg.payload.key}:`, err.message);
        }
      }
      // 2. Remove the message from MongoDB
      await Message.findByIdAndDelete(msg._id);
    }
    console.log('✅ History cleanup complete.');
  } catch (err) {
    console.error('🧹 Cleanup error:', err.message);
  }
};

const startMediaCleanupCron = () => {
  // Runs every 15 minutes to check for messages past their 24h mark
  cron.schedule('*/15 * * * *', cleanupExpiredContent);
  console.log('🔄 24h History Cleanup Task Scheduled');
};

module.exports = { startMediaCleanupCron, cleanupExpiredContent };

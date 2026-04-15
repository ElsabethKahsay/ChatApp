require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const mongoose = require('mongoose');
const cors = require('cors');
const bodyParser = require('body-parser');
const redis = require('redis');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const app = express();
const server = http.createServer(app);

// Allow any origin for development to simplify Android connectivity
const CORS_ORIGINS = process.env.CORS_ORIGIN 
  ? process.env.CORS_ORIGIN.split(',') 
  : ['http://localhost:8080', 'http://127.0.0.1:8080', 'http://localhost:3000', 'http://127.0.0.1:3000', 'http://127.0.0.1:50153'];

const corsOptions = {
  origin: function (origin, callback) {
    // Allow all origins in development
    if (!origin) return callback(null, true);
    callback(null, true);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
};
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-please-change';

const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' },
});

// ── Socket.IO ──────────────────────────────────────────────────────────────
const io = new Server(server, {
  cors: {
    origin: "*", // More permissive for development sockets
    methods: ["GET", "POST"],
    credentials: true
  },
  pingTimeout: 60000,
});

// ── Middleware ─────────────────────────────────────────────────────────────
app.use(helmet());
app.use(morgan('dev'));
app.use(cors(corsOptions));
app.use(apiLimiter);
app.use(express.json());

// expose JWT secret for socket auth module
app.locals.JWT_SECRET = JWT_SECRET;

// ── Health check ───────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// ── REST Routes ────────────────────────────────────────────────────────────
app.use('/api', require('./routes/users'));
app.use('/api', require('./routes/media'));
app.use('/api', require('./routes/saved_messages'));
app.use('/api', require('./routes/groups'));

// ── Socket relay ───────────────────────────────────────────────────────────
require('./socket')(io, JWT_SECRET);

// ── MongoDB ────────────────────────────────────────────────────────────────
mongoose
  .connect(process.env.MONGO_URI || 'mongodb://localhost:27017/securechat')
  .then(() => console.log('MongoDB connected'))
  .catch(err => console.error('MongoDB connection error:', err));

// Redis Connection
if (process.env.REDIS_URL) {
    const redisClient = redis.createClient({ url: process.env.REDIS_URL });
    redisClient.on('error', (err) => console.error('Redis connection error:', err));
    redisClient.connect().then(() => console.log('Redis connected'));
} else {
    console.warn('REDIS_URL not set, skipping redis connection in index.js');
}

// ── Start server ───────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;

server.listen(PORT, '0.0.0.0', () => {
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║           SecureChat Server Started                       ║');
  console.log('╠═══════════════════════════════════════════════════════════╣');
  console.log(`║  Server URL: http://0.0.0.0:${PORT}                        ║`);
  console.log(`║  Health check: http://<your-ip>:${PORT}/health             ║`);
  console.log('║                                                           ║');
  console.log('║  Testing from Mac:                                        ║');
  console.log(`║    curl http://127.0.0.1:${PORT}/health                    ║`);
  console.log('║                                                           ║');
  console.log('║  Testing from Android device:                             ║');
  console.log('║    1. Find your Mac IP: ipconfig getifaddr en0            ║');
  console.log(`║    2. Update Constants.serverUrl in Flutter app           ║`);
  console.log(`║    3. curl http://<mac-ip>:${PORT}/health                  ║`);
  console.log('╚═══════════════════════════════════════════════════════════╝');

  // Warn if using default JWT secret
  if (JWT_SECRET === 'dev-secret-please-change') {
    console.warn('\n⚠️  WARNING: Using default JWT_SECRET!');
    console.warn('   Set JWT_SECRET in .env file for production!\n');
  }

  // Display MongoDB status
  if (mongoose.connection.readyState === 1) {
    console.log('✅ MongoDB connected');
  } else {
    console.warn('⏳ MongoDB connecting...');
  }
});

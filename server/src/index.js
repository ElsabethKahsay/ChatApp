require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

// V1 REQUIREMENT: Fail-fast on missing environment variables
const REQUIRED_ENV = ['JWT_SECRET', 'MONGO_URI'];
for (const env of REQUIRED_ENV) {
  if (!process.env[env]) {
    console.error(`❌ FATAL: Environment variable ${env} is missing.`);
    process.exit(1);
  }
}

const app = express();
const server = http.createServer(app);

const CORS_ORIGINS = process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',') : ['*'];

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Too many requests. Please try again later.' },
});

// ── Socket.IO ──────────────────────────────────────────────────────────────
const io = new Server(server, {
  cors: {
    origin: CORS_ORIGINS.includes('*') ? '*' : CORS_ORIGINS,
    methods: ['GET', 'POST'],
    credentials: !CORS_ORIGINS.includes('*'),
  },
  pingTimeout: 60000,
});

// ── Middleware ─────────────────────────────────────────────────────────────
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(morgan('combined')); // Production-grade logging
app.use(cors({
  origin: CORS_ORIGINS.includes('*') ? '*' : CORS_ORIGINS,
  credentials: !CORS_ORIGINS.includes('*'),
}));
app.use('/api/', apiLimiter);
app.use(express.json());

app.locals.JWT_SECRET = process.env.JWT_SECRET;

// ── Routes ─────────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok', version: '1.0.0' }));
app.use('/api', require('./routes/users'));
app.use('/api', require('./routes/media'));
app.use('/api', require('./routes/groups'));

require('./socket')(io, process.env.JWT_SECRET);

// ── MongoDB ────────────────────────────────────────────────────────────────
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log('✅ Connected to Production MongoDB Instance'))
  .catch(err => {
    console.error('❌ MongoDB Connection Error:', err.message);
    process.exit(1);
  });

// ── Start ──────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 SecureChat Server V1 Live on Port ${PORT}`);
});

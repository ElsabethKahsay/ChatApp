require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const mongoose = require('mongoose');
const cors = require('cors');
const morgan = require('morgan');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const app = express();
const server = http.createServer(app);

const CORS_ORIGINS = process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : ['http://localhost:3000', 'http://10.0.2.2:3000'];
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
    origin: (origin, callback) => {
      if (!origin || CORS_ORIGINS.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('CORS policy violation'));
      }
    },
    methods: ['GET', 'POST'],
    credentials: true,
  },
  pingTimeout: 60000,
});

// ── Middleware ─────────────────────────────────────────────────────────────
app.use(helmet());
app.use(morgan('combined'));
app.use(cors({ origin: CORS_ORIGINS, credentials: true }));
app.use(apiLimiter);
app.use(express.json());

// expose JWT secret for socket auth module
app.locals.JWT_SECRET = JWT_SECRET;

// ── Health check ───────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// ── REST Routes ────────────────────────────────────────────────────────────
app.use('/api', require('./routes/users'));
app.use('/api', require('./routes/media'));

// ── Socket relay ───────────────────────────────────────────────────────────
require('./socket')(io, JWT_SECRET);

// ── MongoDB ────────────────────────────────────────────────────────────────
mongoose
  .connect(process.env.MONGO_URI)
  .then(() => console.log(' MongoDB connected'))
  .catch((err) => console.error(' MongoDB error:', err));

// ── Start server ───────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`  Server running on port ${PORT}`));

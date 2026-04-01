const jwt = require('jsonwebtoken');
const User = require('../db/mongo');

const authenticate = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authorization header missing or malformed. Use Bearer token.' });
  }

  const token = authHeader.substring('Bearer '.length);
  const jwtSecret = process.env.JWT_SECRET || 'dev-secret-please-change';

  try {
    const decoded = jwt.verify(token, jwtSecret);

    if (!decoded || typeof decoded !== 'object' || !decoded.userId) {
      return res.status(401).json({ error: 'Invalid auth token.' });
    }

    const user = await User.findOne({ userId: decoded.userId });
    if (!user) {
      return res.status(401).json({ error: 'User not found.' });
    }

    req.user = user;
    next();
  } catch (err) {
    console.error('Auth middleware error:', err.message || err);
    return res.status(401).json({ error: 'Invalid or expired token.' });
  }
};

module.exports = authenticate;

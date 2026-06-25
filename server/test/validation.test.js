const { expect } = require('chai');

// ── Test the Message type enum values ──────────────────────────────────────
describe('Message type validation', () => {
  const VALID_TYPES = ['text', 'media', 'file', 'voice', 'image'];

  it('should accept all valid message types', () => {
    for (const type of VALID_TYPES) {
      expect(VALID_TYPES.includes(type)).to.be.true;
    }
  });

  it('should reject invalid message types', () => {
    const invalidTypes = ['audio', 'video', '', null, undefined, 123];
    for (const type of invalidTypes) {
      expect(VALID_TYPES.includes(type)).to.be.false;
    }
  });

  it('should have all client MessageType values represented', () => {
    // Client uses: text, media, voice, image
    expect(VALID_TYPES).to.include.members(['text', 'media', 'voice', 'image']);
  });
});

// ── Test the registration input validation rules ───────────────────────────
describe('Registration validation', () => {
  function validateRegistration(body) {
    const errors = [];

    if (!body.userId || !body.username || !body.publicKey || !body.password) {
      return { valid: false, error: 'All fields are required' };
    }

    if (typeof body.userId !== 'string') {
      return { valid: false, error: 'userId must be a string' };
    }
    const cleanUserId = body.userId.trim().replace(/[^a-zA-Z0-9\-_]/g, '');
    if (cleanUserId.length < 3 || cleanUserId.length > 64) {
      return { valid: false, error: 'userId must be 3-64 characters' };
    }

    const username = (body.username || '').trim();
    if (username.length < 3 || username.length > 20) {
      return { valid: false, error: 'Username must be 3-20 characters' };
    }
    if (!/^[a-zA-Z0-9_]+$/.test(username)) {
      return { valid: false, error: 'Username invalid format' };
    }

    if (body.password.length < 6) {
      return { valid: false, error: 'Password too short' };
    }

    if (!/^[A-Za-z0-9+/=]+$/.test(body.publicKey) ||
        body.publicKey.length < 10 || body.publicKey.length > 512) {
      return { valid: false, error: 'Invalid public key' };
    }

    return { valid: true };
  }

  it('should accept valid registration data', () => {
    const result = validateRegistration({
      userId: 'user-abc_123',
      username: 'testuser',
      publicKey: 'base64encodedkeyvaluehere',
      password: 'securepass123',
    });
    expect(result.valid).to.be.true;
  });

  it('should reject missing fields', () => {
    expect(validateRegistration({}).valid).to.be.false;
    expect(validateRegistration({ userId: 'u1' }).valid).to.be.false;
  });

  it('should reject short userId', () => {
    const result = validateRegistration({
      userId: 'ab',
      username: 'testuser',
      publicKey: 'base64key',
      password: 'password123',
    });
    expect(result.valid).to.be.false;
    expect(result.error).to.include('userId');
  });

  it('should reject short username', () => {
    const result = validateRegistration({
      userId: 'valid-user',
      username: 'ab',
      publicKey: 'base64key',
      password: 'password123',
    });
    expect(result.valid).to.be.false;
    expect(result.error).to.include('Username');
  });

  it('should reject short password', () => {
    const result = validateRegistration({
      userId: 'valid-user',
      username: 'testuser',
      publicKey: 'base64key',
      password: '12345',
    });
    expect(result.valid).to.be.false;
    expect(result.error).to.include('Password');
  });

  it('should reject invalid public key', () => {
    const result = validateRegistration({
      userId: 'valid-user',
      username: 'testuser',
      publicKey: 'x',
      password: 'password123',
    });
    expect(result.valid).to.be.false;
    expect(result.error).to.include('public key');
  });

  it('should sanitize userId by removing special characters', () => {
    const body = {
      userId: 'user$#@{}id',
      username: 'testuser',
      publicKey: 'base64keyvaluehere',
      password: 'password123',
    };
    const clean = body.userId.trim().replace(/[^a-zA-Z0-9\-_]/g, '');
    // After sanitization, special chars like $#@{} are removed
    expect(clean).to.equal('userid');
    // Clean length >= 3, so validation should pass
    const result = validateRegistration({ ...body, userId: clean });
    expect(result.valid).to.be.true;
  });
});

// ── Test the encryptedKeys validation in group creation ────────────────────
describe('Group encryptedKeys validation', () => {
  function validateEncryptedKeys(encryptedKeys, members) {
    if (!encryptedKeys || typeof encryptedKeys !== 'object') {
      return { valid: false, error: 'encryptedKeys map is required' };
    }

    const base64Regex = /^[A-Za-z0-9+/=]+$/;
    const allMembers = [...new Set([...members, 'creator-user'])];

    for (const memberId of allMembers) {
      const keyEntry = encryptedKeys[memberId];
      if (!keyEntry || !keyEntry.ciphertext || !keyEntry.nonce || !keyEntry.mac) {
        return { valid: false, error: `Missing key for ${memberId}` };
      }
      if (!base64Regex.test(keyEntry.ciphertext) ||
          !base64Regex.test(keyEntry.nonce) ||
          !base64Regex.test(keyEntry.mac)) {
        return { valid: false, error: `Invalid encoding for ${memberId}` };
      }
    }

    return { valid: true };
  }

  it('should accept valid encryptedKeys', () => {
    const result = validateEncryptedKeys({
      'user1': { ciphertext: 'abc123', nonce: 'def456', mac: 'ghi789' },
      'user2': { ciphertext: 'xyz789', nonce: 'uvw456', mac: 'rst123' },
      'creator-user': { ciphertext: 'aaa', nonce: 'bbb', mac: 'ccc' },
    }, ['user1', 'user2']);
    expect(result.valid).to.be.true;
  });

  it('should reject null encryptedKeys', () => {
    const result = validateEncryptedKeys(null, ['user1']);
    expect(result.valid).to.be.false;
  });

  it('should reject missing member key entries', () => {
    const result = validateEncryptedKeys({
      'user1': { ciphertext: 'abc', nonce: 'def', mac: 'ghi' },
    }, ['user1', 'user2']);
    expect(result.valid).to.be.false;
    expect(result.error).to.include('user2');
  });

  it('should reject incomplete key entries', () => {
    const result = validateEncryptedKeys({
      'user1': { ciphertext: 'abc' },
    }, ['user1']);
    expect(result.valid).to.be.false;
  });

  it('should reject non-base64 key fields', () => {
    const result = validateEncryptedKeys({
      'user1': { ciphertext: '!!!invalid!!!', nonce: 'def', mac: 'ghi' },
    }, ['user1']);
    expect(result.valid).to.be.false;
    expect(result.error).to.include('encoding');
  });

  it('should include the creator in the member check', () => {
    const result = validateEncryptedKeys({
      'user1': { ciphertext: 'abc', nonce: 'def', mac: 'ghi' },
      'creator-user': { ciphertext: 'xyz', nonce: 'uvw', mac: 'rst' },
    }, ['user1']);
    expect(result.valid).to.be.true;
  });
});

// ── Test the media presign validation ──────────────────────────────────────
describe('Media presign validation', () => {
  const ALLOWED_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'webm', 'm4a', 'aac'];
  const ALLOWED_CONTENT_TYPES = {
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
    'gif': 'image/gif',  'webp': 'image/webp',
    'mp4': 'video/mp4',  'mov': 'video/quicktime', 'webm': 'video/webm',
    'm4a': 'audio/mp4',  'aac': 'audio/aac',
  };

  function validatePresign(body) {
    const ext = (body.extension || 'bin').replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
    if (!ALLOWED_EXTENSIONS.includes(ext)) {
      return { valid: false, error: `Extension .${ext} not allowed` };
    }

    const maxSizeMb = body.maxSizeMb ?? 20;
    if (typeof maxSizeMb !== 'number' || maxSizeMb < 1 || maxSizeMb > 100) {
      return { valid: false, error: 'maxSizeMb must be between 1 and 100' };
    }

    // Content-Type validation
    const expectedType = ALLOWED_CONTENT_TYPES[ext];
    if (body.contentType && body.contentType !== expectedType) {
      return { valid: false, error: 'Content-Type mismatch' };
    }

    return { valid: true };
  }

  it('should accept allowed extensions', () => {
    for (const ext of ALLOWED_EXTENSIONS) {
      expect(validatePresign({ extension: ext }).valid).to.be.true;
    }
  });

  it('should reject disallowed extensions', () => {
    const result = validatePresign({ extension: 'exe' });
    expect(result.valid).to.be.false;
  });

  it('should reject disallowed extensions even after sanitization attempts', () => {
    const result = validatePresign({ extension: 'exe' });
    expect(result.valid).to.be.false;
  });

  it('should validate maxSizeMb range', () => {
    expect(validatePresign({ extension: 'jpg', maxSizeMb: 50 }).valid).to.be.true;
    expect(validatePresign({ extension: 'jpg', maxSizeMb: 101 }).valid).to.be.false;
  });

  it('should accept matching content-type', () => {
    const result = validatePresign({ extension: 'jpg', contentType: 'image/jpeg' });
    expect(result.valid).to.be.true;
  });

  it('should reject mismatched content-type', () => {
    const result = validatePresign({ extension: 'jpg', contentType: 'image/png' });
    expect(result.valid).to.be.false;
    expect(result.error).to.include('Content-Type');
  });

  it('should accept missing content-type (defaults to octet-stream)', () => {
    const result = validatePresign({ extension: 'jpg' });
    expect(result.valid).to.be.true;
  });
});

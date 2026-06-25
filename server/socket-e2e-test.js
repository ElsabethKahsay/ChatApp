const axios = require('axios');
const { io } = require('socket.io-client');

async function run() {
  try {
    const tokenA = (await axios.post('http://localhost:3000/api/auth', { userId: 'alice' })).data.token;
    const tokenB = (await axios.post('http://localhost:3000/api/auth', { userId: 'bob' })).data.token;

    const onlineUsers = (await axios.get('http://localhost:3000/api/online-users', { headers: { Authorization: `Bearer ${tokenA}` } })).data.onlineUsers;
    console.log('onlineUsers initially', onlineUsers.map(u => u.userId));

    const presenceBob = (await axios.get('http://localhost:3000/api/presence/bob', { headers: { Authorization: `Bearer ${tokenA}` } })).data;
    console.log('presence Bob:', presenceBob);

    const clientA = io('http://localhost:3000', { auth: { token: tokenA }, transports: ['websocket'] });
    const clientB = io('http://localhost:3000', { auth: { token: tokenB }, transports: ['websocket'] });

    clientA.on('connect', () => console.log('A connected', clientA.id));
    clientB.on('connect', () => console.log('B connected', clientB.id));

    clientA.on('registered', d => console.log('A registered', d));
    clientB.on('registered', d => console.log('B registered', d));

    clientB.on('receive_message', d => {
      console.log('B got message', d);
      clientB.emit('message_ack', { to: 'alice', messageId: d.messageId });
    });

    clientA.on('message_ack', d => {
      console.log('A got ack', d);
      clientA.disconnect();
      clientB.disconnect();
      process.exit(0);
    });

    clientA.on('connect_error', err => { console.error('A connect_error', err.message); process.exit(1); });
    clientB.on('connect_error', err => { console.error('B connect_error', err.message); process.exit(1); });

    setTimeout(() => {
      clientA.emit('send_message', { to: 'bob', payload: { ciphertext: 'abc', nonce: '123', mac: 'xyz' }, messageId: 'msg1' });
    }, 500);
  } catch (err) {
    console.error('Test harness failed', err.message || err);
    process.exit(1);
  }
}

run();

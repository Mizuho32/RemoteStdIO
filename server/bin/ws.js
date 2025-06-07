// client.js
const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:8000/websocket/back');

ws.on('open', () => {
  console.log('Connected to server');
  ws.send('lD714');
});

ws.on('message', (data) => {
	const text = data.toString('utf-8')
  console.log('Received:',  text);
	if (text.includes('close'))
		ws.close()
});

ws.on('close', () => {
  console.log('Disconnected from server');
});

ws.on('error', (err) => {
  console.error('WebSocket error:', err);
});

// Live "people playing right now" counter for harmonium.lol.
// Each page load opens a WebSocket; everyone gets the connection count,
// re-broadcast on every join/leave and on a heartbeat sweep.
const { WebSocketServer } = require('ws');

const port = process.env.PORT || 8080;
const wss = new WebSocketServer({ port });

const count = () => [...wss.clients].filter(c => c.readyState === 1).length;
const broadcast = () => {
  const msg = JSON.stringify({ online: count() });
  for (const c of wss.clients) if (c.readyState === 1) c.send(msg);
};

wss.on('connection', ws => {
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });
  ws.on('close', broadcast);
  ws.on('error', () => {});
  broadcast();
});

// Drop dead connections (sleeping laptops, closed tabs that never sent FIN)
setInterval(() => {
  for (const c of wss.clients) {
    if (!c.isAlive) { c.terminate(); continue; }
    c.isAlive = false;
    c.ping();
  }
  broadcast();
}, 25000);

console.log('presence counter listening on', port);

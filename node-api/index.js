const http = require('http');

const server = http.createServer((_req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ message: 'Node API running' }));
});

if (require.main === module) {
  server.listen(3000, () => console.log('Node API running on http://localhost:3000'));
}

module.exports = server;

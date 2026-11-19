const http = require('http');
const { Client } = require('pg');
let message = 'Waiting for database';
let ready = false;
const host = process.env.DB_HOST;
async function readDatabase() {
  const client = new Client({
    host, port: 5432, database: process.env.DB_NAME || 'training',
    user: process.env.DB_USER, password: process.env.DB_PASSWORD,
    ssl: { rejectUnauthorized: false }, // lab only; use trusted RDS CA in production
    connectionTimeoutMillis: 5000, query_timeout: 5000,
  });
  try {
    await client.connect();
    const result = await client.query('SELECT message FROM training_messages WHERE id=1');
    if (!result.rows.length) throw new Error('Sample row not yet available');
    message = result.rows[0].message;
    ready = true;
    console.log('[DB] Node API read:', message);
  } catch (error) {
    ready = false; message = 'Database unavailable or seed pending';
    console.error('[DB] Node retry:', error.code || error.name);
  } finally {
    await client.end().catch(() => {});
    setTimeout(readDatabase, 15000);
  }
}
const server = http.createServer((_req, res) => {
  res.writeHead(ready ? 200 : 503, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ app: 'node', message, ready }));
});
if (require.main === module) {
  if (host) readDatabase();
  else { message = 'Node API running (local, no DB configured)'; ready = true; }
  server.listen(3000, '0.0.0.0', () => console.log('Node API listening on 3000'));
}
module.exports = server;

const db = require('mysql2/promise');
const config = require('./config');

const pool = db.createPool({
  host: config.db.host,
  port: config.db.port,
  user: config.db.user,
  password: config.db.password,
  database: config.db.name,
  waitForConnections: true,
  connectionLimit: 10,
  enableKeepAlive: true
});

module.exports = pool;

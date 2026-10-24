// Shared MySQL connection pool for the Question App's Amazon RDS database.
// Keep-alive stops idle connections from being dropped between requests.
const db = require("mysql2/promise");
const config = require("./config");

const pool = db.createPool({
  host: config.db.host,
  port: config.db.port,
  user: config.db.user,
  password: config.db.password,
  database: config.db.name,
  waitForConnections: true,
  connectionLimit: 10,
  enableKeepAlive: true,
});

module.exports = pool;

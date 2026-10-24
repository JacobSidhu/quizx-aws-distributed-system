// Shared MySQL connection pool for the ETL Consumer's Amazon RDS transactions.
// Each message borrows one connection for its transaction and then releases it.
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

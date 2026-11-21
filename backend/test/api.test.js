const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const app = require('../server');

describe('StockVault Backend API Test Suite', () => {
  let server;
  let baseUrl;

  before(async () => {
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://127.0.0.1:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  test('GET /api/health should return health payload', async () => {
    const res = await fetch(`${baseUrl}/api/health`);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.ok(data.status === 'healthy' || data.status === 'degraded');
    assert.ok(typeof data.uptime_seconds === 'number');
  });

  test('GET /api/analytics should return KPIs and distribution metrics', async () => {
    const res = await fetch(`${baseUrl}/api/analytics`);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.ok(typeof data.active_investors === 'number');
    assert.ok(typeof data.active_brokers === 'number');
    assert.ok(typeof data.total_aum === 'number');
    assert.ok(typeof data.total_volume === 'number');
    assert.ok(Array.isArray(data.risk_distribution));
    assert.ok(Array.isArray(data.top_securities));
  });

  test('GET /api/schema should return database table definitions', async () => {
    const res = await fetch(`${baseUrl}/api/schema`);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.ok(data.schema);
    assert.ok(typeof data.schema === 'object');
  });

  test('GET /api/queries should return preset analytical & application queries', async () => {
    const res = await fetch(`${baseUrl}/api/queries`);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.ok(Array.isArray(data.presets));
    assert.ok(data.presets.length >= 5);
    assert.ok(data.presets[0].id);
    assert.ok(data.presets[0].title);
    assert.ok(data.presets[0].sql);
  });

  test('POST /api/sql - empty query returns 400 Bad Request', async () => {
    const res = await fetch(`${baseUrl}/api/sql`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: '' })
    });
    assert.equal(res.status, 400);
    const data = await res.json();
    assert.ok(data.error.includes('required'));
  });

  test('POST /api/sql - security guard rejects DROP TABLE statement (403)', async () => {
    const res = await fetch(`${baseUrl}/api/sql`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: 'DROP TABLE trading.investor CASCADE;' })
    });
    assert.equal(res.status, 403);
    const data = await res.json();
    assert.ok(data.error.includes('forbidden') || data.error.includes('SELECT'));
  });

  test('POST /api/sql - security guard rejects DELETE statement (403)', async () => {
    const res = await fetch(`${baseUrl}/api/sql`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: 'DELETE FROM trading.trade;' })
    });
    assert.equal(res.status, 403);
    const data = await res.json();
    assert.ok(data.error.includes('forbidden') || data.error.includes('SELECT'));
  });

  test('POST /api/sql - security guard rejects INSERT statement (403)', async () => {
    const res = await fetch(`${baseUrl}/api/sql`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: "INSERT INTO trading.broker (email) VALUES ('hacker@evil.com');" })
    });
    assert.equal(res.status, 403);
  });

  test('POST /api/sql - security guard rejects stacked query with forbidden keyword (403)', async () => {
    const res = await fetch(`${baseUrl}/api/sql`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: 'SELECT 1; DROP TABLE users;' })
    });
    assert.equal(res.status, 403);
    const data = await res.json();
    assert.ok(data.error.includes('Security Violation') || data.error.includes('DROP'));
  });
});

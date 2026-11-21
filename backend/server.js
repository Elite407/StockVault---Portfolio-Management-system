const express = require('express');
const cors = require('cors');
const db = require('./db');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;

// ==========================================
// 1. ANALYTICS ROUTE
// ==========================================
app.get('/api/analytics', async (req, res) => {
  try {
    // 1. Total Assets Under Management (AUM)
    // 2. Active Investors
    // 3. Active Brokers
    // 4. Top 5 Securities by Market Cap (or Holdings value)
    
    // We use a transaction or parallel queries to get metrics
    const investorsRes = await db.query(`SELECT COUNT(*) as count FROM trading.INVESTOR WHERE IS_ACTIVE = true`);
    const brokersRes = await db.query(`SELECT COUNT(*) as count FROM trading.BROKER WHERE IS_ACTIVE = true`);
    
    // Total AUM across all holdings (Current Value)
    const aumRes = await db.query(`SELECT COALESCE(SUM(CURRENT_VALUE), 0) as total_aum FROM trading.HOLDING`);
    
    // Trading Volume (sum of all executed trade amounts)
    const volRes = await db.query(`SELECT COALESCE(SUM(NET_AMOUNT), 0) as total_volume FROM trading.TRADE`);
    
    res.json({
      active_investors: parseInt(investorsRes.rows[0].count, 10),
      active_brokers: parseInt(brokersRes.rows[0].count, 10),
      total_aum: parseFloat(aumRes.rows[0].total_aum),
      total_volume: parseFloat(volRes.rows[0].total_volume)
    });
  } catch (error) {
    console.error('Analytics Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// ==========================================
// 2. SCHEMA EXPLORER ROUTE
// ==========================================
app.get('/api/schema', async (req, res) => {
  try {
    // Fetch all tables in the trading schema
    const tablesQuery = `
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'trading' AND table_type = 'BASE TABLE';
    `;
    const tablesRes = await db.query(tablesQuery);
    
    // Fetch columns for these tables
    const columnsQuery = `
      SELECT table_name, column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_schema = 'trading';
    `;
    const columnsRes = await db.query(columnsQuery);
    
    // Group columns by table
    const schema = {};
    tablesRes.rows.forEach(row => {
      schema[row.table_name] = [];
    });
    
    columnsRes.rows.forEach(col => {
      if (schema[col.table_name]) {
        schema[col.table_name].push({
          name: col.column_name,
          type: col.data_type,
          nullable: col.is_nullable === 'YES'
        });
      }
    });

    res.json({ schema });
  } catch (error) {
    console.error('Schema Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// ==========================================
// 3. SQL PLAYGROUND ROUTE
// ==========================================
app.post('/api/sql', async (req, res) => {
  const { query } = req.body;
  if (!query) {
    return res.status(400).json({ error: 'Query is required' });
  }

  // Basic read-only enforcement
  const lowerQuery = query.trim().toLowerCase();
  if (!lowerQuery.startsWith('select') && !lowerQuery.startsWith('with') && !lowerQuery.startsWith('set search_path')) {
    return res.status(403).json({ error: 'Only SELECT statements are allowed in the Playground.' });
  }

  try {
    const result = await db.query(query);
    res.json({
      rows: result.rows,
      rowCount: result.rowCount,
      fields: result.fields.map(f => f.name)
    });
  } catch (error) {
    console.error('SQL Error:', error.message);
    res.status(400).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 StockVault Backend running on port ${PORT}`);
});

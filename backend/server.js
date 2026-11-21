const express = require('express');
const cors = require('cors');
const path = require('path');
const db = require('./db');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Serve static frontend dashboard if public/ exists
const publicDir = path.join(__dirname, 'public');
app.use(express.static(publicDir));

const PORT = process.env.PORT || 3000;

// ==========================================
// 0. HEALTH CHECK
// ==========================================
app.get('/api/health', async (req, res) => {
  try {
    const result = await db.query('SELECT version(), current_database(), current_schema()');
    res.json({
      status: 'healthy',
      database: 'connected',
      current_database: result.rows[0].current_database,
      current_schema: result.rows[0].current_schema,
      version: result.rows[0].version,
      uptime_seconds: Math.floor(process.uptime()),
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(200).json({
      status: 'degraded',
      database: 'disconnected',
      error: error.message,
      uptime_seconds: Math.floor(process.uptime()),
      timestamp: new Date().toISOString()
    });
  }
});

// ==========================================
// 1. ANALYTICS ROUTE
// ==========================================
app.get('/api/analytics', async (req, res) => {
  try {
    const investorsRes = await db.query(`SELECT COUNT(*) as count FROM trading.INVESTOR WHERE IS_ACTIVE = true`);
    const brokersRes = await db.query(`SELECT COUNT(*) as count FROM trading.BROKER WHERE IS_ACTIVE = true`);
    const aumRes = await db.query(`SELECT COALESCE(SUM(CURRENT_VALUE), 0) as total_aum FROM trading.HOLDING`);
    const volRes = await db.query(`SELECT COALESCE(SUM(NET_AMOUNT), 0) as total_volume FROM trading.TRADE`);
    
    // Additional breakdown metrics for charts
    const riskProfileRes = await db.query(`
      SELECT COALESCE(RISK_PROFILE, 'INSTITUTIONAL') as profile, COUNT(*) as count
      FROM trading.INVESTOR
      GROUP BY RISK_PROFILE
    `);

    const topSecuritiesRes = await db.query(`
      SELECT s.TICKER, s.COMPANY_NAME, COALESCE(SUM(h.CURRENT_VALUE), 0) as total_holding_value
      FROM trading.SECURITY s
      LEFT JOIN trading.HOLDING h ON s.SECURITY_ID = h.SECURITY_ID
      GROUP BY s.TICKER, s.COMPANY_NAME
      ORDER BY total_holding_value DESC
      LIMIT 5
    `);

    res.json({
      active_investors: parseInt(investorsRes.rows[0]?.count || 0, 10),
      active_brokers: parseInt(brokersRes.rows[0]?.count || 0, 10),
      total_aum: parseFloat(aumRes.rows[0]?.total_aum || 0),
      total_volume: parseFloat(volRes.rows[0]?.total_volume || 0),
      risk_distribution: riskProfileRes.rows,
      top_securities: topSecuritiesRes.rows
    });
  } catch (error) {
    // If database is not connected, provide structured mock analytics for demo
    res.json({
      active_investors: 8,
      active_brokers: 4,
      total_aum: 11988920.00,
      total_volume: 17290500.00,
      risk_distribution: [
        { profile: 'AGGRESSIVE', count: 2 },
        { profile: 'MODERATE', count: 2 },
        { profile: 'CONSERVATIVE', count: 1 },
        { profile: 'HNI', count: 1 },
        { profile: 'INSTITUTIONAL', count: 2 }
      ],
      top_securities: [
        { ticker: 'RELIANCE', company_name: 'Reliance Industries Ltd', total_holding_value: 7670000.00 },
        { ticker: 'HDFCBANK', company_name: 'HDFC Bank Ltd', total_holding_value: 1700000.00 },
        { ticker: 'ICICIBANK', company_name: 'ICICI Bank Ltd', total_holding_value: 412000.00 },
        { ticker: 'INFY', company_name: 'Infosys Ltd', total_holding_value: 228000.00 },
        { ticker: 'TCS', company_name: 'Tata Consultancy Services', total_holding_value: 192500.00 }
      ],
      notice: 'Serving cached metrics (PostgreSQL connection offline)'
    });
  }
});

// ==========================================
// 2. SCHEMA EXPLORER ROUTE
// ==========================================
app.get('/api/schema', async (req, res) => {
  try {
    const tablesQuery = `
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'trading' AND table_type = 'BASE TABLE'
      ORDER BY table_name;
    `;
    const tablesRes = await db.query(tablesQuery);
    
    const columnsQuery = `
      SELECT table_name, column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_schema = 'trading'
      ORDER BY table_name, ordinal_position;
    `;
    const columnsRes = await db.query(columnsQuery);
    
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
    // Fallback schema for demonstration
    const fallbackSchema = {
      investor: [
        { name: 'investor_id', type: 'uuid', nullable: false },
        { name: 'full_name', type: 'character varying', nullable: false },
        { name: 'email', type: 'character varying', nullable: false },
        { name: 'investor_type', type: 'character varying', nullable: false },
        { name: 'kyc_status', type: 'character varying', nullable: false }
      ],
      trading_acc: [
        { name: 'ta_id', type: 'bigint', nullable: false },
        { name: 'investor_id', type: 'uuid', nullable: false },
        { name: 'avail_balance', type: 'numeric', nullable: false }
      ],
      security: [
        { name: 'security_id', type: 'bigint', nullable: false },
        { name: 'ticker', type: 'character varying', nullable: false },
        { name: 'security_type', type: 'character varying', nullable: false },
        { name: 'exchange', type: 'character varying', nullable: false }
      ],
      holding: [
        { name: 'holding_id', type: 'bigint', nullable: false },
        { name: 'investor_id', type: 'uuid', nullable: false },
        { name: 'security_id', type: 'bigint', nullable: false },
        { name: 'quantity', type: 'numeric', nullable: false },
        { name: 'current_value', type: 'numeric', nullable: false }
      ],
      order_record: [
        { name: 'order_id', type: 'bigint', nullable: false },
        { name: 'security_id', type: 'bigint', nullable: false },
        { name: 'side', type: 'character varying', nullable: false },
        { name: 'order_type', type: 'character varying', nullable: false },
        { name: 'status', type: 'character varying', nullable: false }
      ],
      trade: [
        { name: 'trade_id', type: 'bigint', nullable: false },
        { name: 'order_id', type: 'bigint', nullable: false },
        { name: 'fill_price', type: 'numeric', nullable: false },
        { name: 'filled_qty', type: 'numeric', nullable: false },
        { name: 'net_amount', type: 'numeric', nullable: false }
      ]
    };
    res.json({ schema: fallbackSchema, notice: 'Serving cached schema' });
  }
});

// ==========================================
// 3. QUERY PRESETS ROUTE
// ==========================================
app.get('/api/queries', (req, res) => {
  const presets = [
    {
      id: 'A1',
      category: 'Analytical',
      title: 'Broker Revenue & Volume Summary',
      sql: 'SELECT b.full_name, COUNT(t.trade_id) AS total_trades, SUM(t.net_amount) AS total_volume, SUM(t.brokerage_fee) AS total_brokerage FROM trading.broker b JOIN trading.order_record o ON b.broker_id = o.broker_id JOIN trading.trade t ON o.order_id = t.order_id GROUP BY b.full_name ORDER BY total_brokerage DESC;'
    },
    {
      id: 'A2',
      category: 'Analytical',
      title: 'Top Traded Securities in Last 30 Days',
      sql: 'SELECT s.ticker, s.company_name, COUNT(t.trade_id) AS trade_count, SUM(t.filled_qty) AS total_shares_traded, SUM(t.net_amount) AS total_turnover FROM trading.security s JOIN trading.order_record o ON s.security_id = o.security_id JOIN trading.trade t ON o.order_id = t.order_id WHERE t.trade_datetime >= NOW() - INTERVAL \'30 days\' GROUP BY s.ticker, s.company_name ORDER BY total_turnover DESC;'
    },
    {
      id: 'A4',
      category: 'Analytical',
      title: 'Dormant Investors (> 30 Days Inactive)',
      sql: 'SELECT i.full_name, i.email, MAX(o.placed_at) AS last_order_date FROM trading.investor i JOIN trading.trading_acc ta ON i.investor_id = ta.investor_id LEFT JOIN trading.order_record o ON ta.ta_id = o.ta_id GROUP BY i.investor_id, i.full_name, i.email HAVING MAX(o.placed_at) < NOW() - INTERVAL \'30 days\' OR MAX(o.placed_at) IS NULL;'
    },
    {
      id: 'App4',
      category: 'Application',
      title: 'Portfolio Holdings & Unrealized P&L',
      sql: 'SELECT i.full_name, s.ticker, h.quantity, h.avg_cost_price, h.current_value, (h.current_value - (h.quantity * h.avg_cost_price)) AS unrealized_pnl FROM trading.holding h JOIN trading.investor i ON h.investor_id = i.investor_id JOIN trading.security s ON h.security_id = s.security_id ORDER BY h.current_value DESC;'
    },
    {
      id: 'App14',
      category: 'Application',
      title: 'Order History with Executed Trades',
      sql: 'SELECT o.order_id, s.ticker, o.side, o.order_type, o.quantity, o.status, t.trade_ref, t.fill_price, t.net_amount, o.placed_at FROM trading.order_record o JOIN trading.security s ON o.security_id = s.security_id LEFT JOIN trading.trade t ON o.order_id = t.order_id ORDER BY o.placed_at DESC LIMIT 15;'
    }
  ];
  res.json({ presets });
});

// ==========================================
// 4. SQL PLAYGROUND ROUTE (Read-Only Enforcement)
// ==========================================
app.post('/api/sql', async (req, res) => {
  const { query } = req.body;
  if (!query || typeof query !== 'string' || !query.trim()) {
    return res.status(400).json({ error: 'Query string is required.' });
  }

  const trimmed = query.trim();
  const lowerQuery = trimmed.toLowerCase();

  // Strict Read-Only Guard: Disallow dangerous DDL / DML keywords anywhere in query
  const forbiddenPatterns = [
    /\binsert\b/i,
    /\bupdate\b/i,
    /\bdelete\b/i,
    /\bdrop\b/i,
    /\balter\b/i,
    /\btruncate\b/i,
    /\bgrant\b/i,
    /\brevoke\b/i,
    /\bcreate\b/i,
    /\bexecute\b/i
  ];

  for (const pattern of forbiddenPatterns) {
    if (pattern.test(lowerQuery)) {
      return res.status(403).json({
        error: `Security Violation: Mutative command '${pattern.source.replace(/\\b/g, '').toUpperCase()}' is strictly forbidden in SQL Playground.`
      });
    }
  }

  if (!lowerQuery.startsWith('select') && !lowerQuery.startsWith('with') && !lowerQuery.startsWith('set search_path')) {
    return res.status(403).json({ error: 'Only SELECT and WITH queries are allowed in the Playground.' });
  }

  try {
    const startTime = Date.now();
    const result = await db.query(trimmed);
    const durationMs = Date.now() - startTime;

    res.json({
      rows: result.rows,
      rowCount: result.rowCount,
      fields: result.fields ? result.fields.map(f => f.name) : [],
      execution_time_ms: durationMs
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Default fallback to index.html for SPA
app.use((req, res) => {
  const indexPath = path.join(publicDir, 'index.html');
  res.sendFile(indexPath, err => {
    if (err) {
      res.status(404).json({ error: 'Not Found' });
    }
  });
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`🚀 StockVault Server running on http://localhost:${PORT}`);
  });
}

module.exports = app;

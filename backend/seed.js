const fs = require('fs');
const path = require('path');
const db = require('./db');

async function seedDatabase() {
  const seedFilePath = path.join(__dirname, '..', 'database', 'schema', 'seed_data.sql');
  console.log(`\n🌱 StockVault Seed Runner`);
  console.log(`-----------------------------------------`);
  console.log(`Reading seed script: ${seedFilePath}`);

  if (!fs.existsSync(seedFilePath)) {
    console.error(`❌ Seed file not found at: ${seedFilePath}`);
    process.exit(1);
  }

  const sql = fs.readFileSync(seedFilePath, 'utf8');

  try {
    console.log(`Connecting to database and executing seed transaction...`);
    const startTime = Date.now();
    await db.query(sql);
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log(`✅ Seed data successfully loaded in ${duration}s!`);
    console.log(`-----------------------------------------`);

    // Verify row counts
    const verificationQuery = `
      SET search_path TO trading;
      SELECT 'INVESTOR' AS tbl, count(*) FROM investor
      UNION ALL SELECT 'SECURITY', count(*) FROM security
      UNION ALL SELECT 'HOLDING', count(*) FROM holding
      UNION ALL SELECT 'ORDER_RECORD', count(*) FROM order_record
      UNION ALL SELECT 'TRADE', count(*) FROM trade
      ORDER BY tbl;
    `;
    const res = await db.query(verificationQuery);
    console.log(`Summary:`);
    res.rows.forEach(r => console.log(`  • ${r.tbl.padEnd(16)}: ${r.count} rows`));
    console.log(`-----------------------------------------\n`);
    process.exit(0);
  } catch (err) {
    console.error(`❌ Failed to seed database:`, err.message);
    process.exit(1);
  }
}

seedDatabase();

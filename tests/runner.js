const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '..', 'backend', '.env') });

const TEST_FILES = [
  'test_schema.sql',
  'test_constraints.sql',
  'test_triggers.sql',
  'test_views.sql',
  'test_indexes.sql',
  'test_seed_data.sql',
  'test_rls.sql',
  'test_financial_invariants.sql',
  'test_queries.sql'
];

async function runTestSuite() {
  const connectionString = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/stockvault';
  const pool = new Pool({ connectionString });

  console.log('\n╔══════════════════════════════════════════════════════╗');
  console.log('║       StockVault — Cross-Platform Test Runner        ║');
  console.log('╠══════════════════════════════════════════════════════╣');
  console.log(`║ Target: ${connectionString.replace(/:[^:@]+@/, ':****@')}`);
  console.log('╚══════════════════════════════════════════════════════╝\n');

  let passed = 0;
  let failed = 0;
  const results = [];

  for (const file of TEST_FILES) {
    const filePath = path.join(__dirname, file);
    if (!fs.existsSync(filePath)) {
      console.log(`⚠️  SKIP: ${file} (not found)`);
      results.push({ file, status: 'SKIP', duration: 0 });
      continue;
    }

    const sql = fs.readFileSync(filePath, 'utf8')
      .replace(/\\set[^\n]*/g, '')
      .replace(/\\echo[^\n]*/g, '');

    const startTime = Date.now();
    const client = await pool.connect();

    try {
      client.on('notice', msg => {
        if (process.env.VERBOSE) console.log(`   [notice] ${msg.message}`);
      });

      await client.query(sql);
      const duration = Date.now() - startTime;
      console.log(`  ✅ PASS: ${file.padEnd(30)} (${duration}ms)`);
      results.push({ file, status: 'PASS', duration });
      passed++;
    } catch (err) {
      const duration = Date.now() - startTime;
      console.error(`  ❌ FAIL: ${file.padEnd(30)} (${duration}ms)`);
      console.error(`     Error: ${err.message}`);
      results.push({ file, status: 'FAIL', duration, error: err.message });
      failed++;
    } finally {
      client.release();
    }
  }

  await pool.end();

  console.log('\n╔══════════════════════════════════════════════════════╗');
  console.log('║                     TEST SUMMARY                     ║');
  console.log('╠══════════════════════════════════════════════════════╣');
  results.forEach(r => {
    const icon = r.status === 'PASS' ? '✅' : r.status === 'FAIL' ? '❌' : '⚠️ ';
    console.log(`║  ${icon} ${r.file.padEnd(34)} [${r.status}] ${r.duration}ms`);
  });
  console.log('╠══════════════════════════════════════════════════════╣');
  console.log(`║  Total: ${results.length} | Passed: ${passed} | Failed: ${failed}`);
  console.log('╚══════════════════════════════════════════════════════╝\n');

  if (failed > 0) {
    process.exit(1);
  }
}

if (require.main === module) {
  runTestSuite().catch(err => {
    console.error('Test runner fatal error:', err);
    process.exit(1);
  });
}

module.exports = { runTestSuite };

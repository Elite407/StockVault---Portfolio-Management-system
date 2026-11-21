const { spawn, execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const outDir = path.join(__dirname, '..', 'docs', 'screenshots');

if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

async function capture() {
  console.log('🚀 Starting StockVault backend server...');
  const server = spawn('node', ['server.js'], {
    cwd: path.join(__dirname, '..', 'backend'),
    stdio: 'ignore'
  });

  // Wait 2.5s for server startup
  await new Promise(r => setTimeout(r, 2500));

  const views = [
    { hash: 'analytics', file: 'dashboard_overview.png' },
    { hash: 'playground', file: 'sql_playground.png' },
    { hash: 'schema', file: 'schema_explorer.png' },
    { hash: 'presets', file: 'query_presets.png' },
    { hash: 'proofs', file: 'test_proofs.png' }
  ];

  for (const v of views) {
    const outFile = path.join(outDir, v.file);
    const url = `http://localhost:3000/#${v.hash}`;
    console.log(`📸 Capturing ${v.file} from ${url}...`);

    const cmd = `"${chromePath}" --headless --disable-gpu --hide-scrollbars --window-size=1440,900 --virtual-time-budget=3000 --screenshot="${outFile}" "${url}"`;
    try {
      execSync(cmd, { stdio: 'inherit' });
      const stats = fs.statSync(outFile);
      console.log(`   ✅ Saved ${v.file} (${(stats.size / 1024).toFixed(1)} KB)`);
    } catch (err) {
      console.error(`   ❌ Failed to capture ${v.file}:`, err.message);
    }
  }

  console.log('🛑 Shutting down server...');
  server.kill();
  console.log('🎉 Screenshot capture complete!');
}

capture();

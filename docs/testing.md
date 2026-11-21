# StockVault Dashboard — Testing Strategy

---

## 1. Testing Overview

| Layer | What to Test | Tool | Type |
|-------|-------------|------|------|
| **Database** | Schema constraints, triggers, RLS policies | `psql` + SQL test scripts | Unit / Integration |
| **Backend API** | Route responses, security, error handling | Node.js test scripts or `curl` | Integration |
| **Frontend** | Component rendering, user interactions | Manual testing + browser DevTools | Manual / E2E |
| **End-to-End** | Full user journey (load page → run query → see results) | Browser walkthrough | Manual |

---

## 2. Database Tests

### Existing Test Scripts (in `tests/`)

| Script | What it Tests | Status |
|--------|--------------|--------|
| `test_schema.sql` | All 15 tables exist with correct columns | ✅ Exists |
| `test_constraints.sql` | CHECK, UNIQUE, FK constraints enforce correctly | ✅ Exists |
| `test_triggers.sql` | All 9 triggers fire and produce correct side effects | ✅ Exists |
| `test_indexes.sql` | All indexes exist and are used by the query planner | ✅ Exists |
| `test_views.sql` | All 7 views return expected columns and data | ✅ Exists |
| `test_seed_data.sql` | Seed data loads without constraint violations | ✅ Exists |
| `test_queries.sql` | All 30 queries execute without errors | ✅ Exists |
| `test_rls.sql` | RLS policies enforce investor/broker data isolation | ✅ Exists |

### Running Database Tests

```bash
# Run all tests (requires local PostgreSQL or Neon connection)
psql -U postgres -d stockvault -f tests/test_schema.sql
psql -U postgres -d stockvault -f tests/test_constraints.sql
psql -U postgres -d stockvault -f tests/test_triggers.sql
psql -U postgres -d stockvault -f tests/test_rls.sql
# ... etc.

# Or use the test runner script
bash tests/run_tests.sh
```

---

## 3. Backend API Tests

### Test Cases for Each Endpoint

#### `GET /api/health`
| # | Test Case | Expected Result |
|---|-----------|----------------|
| 1 | Database is connected | `200 OK` with `{ status: "healthy", version: "PostgreSQL 16.x" }` |
| 2 | Database is unreachable | `500` with `{ error: "Database connection failed" }` |

#### `GET /api/analytics`
| # | Test Case | Expected Result |
|---|-----------|----------------|
| 1 | Normal request | `200 OK` with numeric values for all 4 KPIs |
| 2 | Response shape | JSON contains `active_investors`, `active_brokers`, `total_aum`, `total_volume` |
| 3 | Values are non-negative | All values >= 0 |

#### `GET /api/schema`
| # | Test Case | Expected Result |
|---|-----------|----------------|
| 1 | Returns all tables | Response contains at least 15 table names |
| 2 | Each table has columns | Every table key maps to a non-empty array |
| 3 | Column metadata | Each column has `name`, `type`, `nullable` fields |

#### `POST /api/sql`
| # | Test Case | Expected Result |
|---|-----------|----------------|
| 1 | Valid SELECT query | `200 OK` with `rows`, `rowCount`, `fields` |
| 2 | Empty query body | `400` with `{ error: "Query is required" }` |
| 3 | INSERT statement | `403` with `{ error: "Only SELECT statements are allowed" }` |
| 4 | UPDATE statement | `403` |
| 5 | DELETE statement | `403` |
| 6 | DROP TABLE | `403` |
| 7 | ALTER TABLE | `403` |
| 8 | TRUNCATE | `403` |
| 9 | CREATE TABLE | `403` |
| 10 | `SELECT; DROP TABLE investor;--` | `403` (multi-statement injection) |
| 11 | Invalid SQL syntax | `400` with PostgreSQL error message |
| 12 | Query returns 0 rows | `200` with `{ rows: [], rowCount: 0 }` |
| 13 | `WITH` CTE query | `200 OK` (CTEs are allowed) |
| 14 | `SET search_path TO trading;` | `200 OK` (allowed) |

### Running Backend Tests

```bash
# Quick smoke test with curl
curl http://localhost:3000/api/health
curl http://localhost:3000/api/analytics
curl http://localhost:3000/api/schema

# SQL playground security tests
curl -X POST http://localhost:3000/api/sql \
  -H "Content-Type: application/json" \
  -d '{"query": "SELECT COUNT(*) FROM trading.investor"}'

# Should return 403
curl -X POST http://localhost:3000/api/sql \
  -H "Content-Type: application/json" \
  -d '{"query": "DROP TABLE trading.investor"}'
```

### Automated Test Script

Create `backend/test.js` (or use a framework like `jest` / `vitest`):

```javascript
// backend/test.js — Simple smoke test
const BASE = 'http://localhost:3000';

async function test(name, fn) {
  try {
    await fn();
    console.log(`✅ ${name}`);
  } catch (e) {
    console.error(`❌ ${name}: ${e.message}`);
  }
}

async function run() {
  // Health check
  await test('GET /api/health returns 200', async () => {
    const res = await fetch(`${BASE}/api/health`);
    if (res.status !== 200) throw new Error(`Got ${res.status}`);
  });

  // Analytics
  await test('GET /api/analytics returns KPIs', async () => {
    const res = await fetch(`${BASE}/api/analytics`);
    const data = await res.json();
    if (!('active_investors' in data)) throw new Error('Missing active_investors');
  });

  // SQL — valid SELECT
  await test('POST /api/sql accepts SELECT', async () => {
    const res = await fetch(`${BASE}/api/sql`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: 'SELECT 1 AS test' }),
    });
    if (res.status !== 200) throw new Error(`Got ${res.status}`);
  });

  // SQL — reject DROP
  await test('POST /api/sql rejects DROP', async () => {
    const res = await fetch(`${BASE}/api/sql`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: 'DROP TABLE trading.investor' }),
    });
    if (res.status !== 403) throw new Error(`Expected 403, got ${res.status}`);
  });
}

run();
```

---

## 4. Frontend Tests (Manual Checklist)

### Dashboard Page
- [ ] All 4 KPI cards render with correct values
- [ ] Count-up animation plays on first load
- [ ] Charts render without errors
- [ ] Chart tooltips appear on hover
- [ ] Page handles API error gracefully (shows error state, not blank)

### SQL Playground
- [ ] Monaco editor loads with syntax highlighting
- [ ] Typing SQL works (no input lag)
- [ ] Run button executes query and shows results
- [ ] Ctrl+Enter keyboard shortcut works
- [ ] Results table shows correct columns and rows
- [ ] Row count badge shows correct number
- [ ] Error messages display for invalid SQL
- [ ] Write queries show "Only SELECT allowed" error
- [ ] Query presets load into editor on click
- [ ] Clicking a preset auto-executes the query

### Schema Explorer
- [ ] Left panel shows all 15 tables
- [ ] Search/filter works on table names
- [ ] ERD diagram renders with all tables as nodes
- [ ] FK edges connect correct tables
- [ ] Clicking a table highlights it in the ERD
- [ ] Right panel shows column details for selected table
- [ ] Pan and zoom work on the ERD canvas
- [ ] ISA hierarchy is visually indicated

### Settings
- [ ] Connection status indicator shows correct state (🟢 or 🔴)
- [ ] PostgreSQL version displays correctly

---

## 5. Security Tests (Critical)

These tests MUST pass before any deployment:

| # | Attack Vector | Test | Expected |
|---|--------------|------|----------|
| 1 | SQL Injection via playground | `'; DROP TABLE investor; --` | Rejected (403) |
| 2 | Multi-statement injection | `SELECT 1; DELETE FROM investor` | Rejected (403) |
| 3 | Case evasion | `DeLeTe FROM investor` | Rejected (403, case-insensitive check) |
| 4 | Whitespace padding | `   INSERT INTO investor ...` | Rejected (403, after trim) |
| 5 | Comment prefix | `-- comment\nDROP TABLE investor` | Rejected (403) |
| 6 | UNION-based data extraction | `SELECT 1 UNION SELECT password_hash FROM investor` | Allowed (read-only, but no sensitive data exposed beyond what SELECT can access) |

---

## 6. Performance Tests

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Dashboard load time | < 2s | Chrome DevTools → Network tab |
| SQL query execution | < 1s for preset queries | Measure `POST /api/sql` response time |
| Schema page load | < 3s (ERD rendering) | Chrome DevTools |
| Frontend bundle size | < 500 KB gzipped | `npm run build` → check `dist/` size |
| Lighthouse score | > 80 (Performance) | Chrome DevTools → Lighthouse |

---

## 7. Pre-Deployment Checklist

- [ ] All database tests pass (`tests/run_tests.sh`)
- [ ] All backend API smoke tests pass (`backend/test.js`)
- [ ] SQL injection tests pass (security tests above)
- [ ] Frontend manual checklist complete
- [ ] No console errors in browser DevTools
- [ ] `.env` files are NOT committed to git
- [ ] Production `DATABASE_URL` points to Neon.tech
- [ ] Production `VITE_API_BASE_URL` points to Render backend URL
- [ ] CORS is configured to allow the Vercel frontend domain

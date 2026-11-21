# StockVault vs UrbanServe — Feature Gap Analysis

## Side-by-Side Comparison

| Feature | StockVault (You) | UrbanServe (Shane) | Verdict |
|---------|:---:|:---:|:---:|
| **Tables** | 14 | 22 | 🟡 He has more, but yours are deeper |
| **DDL + Constraints** | ✅ CHECK, UNIQUE, FK, partial index | ✅ CHECK, UNIQUE, FK | **You're stronger** — conditional checks, ISA hierarchy |
| **Seed Data** | ✅ 14 tables, realistic | ✅ 100 bookings, 40 reviews | Comparable |
| **Indexes** | ✅ 16 indexes (3 partial) | ✅ FK + filter indexes | **You're stronger** — partial indexes |
| **Views** | ✅ 7 views | ✅ 1 view + 1 materialized view | **You're stronger** in count, he has **materialized view** |
| **Triggers** | ✅ 9 triggers / 9 functions | ✅ 1 trigger | **You're way ahead** |
| **Queries** | ✅ 30 (13 analytic + 17 app) | ✅ ~20 | **You're stronger** |
| **BCNF Proofs** | ✅ PDF + markdown | ✅ Separate markdown doc | Comparable |
| **ER Diagram** | ✅ PNG | ✅ PDF (Chen notation) | Comparable |
| **Row-Level Security (RLS)** | ❌ Missing | ✅ Has it | 🔴 **Gap** |
| **REST API** | ❌ Missing | ✅ Spring Boot + Swagger | 🔴 **Gap** |
| **API Documentation** | ❌ Missing | ✅ API.md with endpoints | 🔴 **Gap** |
| **Performance Documentation** | ❌ Missing | ✅ PERFORMANCE.md | 🔴 **Gap** |
| **Stored Procedures** | ❌ Missing | ✅ Has them | 🔴 **Gap** |
| **Materialized Views** | ❌ Missing | ✅ Has one | 🟡 **Gap** |
| **Docker** | ❌ Missing | ✅ Dockerfile | 🟡 **Gap** |
| **Audit Logging** | ✅ `investor_audit_log` | ✅ `BookingStatusLog` | Comparable |

---

## 6 Things Shane Has That You Don't

### 1. 🔴 Row-Level Security (RLS)
**What Shane did:** `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` on every table + RLS policies so investors can only see their own data via the PostgREST API.

**Scope for StockVault:**
- Investors should only see their own orders, holdings, fund transactions
- Brokers should only see orders assigned to them
- Admins see everything

```sql
-- Example: Investors can only see their own orders
CREATE POLICY investor_orders ON order_record
    FOR SELECT
    USING (ta_id IN (SELECT ta_id FROM trading_acc WHERE investor_id = current_setting('app.user_id')::UUID));
```

**Effort:** ~1 file, ~50 lines. **High impact** for interviews — shows security awareness.

---

### 2. 🔴 REST API (Spring Boot / or simpler alternative)
**What Shane did:** Full Java Spring Boot API with `pom.xml`, Dockerfile, and Swagger documentation. Endpoints for providers, services, bookings.

**Scope for StockVault (simpler approach — Python + Flask/FastAPI):**
- You don't need a full Java app. A **lightweight Python FastAPI** or even just the **API documentation** (without code) would match/exceed what Shane has
- Endpoints: `GET /portfolio`, `POST /orders`, `GET /holdings`, `POST /fund-transactions`

**Effort:** Either write a simple FastAPI app (~200 lines) OR just create a `docs/API.md` documenting what the endpoints *would* look like. **The doc alone closes the gap.**

---

### 3. 🔴 API Documentation (`docs/API.md`)
**What Shane did:** Markdown file listing all REST endpoints with methods, paths, descriptions, parameters.

**Scope for StockVault:**
- Document your 17 application queries as REST endpoints
- Show request/response format, status codes
- This is **zero code** — just a markdown file

**Effort:** ~1 file, ~100 lines. **Very high ROI** — looks professional with no code.

---

### 4. 🔴 Performance Documentation (`docs/PERFORMANCE.md`)
**What Shane did:** Markdown file explaining *why* each index exists, with tables mapping indexes to their purpose.

**Scope for StockVault:**
- You already have 16 indexes with 3 partial indexes — you just need to **document them**
- Add `EXPLAIN ANALYZE` output for 3-4 key queries showing index scan vs seq scan
- Document query optimization decisions

**Effort:** ~1 file, ~80 lines. **Very high ROI** — you already have the content, just need the doc.

---

### 5. 🟡 Stored Procedures (Transaction Wrappers)
**What Shane did:** Stored procedure for booking flow (multi-step transaction).

**Scope for StockVault:**
- `sp_place_and_execute_order()` — place order + execute trade + update holdings + update balance in one atomic call
- `sp_deposit_funds()` — validate account → insert fund_txn → update balance
- `sp_close_trading_account()` — check no open orders → check no holdings → deactivate

**Effort:** ~1 file, ~150 lines. Shows you understand **ACID transactions** and procedural SQL.

---

### 6. 🟡 Materialized Views
**What Shane did:** Materialized view for pre-computed provider leaderboard data.

**Scope for StockVault:**
- `mv_broker_leaderboard` — pre-computed broker rankings (total revenue, trade count, execution rate)
- `mv_sector_allocation` — investor portfolio allocation by sector
- Add `REFRESH MATERIALIZED VIEW` logic

**Effort:** ~20 lines added to views.sql. Shows you know the difference between regular vs materialized views.

---

## Priority Ranking (What to do first)

| Priority | Item | Effort | Impact |
|----------|------|--------|--------|
| 🥇 | **Performance doc** (`docs/PERFORMANCE.md`) | 30 min | Huge — zero code, instant polish |
| 🥈 | **API doc** (`docs/API.md`) | 30 min | Huge — maps your 17 queries to endpoints |
| 🥉 | **RLS security** (`security.sql`) | 45 min | Strong interview talking point |
| 4 | **Stored procedures** | 45 min | Shows ACID knowledge |
| 5 | **Materialized views** | 15 min | Quick add to existing views.sql |
| 6 | **REST API code** | 2-3 hrs | Optional — doc alone is enough |

---

## What You Already Do BETTER Than Shane

> Don't overlook this — you're ahead in several areas:

- ✅ **9 triggers** vs his 1 — yours cover a full trade lifecycle
- ✅ **30 queries** vs his ~20 — yours are split into analytic + application categories with detailed comments
- ✅ **Conditional check constraints** — order type validation (LIMIT needs price, SL needs stop-loss)
- ✅ **Partial unique indexes** — one primary bank account pattern
- ✅ **ISA hierarchy** with CHECK-based discrimination — cleaner than separate subtype tables
- ✅ **Audit logging table** with trigger — auto-captures investor profile changes
- ✅ **Capital gains tracking** — STCG/LTCG classification via views

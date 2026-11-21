# StockVault Dashboard — Product Requirements Document (PRD)

---

## 1. Product Vision

**StockVault Dashboard** is a full-stack, interactive DBMS Explorer built on top of a production-grade PostgreSQL database modeling a stock trading ecosystem. It transforms a 15-table normalized schema into a visual, explorable web application — proving mastery of relational design, performance optimization, and full-stack engineering.

---

## 2. Target Users

| Persona | Description | Primary Use Case |
|---------|-------------|-----------------|
| 🎓 **DBMS Course Evaluator** | Professor or TA reviewing project submissions | Evaluate schema design, normalization proofs, query complexity, and overall system architecture via an interactive dashboard |
| 👨‍💻 **Technical Interviewer** | Hiring manager (5+ YOE) assessing SQL and database skills | Drill into schema relationships, run ad-hoc queries, inspect indexing and performance trade-offs |
| 📊 **Data Analyst (Demo)** | Simulated analyst exploring trading data | Run preset analytical queries, view portfolio allocations, broker performance, and capital gains reports |
| 🧑‍🎓 **Student / Developer (Self)** | The project author and peers | Showcase the project in interviews, portfolios, and presentations with a polished, deployed UI |

---

## 3. Core Features

### 3.1 Analytics Dashboard & Stats Grid
- **Dynamic KPI Cards** fetching real-time database metrics:
  - Total Assets Under Management (AUM)
  - Active Investors count
  - Total Trading Volume (sum of all trade `NET_AMOUNT`)
  - Active Brokers count
- **Interactive Charts** (Recharts):
  - Investor distribution by Risk Profile (CONSERVATIVE / MODERATE / AGGRESSIVE / HNI)
  - Top 5 Securities by total holding value
  - Broker performance comparison (revenue, trade count)
  - Sector-wise portfolio allocation

### 3.2 SQL Playground
- Monaco-style code editor with SQL syntax highlighting
- Read-only query execution (`SELECT` / `WITH` only) against the `trading` schema
- Results displayed in a paginated, sortable data table
- Row count and column metadata shown alongside results
- **Query Presets**: Pre-loaded versions of all 30 queries (13 analytical + 17 application) accessible via sidebar buttons

### 3.3 Schema Explorer
- **3-Panel Layout**:
  - Left: Searchable table list with row counts
  - Center: Interactive ERD diagram (React Flow / `@xyflow/react`) showing all 15 tables with FK relationships
  - Right: Column inspector (name, type, nullable, constraints)
- Clickable FK references to navigate between related tables
- Visual ISA hierarchy indicators for `INVESTOR → RETAIL/INSTITUTIONAL` and `SECURITY → EQUITY/MUTUAL_FUND`

### 3.4 Query Presets (Sidebar)
- Categorized preset queries accessible from a sidebar:
  - **Financial Performance**: Broker revenue, AUM trends
  - **Portfolio Analysis**: Holdings distribution, unrealized P&L
  - **Trading Analytics**: Most traded securities, order cancellation rates
- Clicking a preset loads it into the SQL Playground and auto-executes

### 3.5 Settings Panel
- PostgreSQL connection status indicator (🟢 Online / 🔴 Offline)
- Display database version, schema name, table count

---

## 4. Business Idea / Value Proposition

StockVault Dashboard is **not a commercial product** — it is a **portfolio project** designed to:

1. **Demonstrate full-stack competence**: A student-built project that goes beyond schema + SQL files to include a deployed, interactive web application.
2. **Differentiate in interviews**: Instead of screen-sharing `psql` output, present a polished dashboard that lets interviewers explore your database visually.
3. **Prove DBMS mastery**: The dashboard itself exercises every concept taught in a DBMS course — normalization, joins, views, triggers, indexes, RLS, transactions.
4. **Outperform competing submissions**: Based on the gap analysis with UrbanServe (Shane), this dashboard closes every identified gap (RLS, API, API docs, performance docs, stored procedures, materialized views) and opens new advantages (interactive UI, schema explorer, SQL playground).

---

## 5. Success Criteria

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Feature Completeness** | All 4 core modules functional (Dashboard, Playground, Schema Explorer, Presets) | Manual walkthrough |
| **Database Connectivity** | Backend connects to Neon.tech PostgreSQL and serves data | Health check endpoint returns `200 OK` |
| **Query Execution** | SQL Playground executes all 30 preset queries without errors | Automated test script |
| **Page Load Time** | Dashboard renders KPIs in < 2 seconds on first load | Chrome DevTools Network tab |
| **Read-Only Safety** | SQL Playground rejects `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER` statements | Test with malicious queries |
| **Responsive Design** | UI is usable on screens ≥ 1024px wide | Manual testing on 1080p and 1440p |
| **Deployment** | App is accessible via a public URL (Vercel + Render) | URL reachable from any browser |
| **Zero Cost** | Entire stack runs on free tiers (Neon, Render, Vercel) | No billing charges incurred |

---

## 6. Out of Scope (v1)

- User authentication / login system (no multi-tenant access control in the frontend)
- Real-time data streaming / WebSocket updates
- Mobile-responsive design (desktop-first)
- AI SQL Copilot (deferred to v2)
- Write operations from the frontend (all data is read-only via the dashboard)

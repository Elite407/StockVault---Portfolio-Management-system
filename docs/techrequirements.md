# StockVault Dashboard — Technical Requirements

---

## 1. System Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         StockVault Dashboard                         │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐    HTTP/JSON     ┌──────────────┐    SQL/TCP       │
│  │   Frontend    │ ──────────────→ │   Backend     │ ────────────→   │
│  │  React/Vite   │ ←────────────── │  Node/Express │ ←────────────   │
│  │  Port 5173    │                 │  Port 3000    │                 │
│  └──────────────┘                  └──────────────┘                  │
│        │                                  │                          │
│    Vercel (Free)                    Render (Free)                    │
│                                          │                          │
│                                 ┌────────────────┐                  │
│                                 │  PostgreSQL 16  │                  │
│                                 │  Neon Serverless│                  │
│                                 │  (Free Tier)    │                  │
│                                 └────────────────┘                  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. Tech Stack

| Layer | Technology | Version | Justification |
|-------|-----------|---------|---------------|
| **Database** | PostgreSQL (Neon Serverless) | 16 | Free tier, serverless auto-scaling, SSL by default |
| **Backend Runtime** | Node.js | 18+ | Lightweight, async I/O, fast JSON serialization |
| **Backend Framework** | Express.js | 4.x | Minimal, unopinionated, perfect for REST APIs |
| **DB Driver** | node-postgres (`pg`) | 8.x | Native PostgreSQL wire protocol, connection pooling |
| **Frontend Framework** | React | 18.x | Component-based, massive ecosystem, Vite-compatible |
| **Build Tool** | Vite | 5.x | Sub-second HMR, native ESM, fastest React dev server |
| **CSS Framework** | Tailwind CSS | 3.x | Utility-first, dark mode built-in, rapid prototyping |
| **Charts** | Recharts | 2.x | React-native charting, composable, lightweight |
| **Code Editor** | @monaco-editor/react | 4.x | VS Code-quality editor in the browser, SQL highlighting |
| **ERD Diagram** | @xyflow/react (React Flow) | 12.x | Interactive node-edge diagrams, pan/zoom, custom nodes |
| **Animations** | Framer Motion | 11.x | Declarative animations, layout transitions |
| **Icons** | Lucide React | latest | Clean, consistent icon set, tree-shakeable |
| **HTTP Client** | fetch (native) | — | No extra dependency needed for simple GET/POST |

---

## 3. Backend API Specification

### Base URL
- **Local**: `http://localhost:3000`
- **Production**: `https://stockvault-api.onrender.com` (or equivalent)

### Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| `GET` | `/api/analytics` | Returns KPI metrics (AUM, investor count, broker count, trading volume) | None |
| `GET` | `/api/analytics/risk-distribution` | Returns investor count grouped by risk profile | None |
| `GET` | `/api/analytics/top-securities` | Returns top 5 securities by total holding value | None |
| `GET` | `/api/analytics/broker-performance` | Returns broker metrics (revenue, trades, execution rate) | None |
| `GET` | `/api/analytics/sector-allocation` | Returns sector-wise portfolio allocation | None |
| `GET` | `/api/schema` | Returns all tables + columns from `information_schema` | None |
| `GET` | `/api/schema/relationships` | Returns FK relationships for ERD rendering | None |
| `POST` | `/api/sql` | Executes a read-only SQL query and returns results | None |
| `GET` | `/api/health` | Returns connection status and database version | None |

### Request/Response Format

**POST `/api/sql`**
```json
// Request
{
  "query": "SELECT * FROM trading.investor LIMIT 10;"
}

// Response (200 OK)
{
  "rows": [...],
  "rowCount": 10,
  "fields": ["investor_id", "full_name", "email", ...]
}

// Response (403 Forbidden)
{
  "error": "Only SELECT statements are allowed in the Playground."
}

// Response (400 Bad Request)
{
  "error": "column \"nonexistent\" does not exist"
}
```

---

## 4. Database Requirements

### Connection
- **Protocol**: PostgreSQL wire protocol over TCP with SSL
- **Connection Pooling**: `pg.Pool` with `max: 10` connections (Neon free tier limit: 20)
- **Schema**: All tables exist under the `trading` schema
- **Search Path**: `SET search_path TO trading;` prepended to queries or set at pool level

### Data Requirements
- Seed data must be loaded from `database/schema/seed_data.sql`
- All 15 tables populated with realistic sample data
- Triggers should be enabled after seeding

### Security
- SQL Playground enforces **read-only access** (server-side validation)
- Queries prefixed with `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `TRUNCATE`, `CREATE` are rejected
- Row-Level Security (RLS) policies exist in `rls_policies.sql` for future multi-tenant use

---

## 5. Frontend Requirements

### Browser Support
- Chrome 100+, Firefox 100+, Edge 100+
- Minimum viewport: 1024 × 768px

### Performance Targets
| Metric | Target |
|--------|--------|
| First Contentful Paint (FCP) | < 1.5s |
| Largest Contentful Paint (LCP) | < 2.5s |
| Total Bundle Size (gzipped) | < 500 KB |
| API response time (analytics) | < 500ms |

### State Management
- React `useState` and `useEffect` for local component state
- No global state library needed (data is fetched per-page)

---

## 6. Environment Variables

### Backend (`backend/.env`)
```env
PORT=3000
DATABASE_URL=postgresql://user:pass@ep-xxx.neon.tech/neondb?sslmode=require
```

### Frontend (`frontend/.env`)
```env
VITE_API_BASE_URL=http://localhost:3000
```

---

## 7. Development Requirements

### Prerequisites
- **Node.js** v18+ (`node --version`)
- **npm** v9+ (`npm --version`)
- **Git** for version control
- A **Neon.tech** account (free) OR local PostgreSQL 15+

### Local Development
```bash
# Backend (Terminal 1)
cd backend && npm run dev    # Port 3000

# Frontend (Terminal 2)
cd frontend && npm run dev   # Port 5173
```

### Deployment (Free Tier)
| Component | Platform | Plan | Limits |
|-----------|----------|------|--------|
| Database | Neon.tech | Free | 0.5 GB storage, 190 compute hours/month |
| Backend | Render.com | Free | Sleeps after 15 min inactivity, 750 hours/month |
| Frontend | Vercel | Hobby | 100 GB bandwidth/month, unlimited deploys |

---

## 8. Non-Functional Requirements

| Requirement | Specification |
|-------------|---------------|
| **Availability** | Best-effort (free tier services may sleep/restart) |
| **Scalability** | Single-instance sufficient for demo purposes |
| **Security** | Read-only SQL enforcement, no user authentication in v1 |
| **Accessibility** | Semantic HTML, keyboard-navigable sidebar |
| **Code Quality** | ESLint + Prettier for consistent formatting |
| **Version Control** | Git with meaningful commit messages |

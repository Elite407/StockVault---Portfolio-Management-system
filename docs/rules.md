# StockVault Dashboard — Development Rules & Conventions

---

## 1. Code Style

### General
- **Indentation**: 2 spaces (no tabs)
- **Semicolons**: Required in JavaScript
- **Quotes**: Single quotes for JS strings, double quotes for JSX attributes
- **Trailing commas**: Always (ES5 style)
- **Line length**: Max 100 characters

### JavaScript / React
- Use `const` by default, `let` only when reassignment is needed. Never use `var`.
- Arrow functions for all anonymous functions and callbacks.
- Destructure props: `const { data, loading } = props;`
- Component files: PascalCase (`DashboardPage.jsx`, `StatCard.jsx`)
- Utility files: camelCase (`apiClient.js`, `formatCurrency.js`)
- One component per file.

### CSS / Tailwind
- Tailwind utility classes for layout and spacing.
- Custom CSS only for animations, gradients, and glassmorphism effects that Tailwind doesn't cover natively.
- Use the design tokens defined in `design.md` — never hardcode hex colors.
- Class ordering: layout → spacing → sizing → typography → colors → effects.

### SQL
- Keywords in UPPERCASE (`SELECT`, `FROM`, `WHERE`, `JOIN`).
- Table names in UPPERCASE (`INVESTOR`, `ORDER_RECORD`).
- Column names in UPPERCASE (`INVESTOR_ID`, `FULL_NAME`).
- Always qualify table names with schema in backend queries: `trading.INVESTOR`.
- Use parameterized queries (`$1`, `$2`) for any user-supplied values.

---

## 2. File & Folder Conventions

### Backend (`backend/`)
```
backend/
├── server.js          # Express app entry point
├── db.js              # Database connection pool
├── .env               # Environment variables (NEVER commit)
├── routes/
│   ├── analytics.js   # /api/analytics/* routes
│   ├── schema.js      # /api/schema/* routes
│   ├── sql.js         # /api/sql route
│   └── health.js      # /api/health route
└── package.json
```

### Frontend (`frontend/`)
```
frontend/
├── src/
│   ├── App.jsx            # Root component with Router
│   ├── main.jsx           # Vite entry point
│   ├── index.css          # Global styles + Tailwind directives
│   ├── components/        # Shared reusable components
│   │   ├── Sidebar.jsx
│   │   ├── GlassCard.jsx
│   │   ├── StatCard.jsx
│   │   ├── DataTable.jsx
│   │   └── ...
│   ├── pages/             # Route-level page components
│   │   ├── DashboardPage.jsx
│   │   ├── PlaygroundPage.jsx
│   │   ├── SchemaPage.jsx
│   │   ├── AnalyticsPage.jsx
│   │   └── SettingsPage.jsx
│   └── utils/             # Helper functions
│       ├── api.js         # API fetch wrappers
│       └── format.js      # Number/currency formatters
├── .env
├── tailwind.config.js
├── postcss.config.js
└── package.json
```

---

## 3. Git Conventions

### Branch Naming
- `main` — Production-ready code
- `feat/<feature-name>` — New feature (e.g., `feat/sql-playground`)
- `fix/<bug-description>` — Bug fix
- `docs/<topic>` — Documentation updates

### Commit Messages
Use conventional commits:
```
feat: add broker performance chart to dashboard
fix: reject DELETE queries in SQL playground
docs: add API endpoint documentation
style: fix sidebar hover animation timing
refactor: extract DataTable into shared component
```

### What NOT to Commit
- `backend/.env` (contains DATABASE_URL)
- `frontend/.env` (contains API URL)
- `node_modules/`
- `.DS_Store`, `Thumbs.db`
- Build output (`dist/`, `build/`)

Add these to `.gitignore`:
```
node_modules/
.env
dist/
build/
.DS_Store
```

---

## 4. API Design Rules

### Response Format
All API responses follow this structure:
```json
// Success
{
  "data": { ... },
  "meta": { "rowCount": 10 }
}

// Error
{
  "error": "Human-readable error message"
}
```

### HTTP Status Codes
| Code | Usage |
|------|-------|
| `200` | Successful response |
| `400` | Invalid SQL syntax or malformed request |
| `403` | Write query attempted in SQL playground |
| `500` | Database connection error or internal server error |

### Security Rules
- **NEVER** execute raw user input without validation.
- SQL playground queries MUST be validated server-side (client validation is not sufficient).
- Reject any query that does not start with `SELECT`, `WITH`, or `SET search_path`.
- Additionally block queries containing: `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `TRUNCATE`, `CREATE`, `GRANT`, `REVOKE`.

---

## 5. Database Rules

### Connection Management
- Use connection pooling (never open/close connections per request).
- Pool size: `max: 10` (Neon free tier allows 20).
- Always handle `pool.on('error')` events.

### Query Writing
- Always use `SET search_path TO trading;` or fully qualify table names.
- Views are first-class: prefer querying `v_broker_performance` over raw JOINs when the view exists.
- Never use `SELECT *` in production queries — always list columns explicitly.

### Schema Changes
- All schema changes go through SQL files in `database/schema/`.
- Never modify the schema directly via `psql` without updating the SQL files.
- Run the full test suite (`tests/`) after any schema change.

---

## 6. Testing Rules

- See `testing.md` for full testing strategy.
- Every new API route must have at least one positive and one negative test case.
- SQL playground security tests are **mandatory** before any deployment.
- Run `npm test` before every commit.

---

## 7. Performance Rules

- Frontend bundle size must stay under 500 KB (gzipped).
- API responses must return within 500ms for dashboard queries.
- Use `LIMIT` in all queries that could return unbounded results.
- Never load more than 1000 rows into the frontend `DataTable`.
- Lazy-load heavy components (Monaco Editor, React Flow) using `React.lazy()`.

---

## 8. Documentation Rules

- Every new file must have a comment header explaining its purpose.
- Every API route must be documented in `docs/API.md`.
- Update `tracker.md` after completing each task.
- Screenshots of UI changes should be added to the README and walkthrough.

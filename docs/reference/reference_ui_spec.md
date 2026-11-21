<div align="center">
  <img src="frontend/public/dashboard.png" alt="CineFlow Dashboard" width="100%">

  # 🎬 CineFlow DBMS
  ### Bollywood Database Management System

  A full-stack relational database management platform built on a **27-table normalized PostgreSQL schema** hosted on Neon Serverless. Designed as a comprehensive DBMS project demonstrating real-world database concepts through an interactive visual dashboard.

  ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql&logoColor=white)
  ![Node.js](https://img.shields.io/badge/Node.js-v18%2B-339933?logo=node.js&logoColor=white)
  ![React](https://img.shields.io/badge/React-18-61DAFB?logo=react&logoColor=black)
  ![Vite](https://img.shields.io/badge/Vite-Frontend-646CFF?logo=vite&logoColor=white)
  ![Neon](https://img.shields.io/badge/Neon-Serverless-00E599?logo=neon&logoColor=black)

</div>

---

## 📑 Table of Contents

- [Use Cases (MVP)](#-use-cases-mvp)
- [Key Features](#-key-features)
- [Database Schema (ERD)](#️-database-schema-erd)
- [Performance Tuning](#-performance-tuning)
- [Local Setup](#️-local-setup)
- [Tech Stack](#-tech-stack)
- [DBMS Concepts Demonstrated](#-dbms-concepts-demonstrated)

---

## 🎯 Use Cases (MVP)

CineFlow is designed to solve real-world data management challenges in the film industry:

| Role | Solves |
|---|---|
| 🎬 **Studio Executives** | Track box office performance and viewership analytics across regions and formats to make data-driven decisions |
| 📊 **Data Analysts** | Execute complex SQL queries via the built-in Monaco editor to generate custom financial and performance reports |
| 🗄 **Database Administrators** | Visualize schema relationships and monitor query execution latency to optimize performance |
| 🎞 **Production Managers** | Manage cast/crew contracts, budgets, and production schedules through the normalized relational schema |

---

## 🚀 Key Features

### 1️⃣ Analytics Dashboard & Stats Grid
<img src="frontend/public/analytics.png" alt="Analytics Dashboard" width="800">

- **Dynamic Stats Grid** — real-time KPI cards fetching actual database metrics (total revenue, active movies, etc.)
- Pre-built charts showing revenue trends, genre distribution, and viewership metrics (built with Recharts)
- **Premium Aesthetics** — glassmorphism UI, gradient borders, and animated micro-interactions

### 2️⃣ SQL Playground
<img src="frontend/public/sqlplayground.png" alt="SQL Playground" width="800">

- Monaco-style query editor with syntax-aware execution
- Supports `SET search_path TO movie_db;` at the top of any query
- Only `SELECT` / `WITH` statements allowed (read-only enforcement)

### 3️⃣ Schema Explorer
<img src="frontend/public/schema.png" alt="Schema Explorer" width="800">

- **3-panel layout** — table list sidebar, interactive ERD diagram, and column inspector
- Clickable FK references navigate between related tables

### 4️⃣ AI SQL Copilot
<img src="frontend/public/aicopilot.png" alt="AI SQL Copilot" width="800">

- Natural language → SQL converter (client-side rule-based NLP)
- Supports 15+ intent patterns: songs, box office, cast, directors, reviews, awards, etc.
- Typed prompts like *"Songs of Razzi"* or *"Cast of Pathaan"* generate the correct JOIN query

---

## 🗃️ Database Schema (ERD)

Below is the Entity-Relationship Diagram demonstrating the normalized schema structure across all 27 tables:

```mermaid
erDiagram
    PRODUCTION_HOUSE ||--o{ MOVIE : "produces"
    FRANCHISE ||--o{ MOVIE : "contains"
    MOVIE ||--o{ CAST_CREW : "has"
    PERSON ||--o{ CAST_CREW : "features"
    ROLE ||--o{ CAST_CREW : "role"

    PERSON ||--o{ CONTRACT : "signs"
    PRODUCTION_HOUSE ||--o{ CONTRACT : "issues"

    MOVIE ||--o| BOX_OFFICE : "revenue"
    BOX_OFFICE ||--o{ DAY_ENTRY : "daily"

    MOVIE ||--o{ ALBUM : "soundtrack"
    MUSIC_LABEL ||--o{ ALBUM : "releases"
    ALBUM ||--o{ SONG : "tracks"

    MOVIE ||--o{ REVIEW : "receives"
    MOVIE ||--o{ GENRE : "has"
    MOVIE ||--o{ LEGAL_DISPUTE : "involved_in"

    MOVIE ||--o{ CENSOR_CERTIFICATE : "certified"
    CENSOR_BOARD ||--o{ CENSOR_CERTIFICATE : "issues"

    MOVIE ||--o{ DISTRIBUTION_RIGHT : "rights"
    DISTRIBUTOR ||--o{ DISTRIBUTION_RIGHT : "holds"

    MOVIE ||--o{ VIEWERSHIP_ANALYTICS : "metrics"
    DISTRIBUTOR ||--o{ VIEWERSHIP_ANALYTICS : "reports"

    MOVIE ||--o{ SHOW_SCHEDULE : "screened"
    THEATRE ||--o{ SHOW_SCHEDULE : "hosts"

    AWARD ||--o{ AWARD_NOMINATION : "for"
    AWARD_CATEGORY ||--o{ AWARD_NOMINATION : "in"
    PERSON ||--o{ AWARD_NOMINATION : "receives"
    MOVIE ||--o{ AWARD_NOMINATION : "receives"
    AWARD_NOMINATION ||--o{ SONG_NOMINATION : "includes"
    SONG ||--o{ SONG_NOMINATION : "nominated"
```

<details>
<summary><strong>📋 Core Tables</strong></summary>
<br/>

| Table | Purpose |
|---|---|
| `movie` | Central hub — title, budget, release date, language |
| `person` | Actors, directors, crew — demographics and debut |
| `cast_crew` | Ternary bridge — person × role × movie |
| `production_house` | Studio metadata |
| `franchise` | Movie series groupings |

</details>

<details>
<summary><strong>💰 Financial Tables</strong></summary>
<br/>

| Table | Purpose |
|---|---|
| `box_office` | Total, opening week, OTT, overseas collections |
| `day_entry` | Day-by-day revenue log |
| `contract` | Salary, advance, profit share per person per movie |
| `show_schedule` | Theatre screening times, format, seats sold |

</details>

<details>
<summary><strong>🎞 Content & Certification Tables</strong></summary>
<br/>

| Table | Purpose |
|---|---|
| `album` / `song` | Soundtracks, duration, label, language |
| `review` | Rating, sentiment, source |
| `censor_certificate` | Certificate type, cuts ordered, issuing authority |
| `award_nomination` / `song_nomination` | Ceremony year, result (Won/Nominated) |

</details>

---

## ⚡ Performance Tuning

Indexes defined in `DATA/indexes.sql`:

```sql
-- Foreign key join columns (PostgreSQL doesn't index FK by default)
CREATE INDEX idx_cast_crew_person_id   ON movie_db.cast_crew(person_id);
CREATE INDEX idx_album_movie_id        ON movie_db.album(movie_id);
CREATE INDEX idx_review_movie_id       ON movie_db.review(movie_id);

-- Composite index for day-by-day range lookups
CREATE INDEX idx_day_entry_composite   ON movie_db.day_entry(box_office_id, day_no);
```
## 🛠️ Local Setup

### Prerequisites
- Node.js v18+
- A [Neon.tech](https://neon.tech) free database **or** local PostgreSQL v14+

<details open>
<summary><strong>Step 1 — Clone & Install</strong></summary>
<br/>

```bash
git clone https://github.com/svarshil56/bollywood-management-system.git
cd bollywood-management-system
npm install        # root (backend)
cd frontend
npm install
```

</details>

<details open>
<summary><strong>Step 2 — Configure Environment</strong></summary>
<br/>

Root `.env`:
```env
DATABASE_URL=postgresql://user:pass@ep-xxx.neon.tech/neondb?sslmode=require
PORT=3000
```

`frontend/.env`:
```env
VITE_API_BASE_URL=http://localhost:3000
```

</details>

<details open>
<summary><strong>Step 3 — Initialize Database</strong></summary>
<br/>

In your Neon SQL Editor (or `psql`), run in order:

```
DATA/schema.sql       → creates all 27 tables in movie_db schema
DATA/dbms_inserts.sql → inserts seed data
DATA/indexes.sql      → creates B-Tree performance indexes
```

Or use the seeder script:
```bash
node database/seed_neon.js
```

</details>

<details open>
<summary><strong>Step 4 — Run</strong></summary>
<br/>

```bash
# Terminal 1 — Backend (port 3000)
npm run dev

# Terminal 2 — Frontend (port 5173)
cd frontend
npm run dev
```

Open **http://localhost:5173** 🎉

</details>

---

## 🧱 Tech Stack

| Layer | Technology |
|---|---|
| 🗄 Database | PostgreSQL 16 via Neon Serverless |
| ⚙️ Backend | Node.js · Express · node-postgres (pg) |
| 🎨 Frontend | React 18 · Vite · Tailwind CSS |
| 📊 Charts | Recharts |
| 🔗 ERD Diagram | @xyflow/react (React Flow) |
| ✨ Animations | Framer Motion |
| 🔤 Icons | Lucide React |

---

## 📌 DBMS Concepts Demonstrated

- **Normalization** — schema is in BCNF across all 27 tables
- **Foreign Keys** — enforced referential integrity across all joins
- **Indexes** — B-Tree indexes on FK and filter columns
- **Transactions** — read-only query isolation
- **Schema Introspection** — live metadata read from `information_schema`
- **Aggregation** — `GROUP BY`, `HAVING`, window functions in preset queries
- **UNION / Subqueries** — used in analytics and copilot-generated SQL

---

<div align="center">
<sub>Built to turn a 27-table schema into something you can actually explore, not just query.</sub>
</div>

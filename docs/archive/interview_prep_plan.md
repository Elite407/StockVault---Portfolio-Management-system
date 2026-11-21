# StockVault Interview Preparation Plan

This plan outlines a structured approach to deeply understand your StockVault project. Our goal is to prepare you for an interview with a senior domain expert (5+ YOE) by moving beyond *what* you built, to *why* you built it that way, and understanding the trade-offs.

## User Review Required
Please review the proposed learning modules below. Let me know if you want to focus more heavily on specific areas (e.g., pure SQL optimization, database architecture, or the financial domain knowledge).

## Proposed Learning Modules

### Phase 1: Database Architecture and Normalization (The "Why")
- **BCNF Normalization**: We will review your `BCNF_Proofs.md` and the PDF. We'll discuss *why* BCNF is used here, scenarios where you might intentionally *denormalize* for performance, and the trade-offs.
- **ISA Hierarchies**: Deep dive into how you modeled `INVESTOR` and `SECURITY`. We'll discuss alternative approaches (Single Table Inheritance vs. Class Table Inheritance) and why you chose your approach in PostgreSQL.
- **Constraints and Integrity**: Analyzing your conditional check constraints and partial unique indexes. Why not handle these in the application layer?

### Phase 2: Schema and Business Logic (Triggers vs. Application Layer)
- **Triggers**: You have 9 triggers (e.g., `trg_validate_order`, `trg_trade_update_holdings`). We will evaluate the pros and cons of placing this much business logic inside the database. A senior engineer will likely challenge you on this (e.g., "What happens to scalability when triggers handle all logic?").
- **Transaction Management**: Discussing how deposits, withdrawals, and trade executions maintain ACID properties, especially dealing with concurrency and race conditions.

### Phase 3: Query Optimization and Performance (The 30 Queries)
- **Performance**: We will review your `indexes.sql` and `docs/PERFORMANCE.md` (if it contains relevant info).
- **Execution Plans**: We will discuss how PostgreSQL executes complex joins and aggregations in your analytical queries (e.g., Broker performance, dormant investors) and how to optimize them using `EXPLAIN ANALYZE`.
- **Views**: The performance implications of your 7 views.

### Phase 4: Financial Domain Expertise
- **Order Types**: Ensure crystal-clear understanding of MARKET, LIMIT, SL (Stop-Loss), and SL-M (Stop-Loss Market) orders.
- **P&L and Taxation**: Realized vs. Unrealized P&L, STCG (Short-Term Capital Gains), and LTCG (Long-Term Capital Gains), and how they are calculated in your system.
- **KYC & Broker Lifecycle**: The real-world flows for these entities.

### Phase 5: Mock Interview (The "Grilling")
- **Interactive Q&A**: I will act as a 5+ YOE interviewer and ask you tough architectural, domain, and "what-if" scaling questions based on your system. We can do this interactively here or you can use the `/grill-me` command later.

## Next Steps
Once you approve this plan, I will start by summarizing Phase 1 for you, posing some advanced questions for us to discuss!

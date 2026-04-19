# Project Notes

## Day 1 — 2026-04-18
- Dataset: CMS Medicare Physician & Other Practitioners by Provider and Service, 2023
- 9,660,647 rows loaded to raw_provider_service
- 1.17M unique providers, 6,405 procedures, 62 states/territories, 104 specialties
- Zero NULLs in key columns — unusually clean
- Split: 94.4% Individual providers, 5.6% Organizations
- KEY DECISION: Outlier analysis will use Individuals only (I) — mixing with Orgs (O) 
  would create false outliers due to different billing norms
- Indexes added: NPI, HCPCS, state, provider type

## Day 2 — 2026-04-19

### Infrastructure
- Installed dbt Core 1.11, connected to medicare_claims DB
- Built staging layer: stg_provider_service (filter to Individuals, 9.12M rows)
- Built first mart: mart_top_procedures_by_spend (5,661 procedures ranked)

### Key findings — Business Question #1: Cost drivers
1. Total Medicare spend (individual providers): ~$73.4B
2. Spending is extremely concentrated:
   - 24 procedures (0.42%) = 50% of spend
   - 166 procedures (2.9%) = 80% of spend  
   - 621 procedures (11%) = 95% of spend
3. Top 10 is dominated by E/M visits (99213, 99214, etc.) — high volume, not high unit cost
4. Two drugs break into top 10: aflibercept (Eylea, eye injection) and pembrolizumab (Keytruda, cancer)
5. Drugs = 8% of procedure codes but 16.5% of spend (2x over-indexed)

### Implication for analysis
- Provider outlier analysis (BQ#2) should focus on the top 100-200 procedures 
  where benchmarking has statistical power
- Geographic variation (BQ#3) most meaningful on the top ~50 procedures
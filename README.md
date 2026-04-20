\# Medicare Claims Cost Analysis



\*\*An analysis of 9.66 million rows of CMS Medicare provider claims data to identify cost drivers, provider outliers, geographic payment variation, and estimate the dollar impact of three targeted interventions.\*\*



🔗 \*\*\[View Interactive Dashboard on Tableau Public →](https://public.tableau.com/app/profile/akshitha.a2492/viz/MedicareClaimsCostAnalysis2023/Dashboard1)\*\*



!\[Dashboard Preview](images/dashboard\_preview.png)



\---



\## TL;DR



\- Analyzed \*\*9.12M individual-provider claim rows\*\* from CMS Medicare 2023 data (\~$73B in spend)

\- Found \*\*24 procedures drive 50% of total Medicare spend\*\* — extreme concentration

\- Flagged \*\*277K provider-procedure outliers\*\* using specialty+state peer benchmarking  

\- Identified \*\*15× geographic variation\*\* in nuclear medicine payments (after geographic cost adjustment)

\- Modeled three interventions totaling \*\*\~$801M in estimated annual savings potential\*\*



\---



\## The Business Questions



| # | Question | Key Finding |

|---|---|---|

| 1 | What drives Medicare spending? | 24 of 5,661 procedures = 50% of all spend |

| 2 | Which providers are statistical outliers? | 277K flagged; over-utilization drives 2.5× more cost impact than over-billing |

| 3 | How much does payment vary geographically? | Nuclear imaging shows up to 15× variation across states (standardized) |

| 4 | What's the ROI of targeted interventions? | \~$801M/year combined from 3 modeled interventions |



\---



\## Tech Stack



\- \*\*PostgreSQL 17\*\* — data warehouse (9.66M rows loaded via `\\copy`)

\- \*\*dbt Core\*\* — transformation layer (staging → marts architecture)

\- \*\*Python / pandas\*\* — exploratory analysis

\- \*\*Tableau Public\*\* — interactive dashboard

\- \*\*Git / GitHub\*\* — version control



\---



\## Data Architecture



raw\_provider\_service (9.66M rows)

↓

stg\_provider\_service         ← filters to individual providers (9.12M rows)

↓

mart\_top\_procedures\_by\_spend ← ranks procedures by total Medicare spend

↓

mart\_top\_100\_procedures      ← scopes downstream analysis

↓

├─ mart\_provider\_outliers    ← z-score-based flagging (277K rows)

├─ mart\_geographic\_variation ← state-level payment comparison

└─ mart\_intervention\_roi     ← executive savings estimates



Every mart uses dbt's `ref()` for full lineage. When CMS releases 2024 data, `dbt run` refreshes the entire pipeline.



\---



\## Methodology Highlights



\*\*Provider outlier detection\*\* — peer group defined as specialty + state + HCPCS code, requiring ≥10 peers for statistical validity. Flagged providers > 2 standard deviations above the mean on either `services\_per\_beneficiary` (over-utilization) or `avg\_submitted\_charge` (over-billing).



\*\*Geographic variation analysis\*\* — used CMS's `avg\_medicare\_standardized` payment field (which removes Geographic Practice Cost Index adjustments) to isolate \*unwarranted\* variation from cost-of-living differences.



\*\*Intervention ROI modeling\*\* — used published industry assumptions for recovery rates (15% for targeted audits per CMS RAC program norms; 10% for prior authorization per peer-reviewed health services research) rather than ad-hoc guesses. Assumptions are transparent in the SQL and the final mart.



\---



\## Top Insights



\*\*1. Medicare spending is extraordinarily concentrated\*\*  

24 procedures (0.42% of codes) account for 50% of total spend. 166 procedures (2.9%) account for 80%. Cost-control interventions should be narrowly targeted, not broad-based.



\*\*2. Volume drives more cost impact than charge inflation\*\*  

`HIGH VOLUME` outlier flag covers $4.09B in flagged spend; `HIGH CHARGE` covers only $1.62B. Medicare's fee schedules constrain charge inflation, so over-utilization is the real cost lever.



\*\*3. Nuclear medicine shows 15× payment variation between states\*\*  

On the geographically-standardized basis, HCPCS 78431 (nuclear cardiac blood flow study) shows a 15.14× gap between the 10th and 90th percentile states — pure billing-pattern variance, not cost-of-living.



\*\*4. Drug vs procedure variation is a story about regulation\*\*  

Drugs show 1-2% payment variation across states (Average Sales Price regulation works). Procedures show 2-15× variation. A policy lesson on what standardization achieves.



\---



\## Repository Structure



medicare-claims-analysis/

├── README.md

├── .gitignore

├── requirements.txt

├── medicare\_dbt/                  # dbt project

│   ├── dbt\_project.yml

│   └── models/

│       ├── staging/

│       │   └── stg\_provider\_service.sql

│       └── marts/

│           └── cost\_analysis/

│               ├── mart\_top\_procedures\_by\_spend.sql

│               ├── mart\_top\_100\_procedures.sql

│               ├── mart\_provider\_outliers.sql

│               ├── mart\_geographic\_variation.sql

│               └── mart\_intervention\_roi.sql

├── tableau\_exports/               # CSVs for Tableau Public (not tracked)

└── images/

└── dashboard\_preview.png



\---



\## Data Source



CMS Medicare Physician \& Other Practitioners — by Provider and Service (2023). Public Use File.  

\[data.cms.gov](https://data.cms.gov/provider-summary-by-type-of-service/medicare-physician-other-practitioners/medicare-physician-other-practitioners-by-provider-and-service)



\---



\## About



Built by \*\*Akshitha Addagatla\*\* as part of a 3-project data analytics portfolio focused on high-hiring-volume domains (healthcare, finance, e-commerce). This is Project 2 of 3.



\*\*Caveats:\*\* Savings estimates use published industry recovery rates, not actuarial modeling. Real-world recovery rates vary by procedure type and provider behavior. Drug codes were not excluded from outlier analysis. Analysis scoped to individual providers; organizational billing patterns differ and are not benchmarked here.


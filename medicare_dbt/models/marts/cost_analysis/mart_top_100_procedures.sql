-- Mart: Top 100 HCPCS procedures by Medicare spend
-- Used as the scope filter for downstream outlier analysis
-- Reduces 5,661 procedures to the 100 that drive ~75% of total spend

select
    hcpcs_code,
    hcpcs_description,
    is_drug,
    total_services,
    total_medicare_spend,
    spend_rank,
    pct_of_total_spend,
    cumulative_pct_of_spend
from {{ ref('mart_top_procedures_by_spend') }}
where spend_rank <= 100
order by spend_rank
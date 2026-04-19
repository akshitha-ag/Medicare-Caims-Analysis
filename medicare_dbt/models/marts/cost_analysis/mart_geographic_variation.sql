-- Mart: Geographic variation in Medicare payments by procedure and state
-- Methodology:
--   For each HCPCS procedure in the top 100 by spend, calculate:
--     - Mean/min/max/p90/p10 of avg Medicare payment across states
--     - State-level ranking (which states pay most/least)
--     - Variation ratio (p90/p10) — how many times more expensive is the 
--       90th percentile state vs the 10th percentile
--   Use standardized payment amount (removes GPCI) to isolate UNWARRANTED variation
--   Require minimum 20 providers per state-procedure combo for data stability

with state_procedure_stats as (
    select
        s.hcpcs_code,
        s.hcpcs_description,
        s.state,
        count(distinct s.provider_npi)              as providers_in_state,
        sum(s.total_services)                       as total_services,
        sum(s.total_beneficiaries)                  as total_beneficiaries,
        sum(s.total_medicare_spend)                 as total_medicare_spend,
        avg(s.avg_medicare_payment)                 as avg_payment_raw,
        avg(s.avg_medicare_standardized)            as avg_payment_standardized,
        avg(s.avg_submitted_charge)                 as avg_submitted_charge
    from {{ ref('stg_provider_service') }} s
    inner join {{ ref('mart_top_100_procedures') }} t
        on s.hcpcs_code = t.hcpcs_code
    group by s.hcpcs_code, s.hcpcs_description, s.state
    having count(distinct s.provider_npi) >= 20
),

procedure_benchmarks as (
    -- Calculate national benchmarks for each procedure
    select
        hcpcs_code,
        avg(avg_payment_raw)                        as national_avg_payment_raw,
        avg(avg_payment_standardized)               as national_avg_payment_stdzd,
        min(avg_payment_standardized)               as min_state_stdzd,
        max(avg_payment_standardized)               as max_state_stdzd,
        percentile_cont(0.10) within group (order by avg_payment_standardized) 
                                                    as p10_state_stdzd,
        percentile_cont(0.50) within group (order by avg_payment_standardized) 
                                                    as median_state_stdzd,
        percentile_cont(0.90) within group (order by avg_payment_standardized) 
                                                    as p90_state_stdzd,
        count(distinct state)                       as states_covered
    from state_procedure_stats
    group by hcpcs_code
),

final as (
    select
        sp.hcpcs_code,
        sp.hcpcs_description,
        sp.state,
        sp.providers_in_state,
        sp.total_services,
        sp.total_medicare_spend,
        round(sp.avg_payment_raw::numeric, 2)                as state_avg_payment_raw,
        round(sp.avg_payment_standardized::numeric, 2)       as state_avg_payment_stdzd,
        round(pb.national_avg_payment_stdzd::numeric, 2)     as national_avg_stdzd,
        round(pb.p10_state_stdzd::numeric, 2)                as p10_national_stdzd,
        round(pb.p90_state_stdzd::numeric, 2)                as p90_national_stdzd,
        -- How does this state compare to national p10/p90 on standardized basis?
        round(
            (100.0 * (sp.avg_payment_standardized - pb.national_avg_payment_stdzd) 
                  / nullif(pb.national_avg_payment_stdzd, 0))::numeric,
            2
        )                                                    as pct_diff_from_national,
        -- How much variation exists nationally for this procedure?
        round(
            (pb.p90_state_stdzd / nullif(pb.p10_state_stdzd, 0))::numeric,
            2
        )                                                    as national_p90_p10_ratio,
        pb.states_covered,
        -- Rank state within procedure from cheapest (1) to most expensive
        row_number() over (
            partition by sp.hcpcs_code 
            order by sp.avg_payment_standardized asc
        )                                                    as state_rank_low_to_high
    from state_procedure_stats sp
    join procedure_benchmarks pb on sp.hcpcs_code = pb.hcpcs_code
)

select * from final
order by hcpcs_code, state_rank_low_to_high
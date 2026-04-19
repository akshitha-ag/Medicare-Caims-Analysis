-- Mart: Estimated ROI of three Medicare cost-reduction interventions
-- Combines findings from BQ#1 (cost drivers), BQ#2 (outliers), BQ#3 (geo variation)
-- Produces per-intervention savings estimates with transparent assumptions

with intervention_a_audit as (
    -- Intervention A: Targeted audit of HIGH VOLUME + HIGH CHARGE outliers
    -- Assumption: 15% recovery rate (industry norm for concentrated audits)
    -- Source: CMS RAC program recovers 8-25% of audited claims
    select
        'A: Targeted Provider Audit' as intervention,
        'Audit 4,753 dual-flagged outliers (HIGH VOL + HIGH CHARGE)' as description,
        count(*) as providers_targeted,
        sum(total_medicare_spend) as flagged_spend,
        round(sum(total_medicare_spend) * 0.15, 0) as estimated_recovery_15pct,
        round(count(*) * 1500.0, 0) as estimated_audit_cost,
        round(sum(total_medicare_spend) * 0.15 - count(*) * 1500.0, 0) as net_savings
    from {{ ref('mart_provider_outliers') }}
    where outlier_flag = 'HIGH VOLUME + HIGH CHARGE'
),

intervention_b_geo_standardize as (
    -- Intervention B: Standardize payment on top-variation procedures
    -- Assumption: Cap high-state payments at national median
    -- Method: Calculate overpayment = (state avg - national median) × services
    -- Focus: Top 20 highest-variation procedures (>=2x P90/P10 ratio)
    select
        'B: Geographic Payment Standardization' as intervention,
        'Cap payments on 20 highest-variation procedures at national median' as description,
        count(distinct mgv.hcpcs_code) as procedures_affected,
        sum(mgv.total_medicare_spend) as affected_spend,
        round(
            sum(
                case 
                    when mgv.state_avg_payment_stdzd > mgv.national_avg_stdzd
                    then (mgv.state_avg_payment_stdzd - mgv.national_avg_stdzd) * mgv.total_services
                    else 0
                end
            ),
            0
        ) as estimated_recovery,
        0 as estimated_audit_cost,  -- Policy change, not audit
        round(
            sum(
                case 
                    when mgv.state_avg_payment_stdzd > mgv.national_avg_stdzd
                    then (mgv.state_avg_payment_stdzd - mgv.national_avg_stdzd) * mgv.total_services
                    else 0
                end
            ),
            0
        ) as net_savings
    from {{ ref('mart_geographic_variation') }} mgv
    where mgv.hcpcs_code in (
        select distinct hcpcs_code 
        from {{ ref('mart_geographic_variation') }}
        where national_p90_p10_ratio >= 2.0
    )
),

intervention_c_prior_auth as (
    -- Intervention C: Prior authorization on top over-utilized procedures
    -- Assumption: 10% reduction in services on high-volume outliers (conservative)
    -- Prior auth typically reduces volume 5-15% per peer-reviewed healthcare research
    select
        'C: Prior Authorization (Volume Reduction)' as intervention,
        'Prior auth on top procedures with HIGH VOLUME outliers' as description,
        count(*) as providers_targeted,
        sum(total_medicare_spend) as flagged_spend,
        round(sum(total_medicare_spend) * 0.10, 0) as estimated_recovery_10pct,
        round(count(*) * 50.0, 0) as estimated_audit_cost,  -- $50/auth admin cost
        round(sum(total_medicare_spend) * 0.10 - count(*) * 50.0, 0) as net_savings
    from {{ ref('mart_provider_outliers') }}
    where outlier_flag = 'HIGH VOLUME'
),

all_interventions as (
    select 
        intervention,
        description,
        providers_targeted as targets,
        flagged_spend as scope_dollars,
        estimated_recovery_15pct as estimated_recovery,
        estimated_audit_cost,
        net_savings
    from intervention_a_audit
    
    union all
    
    select 
        intervention,
        description,
        procedures_affected as targets,
        affected_spend as scope_dollars,
        estimated_recovery,
        estimated_audit_cost,
        net_savings
    from intervention_b_geo_standardize
    
    union all
    
    select 
        intervention,
        description,
        providers_targeted as targets,
        flagged_spend as scope_dollars,
        estimated_recovery_10pct as estimated_recovery,
        estimated_audit_cost,
        net_savings
    from intervention_c_prior_auth
)

select 
    intervention,
    description,
    targets,
    round(scope_dollars, 0) as scope_dollars,
    estimated_recovery,
    estimated_audit_cost,
    net_savings,
    round(100.0 * net_savings / nullif(scope_dollars, 0), 2) as savings_as_pct_of_scope,
    row_number() over (order by net_savings desc) as priority_rank
from all_interventions
order by net_savings desc
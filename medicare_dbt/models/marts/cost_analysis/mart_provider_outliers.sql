-- Mart: Provider outliers on top-spend procedures
-- Methodology:
--   Peer group = providers of same specialty in same state doing the same procedure
--   Metrics examined:
--     1. services_per_beneficiary (potential over-utilization)
--     2. avg_submitted_charge (potential charge inflation)
--   Flagged if >2 standard deviations above peer group mean
--   Requires minimum peer group size of 10 for statistical validity

with filtered as (
    -- Scope to individual providers on top-100 spend procedures only
    select
        s.provider_npi,
        s.provider_last_name,
        s.provider_first_name,
        s.specialty,
        s.state,
        s.hcpcs_code,
        s.hcpcs_description,
        s.total_beneficiaries,
        s.total_services,
        s.avg_submitted_charge,
        s.avg_medicare_payment,
        s.total_medicare_spend,
        -- Services per unique patient
        case 
            when s.total_beneficiaries > 0 
            then s.total_services / s.total_beneficiaries 
            else null 
        end as services_per_beneficiary
    from {{ ref('stg_provider_service') }} s
    inner join {{ ref('mart_top_100_procedures') }} t
        on s.hcpcs_code = t.hcpcs_code
),

peer_stats as (
    -- Calculate mean and std dev within each specialty+state+procedure peer group
    select
        *,
        count(*) over (
            partition by specialty, state, hcpcs_code
        ) as peer_group_size,
        avg(services_per_beneficiary) over (
            partition by specialty, state, hcpcs_code
        ) as peer_avg_services_per_bene,
        stddev(services_per_beneficiary) over (
            partition by specialty, state, hcpcs_code
        ) as peer_stddev_services_per_bene,
        avg(avg_submitted_charge) over (
            partition by specialty, state, hcpcs_code
        ) as peer_avg_charge,
        stddev(avg_submitted_charge) over (
            partition by specialty, state, hcpcs_code
        ) as peer_stddev_charge
    from filtered
),

with_zscores as (
    -- Calculate z-scores: how many std devs above the peer mean
    select
        *,
        case
            when peer_stddev_services_per_bene > 0
            then (services_per_beneficiary - peer_avg_services_per_bene) / peer_stddev_services_per_bene
            else 0
        end as zscore_services_per_bene,
        case
            when peer_stddev_charge > 0
            then (avg_submitted_charge - peer_avg_charge) / peer_stddev_charge
            else 0
        end as zscore_charge
    from peer_stats
    where peer_group_size >= 10  -- Need sufficient peers for statistical validity
)

select
    provider_npi,
    provider_last_name,
    provider_first_name,
    specialty,
    state,
    hcpcs_code,
    hcpcs_description,
    peer_group_size,
    total_beneficiaries,
    total_services,
    round(services_per_beneficiary, 2) as services_per_beneficiary,
    round(peer_avg_services_per_bene, 2) as peer_avg_services_per_bene,
    round(zscore_services_per_bene, 2) as zscore_services_per_bene,
    round(avg_submitted_charge, 2) as avg_submitted_charge,
    round(peer_avg_charge, 2) as peer_avg_charge,
    round(zscore_charge, 2) as zscore_charge,
    round(total_medicare_spend, 0) as total_medicare_spend,
    -- Flag classification
    case 
        when zscore_services_per_bene > 2 and zscore_charge > 2 then 'HIGH VOLUME + HIGH CHARGE'
        when zscore_services_per_bene > 2 then 'HIGH VOLUME'
        when zscore_charge > 2 then 'HIGH CHARGE'
        else 'normal'
    end as outlier_flag
from with_zscores
where zscore_services_per_bene > 2 or zscore_charge > 2
order by total_medicare_spend desc
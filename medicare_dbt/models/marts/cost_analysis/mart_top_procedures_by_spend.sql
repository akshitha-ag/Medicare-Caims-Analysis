-- Mart: Top Medicare procedures ranked by total spend
-- Business question: Which HCPCS procedures drive the most Medicare spending?
-- Uses individual-provider-only data from staging layer

with procedure_spend as (
    select
        hcpcs_code,
        hcpcs_description,
        is_drug,
        count(distinct provider_npi)        as providers_performing,
        sum(total_beneficiaries)            as total_beneficiaries,
        sum(total_services)                 as total_services,
        sum(total_medicare_spend)           as total_medicare_spend,
        sum(total_submitted_charges)        as total_submitted_charges,
        avg(avg_medicare_payment)           as avg_payment_per_service
    from {{ ref('stg_provider_service') }}
    where total_medicare_spend is not null
    group by hcpcs_code, hcpcs_description, is_drug
),

ranked as (
    select
        *,
        row_number() over (order by total_medicare_spend desc) as spend_rank,
        round(
            100.0 * total_medicare_spend / sum(total_medicare_spend) over (),
            4
        )                                                       as pct_of_total_spend,
        round(
            100.0 * sum(total_medicare_spend) over (order by total_medicare_spend desc) 
                / sum(total_medicare_spend) over (),
            4
        )                                                       as cumulative_pct_of_spend
    from procedure_spend
)

select * from ranked
order by spend_rank
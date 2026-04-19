-- Staging model for CMS Medicare Provider & Service data
-- Filters to individual providers only (excludes organizations)
-- Adds derived columns for downstream analysis

with source as (
    select * from public.raw_provider_service
),

cleaned as (
    select
        -- Identifiers
        rndrng_npi                          as provider_npi,
        rndrng_prvdr_last_org_name          as provider_last_name,
        rndrng_prvdr_first_name             as provider_first_name,
        rndrng_prvdr_crdntls                as provider_credentials,
        rndrng_prvdr_ent_cd                 as entity_code,
        
        -- Location
        rndrng_prvdr_city                   as city,
        rndrng_prvdr_state_abrvtn           as state,
        rndrng_prvdr_zip5                   as zip_code,
        rndrng_prvdr_ruca_desc              as rural_urban_classification,
        
        -- Provider attributes
        rndrng_prvdr_type                   as specialty,
        rndrng_prvdr_mdcr_prtcptg_ind       as medicare_participating,
        
        -- Procedure info
        hcpcs_cd                            as hcpcs_code,
        hcpcs_desc                          as hcpcs_description,
        hcpcs_drug_ind                      as is_drug,
        place_of_srvc                       as place_of_service,
        
        -- Volume metrics
        tot_benes                           as total_beneficiaries,
        tot_srvcs                           as total_services,
        tot_bene_day_srvcs                  as total_bene_day_services,
        
        -- Financial metrics
        avg_sbmtd_chrg                      as avg_submitted_charge,
        avg_mdcr_alowd_amt                  as avg_medicare_allowed,
        avg_mdcr_pymt_amt                   as avg_medicare_payment,
        avg_mdcr_stdzd_amt                  as avg_medicare_standardized,
        
        -- Derived: total spend for this provider/procedure combination
        (tot_srvcs * avg_mdcr_pymt_amt)     as total_medicare_spend,
        (tot_srvcs * avg_sbmtd_chrg)        as total_submitted_charges
        
    from source
    where rndrng_prvdr_ent_cd = 'I'         -- Individual providers only
)

select * from cleaned
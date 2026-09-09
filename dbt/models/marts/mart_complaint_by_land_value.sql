with business_complaints as (
    select * from {{ ref('mart_business_complaint_per_zip') }}
),
 
neighborhood as (
    select * from {{ ref('mart_resident_units') }}
)
 
select
    coalesce(bc.zip_code, n.zip_code) as zip_code,
    coalesce(bc.borough, n.borough)   as borough,
    bc.active_license_count,
    bc.complaint_count,
    bc.complaints_per_business,
    n.tax_lot_count,
    n.avg_year_built,
    n.avg_assessed_total_value,
    n.total_residential_units
from business_complaints bc
full outer join neighborhood n
    on bc.zip_code = n.zip_code
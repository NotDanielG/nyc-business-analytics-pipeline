with businesses as (
    select * from {{ ref('mart_business_density_by_zip') }}
),

complaints as (
    select * from {{ ref('mart_complaints_by_zip') }}
)

select
    coalesce(b.zip_code, c.zip_code) as zip_code,
    coalesce(b.borough, c.borough)   as borough,
    coalesce(b.active_license_count, 0) as active_license_count,
    coalesce(c.complaint_count, 0)      as complaint_count,
    case
        when coalesce(b.active_license_count, 0) = 0 then null
        else round(c.complaint_count / b.active_license_count, 2)
    end as complaints_per_business
from businesses b
full outer join complaints c
    on b.zip_code = c.zip_code

with licenses as (
    select * from {{ ref('stg_issued_licenses') }}
    where license_status = 'Active'
      and zip_code is not null
)

select
    zip_code,
    borough,
    count(distinct business_id) as active_license_count
from licenses
group by 1, 2

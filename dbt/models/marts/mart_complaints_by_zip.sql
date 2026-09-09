with requests as (
    select * from {{ ref('stg_311_requests') }}
    where zip_code is not null
)

select
    zip_code,
    borough,
    count(*) as complaint_count,
    count(distinct complaint_type) as distinct_complaint_types
from requests
group by 1, 2

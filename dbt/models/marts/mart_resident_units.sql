with lots as (
    select * from {{ ref('stg_pluto') }}
    where zip_code is not null
)
select
    zip_code,
    borough,
    count(*)                              as tax_lot_count,
    avg(year_built)                       as avg_year_built,
    avg(assessed_total_value)             as avg_assessed_total_value,
    sum(residential_units)                as total_residential_units
from lots
group by 1, 2
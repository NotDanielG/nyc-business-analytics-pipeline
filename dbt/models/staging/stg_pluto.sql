{{
    config(
        materialized='incremental',
        unique_key='bbl',
        incremental_strategy='merge'
    )
}}
with source as (
    select
        bbl,
        zipcode,
        borough,
        yearbuilt,
        landuse,
        bldgclass,
        numfloors,
        unitstotal,
        unitsres,
        assessland,
        assesstot,
        latitude,
        longitude,
        partition_0
    from {{ source('raw', 'pluto') }}
    {% if is_incremental() %}
    where try_cast(partition_0 as integer) > (select max(extract_date) from {{ this }})
    {% endif %}
),
 
renamed as (
    select
        bbl::varchar                    as bbl,
        nullif(regexp_replace(zipcode, '[^0-9]', ''), '')::varchar(5) as zip_code,
        case upper(borough)
            when 'MN' then 'MANHATTAN'
            when 'BX' then 'BRONX'
            when 'BK' then 'BROOKLYN'
            when 'QN' then 'QUEENS'
            when 'SI' then 'STATEN ISLAND'
            else upper(borough)
        end                              as borough,
        try_cast(yearbuilt as integer)   as year_built,
        landuse::varchar                 as land_use_code,
        bldgclass::varchar               as building_class,
        try_cast(numfloors as float8)    as floor_count,
        try_cast(unitstotal as integer)  as total_units,
        try_cast(unitsres as integer)    as residential_units,
        try_cast(assessland as float8)   as assessed_land_value,
        try_cast(assesstot as float8)    as assessed_total_value,
        try_cast(latitude as float8)     as latitude,
        try_cast(longitude as float8)    as longitude,
        try_cast(partition_0 as integer) as extract_date
    from source
)
 
select * from renamed
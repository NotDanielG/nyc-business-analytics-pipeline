
with source as (
    select * from {{ source('raw', 'issued_licenses') }}
),

renamed as (
    select
        license_nbr::varchar                as license_number,
        business_unique_id::varchar         as business_id,
        business_name::varchar              as business_name,
        nullif(dba_trade_name, '')::varchar as dba_name,
        business_category::varchar          as license_category,
        license_type::varchar               as license_type,
        license_status::varchar             as license_status,
        try_cast(license_creation_date as date) as license_created_date,
        try_cast(lic_expir_dd as date)          as license_expiration_date,
        address_building::varchar           as address_building,
        address_street_name::varchar        as address_street,
        address_city::varchar               as address_city,
        address_state::varchar              as address_state,
        nullif(regexp_replace(address_zip, '[^0-9]', ''), '')::varchar(5) as zip_code,
        address_borough::varchar            as borough,
        try_cast(latitude as float8)        as latitude,
        try_cast(longitude as float8)       as longitude,
        try_cast(partition_0 as integer)       as extract_date
    from source
)
select * from renamed
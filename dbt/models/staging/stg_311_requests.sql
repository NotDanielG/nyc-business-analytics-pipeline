{{
    config(
        materialized='incremental',
        unique_key='request_id',
        incremental_strategy='merge'
    )
}}

with source as (
    select
        unique_key,
        created_date,
        closed_date,
        agency,
        agency_name,
        complaint_type,
        descriptor,
        incident_zip,
        borough,
        status,
        latitude,
        longitude,
        partition_0
    from {{ source('raw', '311_service_request') }}
    {% if is_incremental() %}
    where try_cast(partition_0 as integer) > (select max(extract_date) from {{ this }})
    {% endif %}
),
renamed as (
    select
        unique_key::varchar                     as request_id,
        try_cast(created_date as timestamp)     as created_at,
        try_cast(closed_date as timestamp)      as closed_at,
        agency::varchar                         as agency,
        agency_name::varchar                    as agency_name,
        complaint_type::varchar                 as complaint_type,
        descriptor::varchar                     as complaint_descriptor,
        nullif(regexp_replace(incident_zip, '[^0-9]', ''), '')::varchar(5) as zip_code,
        borough::varchar                        as borough,
        status::varchar                         as request_status,
        try_cast(latitude as float8)            as latitude,
        try_cast(longitude as float8)           as longitude,
        try_cast(partition_0 as integer)           as extract_date
    from source
)
select * from renamed

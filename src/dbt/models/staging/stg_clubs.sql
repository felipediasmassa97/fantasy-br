{{ config(materialized='view') }}

select
    id,
    abreviacao as abbreviation,
    nome_fantasia as name,
from {{ source('cartola', 'raw_clubs') }}

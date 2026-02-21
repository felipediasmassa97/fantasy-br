{{ config(materialized='view') }}

select
    id,
    abreviacao as abbreviation,
    nome_fantasia as name,
    escudos.`60x60` as logo_url
from {{ source('cartola', 'raw_clubs') }}

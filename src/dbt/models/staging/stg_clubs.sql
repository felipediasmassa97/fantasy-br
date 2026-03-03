select
    id,
    abreviacao as abbreviation,
    nome_fantasia as label,
    escudos.`60x60` as logo_url
from {{ source('cartola', 'raw_clubs') }}

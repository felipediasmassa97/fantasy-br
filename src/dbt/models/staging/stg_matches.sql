select
    temporada as season,
    rodada_id as round_id,
    partida_id as match_id,
    clube_casa_id as club_home_id,
    clube_visitante_id as club_away_id
from {{ source('cartola', 'raw_matches') }}

{{ config(materialized='view') }}

select
    m.temporada as season,
    m.rodada_id as round_id,
    m.partida_id as match_id,
    m.clube_casa_id as club_home_id,
    m.clube_visitante_id as club_away_id,
    home.nome_fantasia as club_home_name,
    away.nome_fantasia as club_away_name
from {{ source('cartola', 'raw_matches') }} m
left join {{ source('cartola', 'raw_clubs') }} home on m.clube_casa_id = home.id
left join {{ source('cartola', 'raw_clubs') }} away on m.clube_visitante_id = away.id

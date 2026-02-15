{{ config(materialized='view') }}

select
    temporada as season,
    rodada_id as round_id,
    atleta_id as id,
    apelido as name,
    clube_id as club_id,
    posicao_id as position_id,
    pontos_num as pts_round,
    media_num as pts_avg,
    entrou_em_campo as has_played,
    jogos_num as matches_played,
    scout
from {{ source('cartola', 'raw_players') }}

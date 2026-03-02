with raw_players_etl as (
    select
        temporada as season,
        rodada_id as round_id,
        cast(atleta_id as int64) as id,
        apelido as player_name,
        clube_id as club_id,
        posicao_id as position_id,
        pontos_num as pts_round,
        media_num as pts_avg,
        entrou_em_campo as has_played,
        jogos_num as matches_played,
        scout
    from {{ source('cartola', 'raw_players_etl') }}
),

raw_players_legacy_2025 as (
    select
        temporada as season,
        rodada_id as round_id,
        cast(atleta_id as int64) as id,
        apelido as player_name,
        clube_id as club_id,
        posicao_id as position_id,
        pontos_num as pts_round,
        media_num as pts_avg,
        entrou_em_campo as has_played,
        jogos_num as matches_played,
        struct(
            cast(gc as int64) as gc,
            cast(v as int64) as v,
            cast(ps as int64) as ps,
            cast(ff as int64) as ff,
            cast(sg as int64) as sg,
            cast(dp as int64) as dp,
            cast(ft as int64) as ft,
            cast(cv as int64) as cv,
            cast(gs as int64) as gs,
            cast(fs as int64) as fs,
            cast(i as int64) as i,
            cast(pc as int64) as pc,
            cast(ca as int64) as ca,
            cast(de as int64) as de,
            cast(g as int64) as g,
            cast(fd as int64) as fd,
            cast(a as int64) as a,
            cast(pp as int64) as pp,
            cast(fc as int64) as fc,
            cast(ds as int64) as ds
        ) as scout
    from {{ ref('raw_players_legacy_2025') }}
),

raw_players_legacy_2026 as (
    select
        temporada as season,
        rodada_id as round_id,
        cast(atleta_id as int64) as id,
        apelido as player_name,
        clube_id as club_id,
        posicao_id as position_id,
        pontos_num as pts_round,
        media_num as pts_avg,
        entrou_em_campo as has_played,
        jogos_num as matches_played,
        struct(
            cast(gc as int64) as gc,
            cast(v as int64) as v,
            cast(ps as int64) as ps,
            cast(ff as int64) as ff,
            cast(sg as int64) as sg,
            cast(dp as int64) as dp,
            cast(ft as int64) as ft,
            cast(cv as int64) as cv,
            cast(gs as int64) as gs,
            cast(fs as int64) as fs,
            cast(i as int64) as i,
            cast(pc as int64) as pc,
            cast(ca as int64) as ca,
            cast(de as int64) as de,
            cast(g as int64) as g,
            cast(fd as int64) as fd,
            cast(a as int64) as a,
            cast(pp as int64) as pp,
            cast(fc as int64) as fc,
            cast(ds as int64) as ds
        ) as scout
    from {{ ref('raw_players_legacy_2026') }}
),

unioned as (
    select * from raw_players_etl
    union all
    select * from raw_players_legacy_2025
    union all
    select * from raw_players_legacy_2026
)

select *
from unioned
where position_id != 6  -- exclude head coaches

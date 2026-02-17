{{ config(materialized='view') }}

with raw_players_etl as (
    select
        temporada as season,
        rodada_id as round_id,
        cast(atleta_id as int64) as id,
        apelido as name,
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
        apelido as name,
        clube_id as club_id,
        posicao_id as position_id,
        pontos_num as pts_round,
        media_num as pts_avg,
        entrou_em_campo as has_played,
        jogos_num as matches_played,
        struct(
            cast(GC as int64) as GC,
            cast(V as int64) as V,
            cast(PS as int64) as PS,
            cast(FF as int64) as FF,
            cast(SG as int64) as SG,
            cast(DP as int64) as DP,
            cast(FT as int64) as FT,
            cast(CV as int64) as CV,
            cast(GS as int64) as GS,
            cast(FS as int64) as FS,
            cast(I as int64) as I,
            cast(PC as int64) as PC,
            cast(CA as int64) as CA,
            cast(DE as int64) as DE,
            cast(G as int64) as G,
            cast(FD as int64) as FD,
            cast(A as int64) as A,
            cast(PP as int64) as PP,
            cast(FC as int64) as FC,
            cast(DS as int64) as DS
        ) as scout
    from {{ ref('raw_players_legacy_2025') }}
),

raw_players_legacy_2026 as (
    select
        temporada as season,
        rodada_id as round_id,
        cast(atleta_id as int64) as id,
        apelido as name,
        clube_id as club_id,
        posicao_id as position_id,
        pontos_num as pts_round,
        media_num as pts_avg,
        entrou_em_campo as has_played,
        jogos_num as matches_played,
        struct(
            cast(GC as int64) as GC,
            cast(V as int64) as V,
            cast(PS as int64) as PS,
            cast(FF as int64) as FF,
            cast(SG as int64) as SG,
            cast(DP as int64) as DP,
            cast(FT as int64) as FT,
            cast(CV as int64) as CV,
            cast(GS as int64) as GS,
            cast(FS as int64) as FS,
            cast(I as int64) as I,
            cast(PC as int64) as PC,
            cast(CA as int64) as CA,
            cast(DE as int64) as DE,
            cast(G as int64) as G,
            cast(FD as int64) as FD,
            cast(A as int64) as A,
            cast(PP as int64) as PP,
            cast(FC as int64) as FC,
            cast(DS as int64) as DS
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

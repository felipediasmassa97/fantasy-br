/*
Market Valuation: Round-by-Round Raw (Subtab)

Thin mart: individual round-level data for audit.
Subset of ss_round_by_round columns relevant to market valuation.
*/

select
    round,
    player_name,
    player_id,
    position,
    team,
    points_total,
    points_base,
    goals,
    assists,
    did_play,
    -- Key scouts for context
    scout_FT,
    scout_FD,
    scout_FF,
    scout_FS,
    scout_PS,
    scout_DS,
    scout_SG,
    scout_DE,
    scout_DP,
    scout_FC,
    scout_PC,
    scout_CA,
    scout_CV,
    scout_GC,
    scout_GS,
    scout_I,
    scout_PP
from {{ ref('int_round_by_round') }}

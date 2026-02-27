/*
Start or Sit: Round-by-Round Raw (Subtab)

Thin mart: individual round-level data for audit and analysis.
See int_round_by_round for source logic.
*/

select
    round,
    match_id,
    player_name,
    player_id,
    position,
    team,
    opponent_team,
    is_home,
    points_total,
    points_base,
    goals,
    assists,
    did_play,
    -- Individual scout columns
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

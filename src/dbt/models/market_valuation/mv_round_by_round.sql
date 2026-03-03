/*
Market Valuation: Round-by-Round Raw (Subtab)

Thin mart: individual round-level data for audit.
Subset of ss_round_by_round columns relevant to market valuation.
*/

select
    round,
    player_id,
    player_name,
    position,
    club,
    club_logo_url,
    points_total,
    points_base,
    did_play,
    -- Offensive scouts
    scout_g,
    scout_a,
    scout_ft,
    scout_fd,
    scout_ff,
    scout_fs,
    scout_ps,
    -- Defensive scouts
    scout_ds,
    scout_sg,
    scout_de,
    scout_dp,
    -- Negative scouts
    scout_fc,
    scout_pc,
    scout_ca,
    scout_cv,
    scout_gc,
    scout_gs,
    scout_i,
    scout_pp
from {{ ref('int_round_by_round') }}

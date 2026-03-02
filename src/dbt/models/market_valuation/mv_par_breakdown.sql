/*
Market Valuation: PAR Breakdown & Replacement Level (Subtab)

Thin mart: detailed PAR computation with replacement level context.
*/

select
    b.as_of_round_id,
    b.id as player_id,
    b.player_name,
    b.club,
    b.club_logo_url,
    b.position,
    b.baseline_pts,
    rl.drafted_count as drafted_players_in_position,
    rl.replacement_level as replacement_level_pts,
    b.baseline_pts - rl.replacement_level as par_points,
    -- PAR rank within position
    row_number() over (
        partition by b.as_of_round_id, b.position
        order by b.baseline_pts - rl.replacement_level desc nulls last
    ) as par_rank_pos,
    -- PAR rank general
    row_number() over (
        partition by b.as_of_round_id
        order by b.baseline_pts - rl.replacement_level desc nulls last
    ) as par_rank_gen
from {{ ref('int_baseline') }} as b
inner join {{ ref('int_replacement_levels') }} as rl
    on b.as_of_round_id = rl.as_of_round_id and b.position = rl.position
where b.baseline_pts is not null

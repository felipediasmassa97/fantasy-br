/*
MAP Score: Final Matchup-Adjusted Projection

Joins all MAP components and computes the final projection.
MAP = baseline * form_multiplier * venue_multiplier * mpap_multiplier

Components:
  - Baseline (int_map_baseline): true talent level
  - Form (int_ewm_form): EWM-based recency form, clamped 0.8 - 1.2
  - Venue (int_map_venue): home/away split adjustment, clamped 0.85 - 1.15
  - MPAP (int_map_mpap): opponent matchup adjustment, clamped 0.85 - 1.20

Ranks computed per position and general for each as_of_round.
*/

select
    b.as_of_round_id,
    b.id,
    b.name,
    b.club,
    b.club_logo_url,
    b.position,
    -- Baseline ability
    b.baseline_pts,
    b.baseline_method,
    -- EWM form inputs
    e.ewm_pts,
    e.form_multiplier,
    -- Venue multiplier: pick home or away based on next match
    case
        when o.is_home_next = true then v.home_multiplier
        when o.is_home_next = false then v.away_multiplier
    end as venue_multiplier,
    -- MPAP
    o.mpap_multiplier,
    o.is_home_next,
    o.opponent_id,
    o.opponent_team,
    -- Final MAP score: product of all components (nulls default to 1.0 = no adjustment)
    case
        when b.baseline_pts is null then null
        else
            b.baseline_pts
            * coalesce(e.form_multiplier, 1.0)
            * coalesce(
                case
                    when o.is_home_next = true then v.home_multiplier
                    when o.is_home_next = false then v.away_multiplier
                end,
                1.0
            )
            * coalesce(o.mpap_multiplier, 1.0)
    end as map_score,
    -- Rank within position
    row_number() over (
        partition by b.as_of_round_id, b.position
        order by case
            when b.baseline_pts is null then null
            else
                b.baseline_pts
                * coalesce(e.form_multiplier, 1.0)
                * coalesce(
                    case
                        when o.is_home_next = true then v.home_multiplier
                        when o.is_home_next = false then v.away_multiplier
                    end,
                    1.0
                )
                * coalesce(o.mpap_multiplier, 1.0)
        end desc nulls last
    ) as map_rank_pos,
    -- Rank general
    row_number() over (
        partition by b.as_of_round_id
        order by case
            when b.baseline_pts is null then null
            else
                b.baseline_pts
                * coalesce(e.form_multiplier, 1.0)
                * coalesce(
                    case
                        when o.is_home_next = true then v.home_multiplier
                        when o.is_home_next = false then v.away_multiplier
                    end,
                    1.0
                )
                * coalesce(o.mpap_multiplier, 1.0)
        end desc nulls last
    ) as map_rank_gen
from {{ ref('int_map_baseline') }} as b
left join {{ ref('int_ewm_form') }} as e
    on b.as_of_round_id = e.as_of_round_id and b.id = e.id
left join {{ ref('int_map_venue') }} as v
    on b.as_of_round_id = v.as_of_round_id and b.id = v.id
left join {{ ref('int_map_mpap') }} as o
    on b.as_of_round_id = o.as_of_round_id and b.id = o.id

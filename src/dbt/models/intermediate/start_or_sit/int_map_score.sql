/*
MAP Score: Final Matchup-Adjusted Projection

Joins all MAP components and computes the final projection.
MAP = baseline * form_multiplier * venue_multiplier * mpap_multiplier

Components:
  - Baseline (int_baseline): stabilized points average (true talent level, using shrinkage)
  - Form (int_ewm_form): EWM-based recency form, clamped 0.8 - 1.2
  - Venue (int_home_away): home/away split adjustment, clamped 0.85 - 1.15
  - MPAP (int_map_mpap): opponent matchup adjustment, clamped 0.85 - 1.20

Ranks computed per position and general for each as_of_round.
*/

with with_multipliers as (
    select
        b.as_of_round_id,
        b.id,
        b.name,
        b.club,
        b.club_logo_url,
        b.position,
        -- Baseline ability
        b.baseline_pts,
        b.shrinking_method,
        -- EWM form inputs
        e.ewm_pts,
        e.form_multiplier,
        -- Venue multiplier: pick home or away based on next match
        case
            when o.is_home_next = true then v.multiplier_home
            when o.is_home_next = false then v.multiplier_away
        end as venue_multiplier,
        -- MPAP
        o.mpap_multiplier,
        o.is_home_next,
        o.opponent_id,
        o.opponent_club,
        o.opponent_logo_url
    from {{ ref('int_baseline') }} as b
    left join {{ ref('int_ewm_form') }} as e
        on b.as_of_round_id = e.as_of_round_id and b.id = e.id
    left join {{ ref('int_home_away') }} as v
        on b.as_of_round_id = v.as_of_round_id and b.id = v.id
    left join {{ ref('int_map_mpap') }} as o
        on b.as_of_round_id = o.as_of_round_id and b.id = o.id
)

select
    *,
    -- Final MAP score: product of all components (nulls default to 1.0 = no adjustment)
    case
        when baseline_pts is null then null
        else
            baseline_pts
            * coalesce(form_multiplier, 1.0)
            * coalesce(venue_multiplier, 1.0)
            * coalesce(mpap_multiplier, 1.0)
    end as map_score,
    -- Rank within position
    row_number() over (
        partition by as_of_round_id, position
        order by case
            when baseline_pts is null then null
            else
                baseline_pts
                * coalesce(form_multiplier, 1.0)
                * coalesce(venue_multiplier, 1.0)   
                * coalesce(mpap_multiplier, 1.0)
        end desc nulls last
    ) as map_rank_pos,
    -- Rank general
    row_number() over (
        partition by as_of_round_id
        order by case
            when baseline_pts is null then null
            else
                baseline_pts
                * coalesce(form_multiplier, 1.0)
                * coalesce(venue_multiplier, 1.0)   
                * coalesce(mpap_multiplier, 1.0)
        end desc nulls last
    ) as map_rank_gen
from with_multipliers

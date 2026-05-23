{{ config(materialized='view') }}
/*
Players with Overrides Applied

Applies player_overrides seed values (name, position, club) on top of stg_players.
This is the single source of truth for player data — all downstream models
(intermediate and mart) must reference this model, NOT stg_players.

Override logic:
  - Only non-null seed columns override the original value
  - Null seed columns = original value preserved
  - Coalesce pattern: COALESCE(seed_value, original_value)

Seed column → stg_players field mapping:
  player_overrides.name     → stg_players.player_name
  player_overrides.position → stg_players.position_id (raw position ID: 1-5)
  player_overrides.club     → stg_players.club_id
*/

with overrides as (
    select
        p.season,
        p.round_id,
        p.id,
        coalesce(o.name, p.player_name) as player_name,
        coalesce(o.club, p.club_id) as club_id,
        coalesce(o.position, p.position_id) as position_id,
        p.pts_round,
        p.pts_avg,
        p.has_played,
        p.matches_played,
        p.scout
    from {{ ref('stg_players') }} as p
    left join {{ ref('player_overrides') }} as o on p.id = o.id
)

select * from overrides
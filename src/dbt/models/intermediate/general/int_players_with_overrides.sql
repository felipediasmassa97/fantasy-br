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
  player_overrides.name     → stg_players.player_name  (string, direct)
  player_overrides.position → stg_players.position_id   (stg abbreviation → int ID via stg_positions)
  player_overrides.club     → stg_players.club_id        (stg abbreviation → int ID via stg_clubs)

Position abbreviations (stg_positions.abbreviation): GK, FB, CB, MD, AT, HC
Club abbreviations (stg_clubs.abbreviation): FLU, FLA, CAM, BOT, etc.

Both lookups are case-insensitive via LOWER().
*/

with position_lookup as (
    select lower(abbreviation) as pos_key, id as position_id
    from {{ ref('stg_positions') }}
),

club_lookup as (
    select lower(abbreviation) as club_key, id as club_id
    from {{ ref('stg_clubs') }}
),

overrides as (
    select
        p.season,
        p.round_id,
        p.id,
        coalesce(o.name, p.player_name)                           as player_name,
        coalesce(club_lookup.club_id, p.club_id)                  as club_id,
        coalesce(position_lookup.position_id, p.position_id)      as position_id,
        p.pts_round,
        p.pts_avg,
        p.has_played,
        p.matches_played,
        p.scout
    from {{ ref('stg_players') }} as p
    left join {{ ref('player_overrides') }} as o on p.id = o.id
    left join club_lookup     on lower(o.club)     = club_lookup.club_key
    left join position_lookup on lower(o.position) = position_lookup.pos_key
)

select * from overrides
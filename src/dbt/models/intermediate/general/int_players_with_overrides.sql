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
  player_overrides.position → stg_players.position_id   (raw abbreviation → int ID via raw_positions lookup)
  player_overrides.club     → stg_players.club_id       (TLA → int ID via raw_clubs lookup)

Position abbreviations (raw_positions.abreviacao): gol, lat, zag, mei, ata, tec
Club abbreviations (raw_clubs.abreviacao): FLU, FLA, CAM, BOT, etc.
*/

with position_lookup as (
    select abreviacao, id as position_id
    from {{ ref('raw_positions') }}
),

club_lookup as (
    select abreviacao, id as club_id
    from {{ ref('raw_clubs') }}
),

overrides as (
    select
        p.season,
        p.round_id,
        p.id,
        coalesce(o.name, p.player_name)                              as player_name,
        coalesce(club_lookup.club_id, p.club_id)                    as club_id,
        coalesce(position_lookup.position_id, p.position_id)        as position_id,
        p.pts_round,
        p.pts_avg,
        p.has_played,
        p.matches_played,
        p.scout
    from {{ ref('stg_players') }} as p
    left join {{ ref('player_overrides') }} as o on p.id = o.id
    left join club_lookup     on o.club     = club_lookup.abreviacao
    left join position_lookup on o.position = position_lookup.abreviacao
)

select * from overrides
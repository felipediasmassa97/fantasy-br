select
    season,
    round_id,
    match_id,
    home_team_id,
    home_team_name,
    home_team_tla,
    away_team_id,
    away_team_name,
    away_team_tla
from {{ source('cartola', 'raw_schedule') }}

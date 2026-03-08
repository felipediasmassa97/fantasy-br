select
    s.season,
    s.round_id,
    s.match_id,
    hm.cartola_club_id as club_home_id,
    am.cartola_club_id as club_away_id
from {{ ref('stg_schedule') }} as s
inner join {{ ref('raw_club_mapping') }} as hm
    on s.home_team_id = hm.schedule_team_id
inner join {{ ref('raw_club_mapping') }} as am
    on s.away_team_id = am.schedule_team_id

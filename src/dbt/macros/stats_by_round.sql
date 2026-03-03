{% macro position_stats_by_round(pts_column) %}
{# Compute position stats for top N players per position per round: GK=10, FB/CB=20, MD/AT=30 #}
select
    as_of_round_id,
    position,
    avg({{ pts_column }}) as pos_avg,
    stddev({{ pts_column }}) as pos_std
from (
    select
        as_of_round_id,
        position,
        {{ pts_column }},
        row_number() over (partition by as_of_round_id, position order by {{ pts_column }} desc) as rn,
        case 
            when position = 'GK' then 10
            when position in ('FB', 'CB') then 20
            else 30
        end as pos_limit
    from player_pts
    where {{ pts_column }} is not null
)
where rn <= pos_limit
group by as_of_round_id, position
{% endmacro %}

{% macro general_stats_by_round(pts_column, top_n=200) %}
{# Compute overall stats for top N players per round #}
select
    as_of_round_id,
    avg({{ pts_column }}) as gen_avg,
    stddev({{ pts_column }}) as gen_std
from (
    select
        as_of_round_id,
        {{ pts_column }},
        row_number() over (partition by as_of_round_id order by {{ pts_column }} desc) as rn
    from player_pts
    where {{ pts_column }} is not null
)
where rn <= {{ top_n }}
group by as_of_round_id
{% endmacro %}

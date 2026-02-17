{% macro position_stats_cte(pts_column) %}
{# Compute position stats for top N players per position: GK=10, FB/CB=20, MD/AT=30 #}
select
    position,
    avg({{ pts_column }}) as pos_avg,
    stddev({{ pts_column }}) as pos_std
from (
    select
        position,
        {{ pts_column }},
        row_number() over (partition by position order by {{ pts_column }} desc) as rn,
        case 
            when position = 'GK' then 10
            when position in ('FB', 'CB') then 20
            else 30
        end as pos_limit
    from player_pts
    where {{ pts_column }} is not null
)
where rn <= pos_limit
group by position
{% endmacro %}

{% macro z_score_position(value_column, stats_alias) %}
({{ value_column }} - {{ stats_alias }}.pos_avg) / nullif({{ stats_alias }}.pos_std, 0)
{% endmacro %}

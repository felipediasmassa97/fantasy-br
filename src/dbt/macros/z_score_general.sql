{% macro general_stats_cte(pts_column, top_n=200) %}
{# Compute overall stats for top N players #}
select
    avg({{ pts_column }}) as gen_avg,
    stddev({{ pts_column }}) as gen_std
from (
    select {{ pts_column }}
    from player_pts
    where {{ pts_column }} is not null
    order by {{ pts_column }} desc
    limit {{ top_n }}
)
{% endmacro %}

{% macro z_score_general(value_column, stats_alias) %}
({{ value_column }} - {{ stats_alias }}.gen_avg) / nullif({{ stats_alias }}.gen_std, 0)
{% endmacro %}

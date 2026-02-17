{% macro z_score_general(pts_avg_column, top_n=200) %}
({{ pts_avg_column }} - (
    select avg(top.pts_avg)
    from (
        select {{ pts_avg_column }} as pts_avg
        from player_pts
        where {{ pts_avg_column }} is not null
        order by {{ pts_avg_column }} desc
        limit {{ top_n }}
    ) top
)) / nullif((
    select stddev(top.pts_avg)
    from (
        select {{ pts_avg_column }} as pts_avg
        from player_pts
        where {{ pts_avg_column }} is not null
        order by {{ pts_avg_column }} desc
        limit {{ top_n }}
    ) top
), 0)
{% endmacro %}

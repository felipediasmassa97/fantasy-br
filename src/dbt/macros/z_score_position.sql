{% macro z_score_position(pts_avg_column, position_column, top_n=20) %}
({{ pts_avg_column }} - (
    select avg(top.pts_avg)
    from (
        select pts_avg
        from player_pts pp
        where pp.{{ position_column }} = player_pts.{{ position_column }}
            and pp.{{ pts_avg_column }} is not null
        order by pp.{{ pts_avg_column }} desc
        limit {{ top_n }}
    ) top
)) / nullif((
    select stddev(top.pts_avg)
    from (
        select pts_avg
        from player_pts pp
        where pp.{{ position_column }} = player_pts.{{ position_column }}
            and pp.{{ pts_avg_column }} is not null
        order by pp.{{ pts_avg_column }} desc
        limit {{ top_n }}
    ) top
), 0)
{% endmacro %}

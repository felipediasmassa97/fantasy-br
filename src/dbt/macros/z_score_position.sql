{% macro z_score_position(pts_avg_column, position_column) %}
{# Position-specific top N: GK=10, FB/CB=20, MD/AT=30 #}
({{ pts_avg_column }} - (
    select avg(top.pts_avg)
    from (
        select 
            pts_avg,
            row_number() over (order by pts_avg desc) as rn,
            case 
                when player_pts.{{ position_column }} = 'GK' then 10
                when player_pts.{{ position_column }} in ('FB', 'CB') then 20
                else 30
            end as pos_limit
        from player_pts pp
        where pp.{{ position_column }} = player_pts.{{ position_column }}
            and pp.{{ pts_avg_column }} is not null
    ) top
    where top.rn <= top.pos_limit
)) / nullif((
    select stddev(top.pts_avg)
    from (
        select 
            pts_avg,
            row_number() over (order by pts_avg desc) as rn,
            case 
                when player_pts.{{ position_column }} = 'GK' then 10
                when player_pts.{{ position_column }} in ('FB', 'CB') then 20
                else 30
            end as pos_limit
        from player_pts pp
        where pp.{{ position_column }} = player_pts.{{ position_column }}
            and pp.{{ pts_avg_column }} is not null
    ) top
    where top.rn <= top.pos_limit
), 0)
{% endmacro %}

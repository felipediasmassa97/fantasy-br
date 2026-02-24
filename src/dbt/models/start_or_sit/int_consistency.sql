-- Consistency & CV metrics split from int_distribution_stats
with blended_stats as (
    select
        b.as_of_round_id,
        b.id,
        b.name,
        b.club,
        b.club_logo_url,
        b.position,
        bs.matches_played,
        bs.pts_avg,
        bs.pts_stddev,
        -- Consistency rating: 1 / (1 + CV) where CV = std/mean
        case
            when bs.pts_avg is null or bs.pts_avg = 0 or bs.pts_stddev is null then null
            else 1.0 / (1.0 + bs.pts_stddev / bs.pts_avg)
        end as consistency_rating,
        -- Coefficient of Variation (raw, for reference)
        case
            when bs.pts_avg is null or bs.pts_avg = 0 or bs.pts_stddev is null then null
            else bs.pts_stddev / bs.pts_avg
        end as cv,
        -- Range (ceiling - floor) as a measure of volatility
        (1 - bs.blend_weight) * bs.raw_ceiling + bs.blend_weight * coalesce(bs.pos_ceiling, bs.raw_ceiling)
        - ((1 - bs.blend_weight) * bs.raw_floor + bs.blend_weight * coalesce(bs.pos_floor, bs.raw_floor)) as pts_range
    from {{ ref('int_map_baseline') }} b
    left join (
        select * from {{ ref('int_distribution_stats') }}
    ) bs
        on b.as_of_round_id = bs.as_of_round_id
        and b.id = bs.id
)

select * from blended_stats

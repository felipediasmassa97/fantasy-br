/*
Start or Sit: Main Consolidated Tab

Mart for Start or Sit decisions.
Joins MAP score with ML points prediction, distribution, and next-match context.

ML column: ml_points_pred (from int_ml_points_prediction)
  - XGBoost ML prediction of expected fantasy points for the next round
  - Val RMSE: 0.46 | R²: 0.987
  - Requires: fantasy-br.fdmdev_fantasy_br.xgb_points_prediction (BigQuery ML)
  - To register model: python scripts/ml_pipeline/register_bqml_model.py
*/

{{ config(materialized='table', alias='ss_main') }}

with

int_distribution_stats_deduped as (
    select
        as_of_round_id,
        id,
        pts_floor,
        pts_ceiling,
        consistency_rating
    from {{ ref('int_distribution_stats') }}
    group by as_of_round_id, id, pts_floor, pts_ceiling, consistency_rating
),

int_poe_deduped as (
    select
        as_of_round_id,
        id,
        avg_poe_season,
        avg_poe_last_5
    from {{ ref('int_poe') }}
    group by as_of_round_id, id, avg_poe_season, avg_poe_last_5
)

select
    m.as_of_round_id,
    m.id                                               AS player_id,
    m.player_name,
    m.club,
    m.club_logo_url,
    m.position,
    m.map_score,
    m.map_rank_pos,
    m.map_rank_gen,
    -- ML prediction: next round (as_of_round_id + 1 in int_ml_points_prediction)
    ml.ml_points_pred,
    -- PoE
    poe.avg_poe_season,
    poe.avg_poe_last_5,
    -- Distribution
    d.pts_floor,
    d.pts_ceiling,
    d.consistency_rating,
    -- Next match info
    m.is_home_next,
    m.opponent_club                                    AS next_opponent,
    m.opponent_logo_url                               AS next_opponent_logo
from {{ ref('int_map_score') }} AS m
left join int_distribution_stats_deduped as d
    on m.as_of_round_id = d.as_of_round_id and m.id = d.id
left join int_poe_deduped as poe
    on m.as_of_round_id = poe.as_of_round_id and m.id = poe.id
left join {{ ref('int_ml_points_prediction') }} AS ml
    on m.as_of_round_id + 1 = ml.round_id and m.id = ml.player_id
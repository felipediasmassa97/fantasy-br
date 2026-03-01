/*
Bayesian shrinkage blend (k=5 default).

shrink_blend(num_matches_expr, this_avg_expr, prior_avg_expr, k=5)
  Returns a CASE expression that blends this-season and prior estimates:
    weight = n / (n + k)
    result = weight * this_avg + (1 - weight) * prior_avg

  Null-handling:
    - this_avg IS NULL:   prior_avg (only historical data available)
    - prior_avg IS NULL:  this_avg (no prior; rely on current season)
    - both NULL:          NULL (no data at all)

  Arguments (all are raw SQL expression strings):
    num_matches_expr:  match count driving the weight (caller handles NULL via COALESCE if needed)
    this_avg_expr:     this-season average (or COALESCEd fallback expression)
    prior_avg_expr:    prior / last-season average (or COALESCEd fallback expression)
    k:                 shrinkage constant, default 5

shrink_weight(num_matches_expr, k=5)
  Returns the scalar weight expression: n / (n + k).
  Use this when you need the weight column separately (e.g. for diagnostics).
*/

{%- macro shrink_blend(num_matches_expr, this_avg_expr, prior_avg_expr, k=5) -%}
    case
        when {{ this_avg_expr }} is null
            then {{ prior_avg_expr }}
        when {{ prior_avg_expr }} is null
            then {{ this_avg_expr }}
        else
            ({{ num_matches_expr }} / ({{ num_matches_expr }} + {{ k | float }})) * {{ this_avg_expr }}
            + ({{ k | float }} / ({{ num_matches_expr }} + {{ k | float }})) * {{ prior_avg_expr }}
    end
{%- endmacro -%}


{%- macro shrink_weight(num_matches_expr, k=5) -%}
    {{ num_matches_expr }} / ({{ num_matches_expr }} + {{ k | float }})
{%- endmacro -%}

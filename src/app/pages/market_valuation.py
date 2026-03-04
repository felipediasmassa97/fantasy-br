"""Market Valuation page."""

import pandas as pd
import streamlit as st
from utils import (
    filter_data,
    load_available_rounds,
    load_mv_baseline,
    load_mv_form_trend,
    load_mv_main,
    load_mv_par_breakdown,
    load_mv_regression,
    load_mv_round_by_round,
    load_mv_value_profile,
    render_sidebar_filters,
)


def _render_main() -> None:
    """Render main consolidated tab with key valuation columns."""
    st.subheader("Market Valuation Overview")

    data = filter_data(load_mv_main(st.session_state.get("filter_round_id")))
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn(
            "Player",
            width="medium",
        ),
        "position": st.column_config.TextColumn(
            "Position",
            width="small",
            help="GK / CB / FB / MD / AT",
        ),
        "club_logo_url": st.column_config.ImageColumn(
            "Club",
            width="small",
        ),
        "par": st.column_config.NumberColumn(
            "PAR",
            format="%+.2f",
            help="Points Above Replacement — baseline minus position replacement level",
        ),
        "baseline_pts": st.column_config.NumberColumn(
            "Baseline",
            format="%.2f",
            help="Shrinkage-blended expected output (k=5). Used as stabilized mean.",
        ),
        "ewm_pts": st.column_config.NumberColumn(
            "EWM Form",
            format="%.2f",
            help="Exponentially-weighted form (higher alpha = more recency bias)",
        ),
        "regression_score": st.column_config.NumberColumn(
            "Regr Score",
            format="%+.2f",
            help="Positive = overperforming (sell high), negative = underperforming",
        ),
        "availability": st.column_config.NumberColumn(
            "Avail%",
            format="%.0f%%",
            help="% of listed rounds where player actually played",
        ),
        "avg_poe_season": st.column_config.NumberColumn(
            "PoE (Szn)",
            format="%+.2f",
            help="Average Points over Expected this season (actual minus MAP)",
        ),
        "avg_poe_last_5": st.column_config.NumberColumn(
            "PoE (L5)",
            format="%+.2f",
            help="Average Points over Expected in last 5 matches (actual minus MAP)",
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    for row in rows:
        if row.get("availability") is not None:
            row["availability"] = row["availability"] * 100

    st.dataframe(
        rows, use_container_width=True, hide_index=True, column_config=col_config
    )


def _render_par_breakdown() -> None:
    """PAR Breakdown subtab."""
    st.subheader("PAR Breakdown & Replacement Level")

    data = filter_data(load_mv_par_breakdown(st.session_state.get("filter_round_id")))
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn(
            "Player",
            width="medium",
        ),
        "position": st.column_config.TextColumn(
            "Position",
            width="small",
        ),
        "club_logo_url": st.column_config.ImageColumn(
            "Club",
            width="small",
        ),
        "baseline_pts": st.column_config.NumberColumn(
            "Baseline",
            format="%.2f",
            help="Shrinkage-blended expected output",
        ),
        "drafted_players_in_position": st.column_config.NumberColumn(
            "Drafted",
            format="%d",
            help="Expected number of players rostered at this position across 10 teams",
        ),
        "replacement_level_pts": st.column_config.NumberColumn(
            "Repl Level",
            format="%.2f",
            help="Average baseline of the 5 best undrafted players at this position",
        ),
        "par_points": st.column_config.NumberColumn(
            "PAR",
            format="%+.2f",
            help="Points Above Replacement = baseline - replacement level",
        ),
        "par_rank_pos": st.column_config.NumberColumn(
            "Rk (Pos)",
            format="%d",
            help="PAR rank within same position",
        ),
        "par_rank_gen": st.column_config.NumberColumn(
            "Rk (All)",
            format="%d",
            help="PAR rank across all positions",
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(
        rows, use_container_width=True, hide_index=True, column_config=col_config
    )


def _render_baseline() -> None:
    """Baseline (Stabilized Mean & Shrinkage) subtab."""
    st.subheader("Baseline — Stabilized Mean & Shrinkage")

    data = filter_data(load_mv_baseline(st.session_state.get("filter_round_id")))
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn(
            "Player",
            width="medium",
        ),
        "position": st.column_config.TextColumn(
            "Position",
            width="small",
        ),
        "club_logo_url": st.column_config.ImageColumn(
            "Club",
            width="small",
        ),
        "pts_avg_this_season": st.column_config.NumberColumn(
            "Avg (This)",
            format="%.2f",
            help="Raw average this season",
        ),
        "matches_this_season": st.column_config.NumberColumn(
            "Matches (This)",
            format="%d",
        ),
        "pts_avg_last_season": st.column_config.NumberColumn(
            "Avg (Last)",
            format="%.2f",
            help="Raw average last season",
        ),
        "matches_last_season": st.column_config.NumberColumn(
            "Matches (Last)", format="%d"
        ),
        "position_pts_avg_last_season": st.column_config.NumberColumn(
            "Pos Avg",
            format="%.2f",
            help="Position average last season (rookie prior)",
        ),
        "shrinking_parameter": st.column_config.NumberColumn(
            "k",
            format="%d",
            help="Shrinkage constant: higher k -> slower convergence to this season",
        ),
        "shrinking_weight_this_season": st.column_config.NumberColumn(
            "Wt (This)",
            format="%.2f",
            help="Weight on this-season data = matches / (matches + k)",
        ),
        "shrinking_method": st.column_config.TextColumn(
            "Method",
            help="weighted_seasons = returning; rookie_shrinkage = new player",
        ),
        "baseline_pts": st.column_config.NumberColumn(
            "Baseline",
            format="%.2f",
            help="Final shrinkage-blended estimate",
        ),
        "baseline_rank_pos": st.column_config.NumberColumn(
            "Rk (Pos)",
            format="%d",
            help="Rank within position",
        ),
        "baseline_rank_gen": st.column_config.NumberColumn(
            "Rk (All)",
            format="%d",
            help="Rank across all positions",
        ),
        "pts_avg_home": st.column_config.NumberColumn(
            "Home Avg",
            format="%.2f",
            help="Shrinkage-blended baseline for home matches",
        ),
        "matches_home_this_season": st.column_config.NumberColumn(
            "Home G (This)",
            format="%d",
        ),
        "baseline_rank_pos_home": st.column_config.NumberColumn(
            "Rk Home (Pos)",
            format="%d",
            help="Rank by home baseline within position",
        ),
        "pts_avg_away": st.column_config.NumberColumn(
            "Away Avg",
            format="%.2f",
            help="Shrinkage-blended baseline for away matches",
        ),
        "matches_away_this_season": st.column_config.NumberColumn(
            "Away G (This)",
            format="%d",
        ),
        "baseline_rank_pos_away": st.column_config.NumberColumn(
            "Rk Away (Pos)",
            format="%d",
            help="Rank by away baseline within position",
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(
        rows, use_container_width=True, hide_index=True, column_config=col_config
    )


def _render_form_trend() -> None:
    """Form & Trend subtab."""
    st.subheader("Form (EWM) & Trend")

    data = filter_data(load_mv_form_trend(st.session_state.get("filter_round_id")))
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn(
            "Player",
            width="medium",
        ),
        "position": st.column_config.TextColumn(
            "Position",
            width="small",
        ),
        "club_logo_url": st.column_config.ImageColumn(
            "Club",
            width="small",
        ),
        "ewm_alpha": st.column_config.NumberColumn(
            "Alpha",
            format="%.2f",
            help="EWM decay factor (higher = more weight on recent matches)",
        ),
        "ewm_points": st.column_config.NumberColumn(
            "EWM",
            format="%.2f",
            help="Exponentially-weighted mean score",
        ),
        "last3_avg_points": st.column_config.NumberColumn(
            "Last 3 Avg",
            format="%.2f",
            help="Simple average of last 3 matches played",
        ),
        "season_avg_points": st.column_config.NumberColumn(
            "Season Avg",
            format="%.2f",
            help="Season-to-date simple average",
        ),
        "trend_ratio_last3": st.column_config.NumberColumn(
            "Trend L3",
            format="%.3f",
            help="Last-3 avg / season avg. >1 = improving, <1 = declining",
        ),
        "form_bucket_last3": st.column_config.TextColumn(
            "Form (L3)",
            help="UP / FLAT / DOWN based on last-3 trend ratio",
        ),
        "trend_ratio_ewm": st.column_config.NumberColumn(
            "Trend EWM",
            format="%.3f",
            help="EWM / season avg. >1 = improving, <1 = declining",
        ),
        "form_bucket_ewm": st.column_config.TextColumn(
            "Form (EWM)",
            help="UP / FLAT / DOWN based on EWM trend ratio",
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(
        rows, use_container_width=True, hide_index=True, column_config=col_config
    )


def _render_regression() -> None:
    """Regression Candidate subtab."""
    st.subheader("Regression Candidates")

    data = filter_data(load_mv_regression(st.session_state.get("filter_round_id")))
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn(
            "Player",
            width="medium",
        ),
        "position": st.column_config.TextColumn(
            "Position",
            width="small",
        ),
        "club_logo_url": st.column_config.ImageColumn(
            "Club",
            width="small",
        ),
        "ewm_points": st.column_config.NumberColumn(
            "EWM",
            format="%.2f",
            help="Recent form (exponentially weighted)",
        ),
        "baseline_pts": st.column_config.NumberColumn(
            "Baseline",
            format="%.2f",
            help="Stabilized expected output",
        ),
        "performance_gap": st.column_config.NumberColumn(
            "Gap",
            format="%+.2f",
            help="EWM minus baseline. Positive = over, negative = underperforming",
        ),
        "goal_assist_share": st.column_config.NumberColumn(
            "GA Share",
            format="%.2f",
            help="Goals + assists share of points. High = regression risk.",
        ),
        "consistency_rating": st.column_config.TextColumn(
            "Consistency",
            help="HIGH / MED / LOW based on CV",
        ),
        "regression_score": st.column_config.NumberColumn(
            "Regr Score",
            format="%+.2f",
            help="Composite signal: gap x (1 + GA share) / consistency",
        ),
        "signal_label": st.column_config.TextColumn(
            "Signal",
            help="SELL_HIGH / BUY_LOW / NEUTRAL",
        ),
        "confidence_flag": st.column_config.TextColumn(
            "Confidence",
            help="LOW_SAMPLE if <5 matches played this season",
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(
        rows, use_container_width=True, hide_index=True, column_config=col_config
    )


def _render_value_profile() -> None:
    """Value Profile subtab."""
    st.subheader("Value Profile — Risk vs Reward")

    data = filter_data(load_mv_value_profile(st.session_state.get("filter_round_id")))
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn(
            "Player",
            width="medium",
        ),
        "position": st.column_config.TextColumn(
            "Position",
            width="small",
        ),
        "club_logo_url": st.column_config.ImageColumn(
            "Club",
            width="small",
        ),
        "par_points": st.column_config.NumberColumn(
            "PAR",
            format="%+.2f",
            help="Points Above Replacement",
        ),
        "baseline_pts": st.column_config.NumberColumn(
            "Baseline",
            format="%.2f",
            help="Stabilized expected output",
        ),
        "pts_floor": st.column_config.NumberColumn(
            "Floor (P20)",
            format="%.1f",
            help="20th-percentile score",
        ),
        "pts_median": st.column_config.NumberColumn(
            "Median (P50)",
            format="%.1f",
            help="Median score",
        ),
        "pts_ceiling": st.column_config.NumberColumn(
            "Ceiling (P80)",
            format="%.1f",
            help="80th-percentile score",
        ),
        "consistency_rating": st.column_config.TextColumn(
            "Consistency",
            help="HIGH / MED / LOW based on CV",
        ),
        "availability": st.column_config.NumberColumn(
            "Avail%",
            format="%.0f%%",
            help="% of listed rounds where player actually played",
        ),
        "ga_dependency": st.column_config.NumberColumn(
            "GA Dep",
            format="%.2f",
            help="G+A share of expected points (regression risk indicator).",
        ),
        "avg_poe_season": st.column_config.NumberColumn(
            "PoE (Szn)",
            format="%+.2f",
            help="Average Points over Expected this season (actual minus MAP)",
        ),
        "avg_poe_last_5": st.column_config.NumberColumn(
            "PoE (L5)",
            format="%+.2f",
            help="Average Points over Expected in last 5 matches (actual minus MAP)",
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    for row in rows:
        if row.get("availability") is not None:
            row["availability"] = row["availability"] * 100

    st.dataframe(
        rows, use_container_width=True, hide_index=True, column_config=col_config
    )


def _render_round_by_round() -> None:
    """Round-by-Round Raw subtab."""
    st.subheader("Round-by-Round Raw Data")

    data = filter_data(load_mv_round_by_round(st.session_state.get("filter_round_id")))
    if not data:
        st.info("No data available for this round.")
        return

    df = pd.DataFrame(data)

    display_cols = [
        "round",
        "player_name",
        "position",
        "club_logo_url",
        "club",
        "points_total",
        "points_base",
        "did_play",
    ]
    scout_cols = [c for c in df.columns if c.startswith("scout_")]
    display_cols.extend(sorted(scout_cols))
    display_cols = [c for c in display_cols if c in df.columns]

    scout_col_config = {
        c: st.column_config.NumberColumn(
            c.replace("scout_", "").upper(),
            format="%.0f",
        )
        for c in scout_cols
    }

    st.dataframe(
        df[display_cols],
        use_container_width=True,
        hide_index=True,
        column_config={
            "round": st.column_config.NumberColumn(
                "Rd",
                format="%d",
            ),
            "player_name": st.column_config.TextColumn(
                "Player",
                width="medium",
            ),
            "position": st.column_config.TextColumn(
                "Position",
                width="small",
            ),
            "club_logo_url": st.column_config.ImageColumn(
                "Club",
                width="small",
            ),
            "club": st.column_config.TextColumn(
                "Club",
                width="small",
            ),
            "points_total": st.column_config.NumberColumn(
                "Total",
                format="%.1f",
                help="Total points including G/A",
            ),
            "points_base": st.column_config.NumberColumn(
                "Base",
                format="%.1f",
                help="Points excluding goals, assists, red cards and own goals",
            ),
            "did_play": st.column_config.CheckboxColumn(
                "Played?",
            ),
            **scout_col_config,
        },
    )


def main() -> None:
    """Render Market Valuation page."""
    st.title("Market Valuation")

    rounds = load_available_rounds()
    if not rounds:
        st.warning("No rounds available.")
        return

    render_sidebar_filters()

    tabs = st.tabs(
        [
            "Main",
            "PAR Breakdown",
            "Baseline",
            "Form & Trend",
            "Regression",
            "Value Profile",
            "Round-by-Round",
        ]
    )

    with tabs[0]:
        _render_main()
    with tabs[1]:
        _render_par_breakdown()
    with tabs[2]:
        _render_baseline()
    with tabs[3]:
        _render_form_trend()
    with tabs[4]:
        _render_regression()
    with tabs[5]:
        _render_value_profile()
    with tabs[6]:
        _render_round_by_round()

"""Market Valuation page - PAR, stabilized mean, form, regression signals."""

# fixit evaluate, refactor, standardize and improve

import pandas as pd
import streamlit as st
from utils import (
    filter_data,
    load_available_rounds,
    load_mv_form_trend,
    load_mv_main,
    load_mv_par_breakdown,
    load_mv_regression,
    load_mv_round_by_round,
    load_mv_stabilized,
    load_mv_value_profile,
)

# ---------------------------------------------------------------------------
# Tab renderers
# ---------------------------------------------------------------------------


def _render_main(data: list[dict]) -> None:
    """Render main consolidated tab with key valuation columns."""
    st.subheader("Market Valuation Overview")
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "club_logo_url": st.column_config.ImageColumn("Club", width="small"),
        "club": st.column_config.TextColumn("Team", width="small"),
        "par": st.column_config.NumberColumn(
            "PAR", format="%+.2f", help="Points Above Replacement"
        ),
        "stabilized_mean": st.column_config.NumberColumn(
            "Stabilized", format="%.2f", help="Shrinkage-blended baseline"
        ),
        "ewm_pts": st.column_config.NumberColumn(
            "EWM", format="%.2f", help="Exponentially weighted mean"
        ),
        "regression_score": st.column_config.NumberColumn(
            "Regr Score", format="%+.2f", help="Regression candidate signal"
        ),
        "availability": st.column_config.NumberColumn(
            "Avail%", format="%.0f%%", help="Games played / total rounds"
        ),
    }

    display_cols = [
        "name",
        "position",
        "club_logo_url",
        "club",
        "par",
        "stabilized_mean",
        "ewm_pts",
        "regression_score",
        "availability",
    ]
    rows = [{k: row.get(k) for k in display_cols} for row in data]

    # Convert availability from fraction to percentage for display
    for row in rows:
        if row.get("availability") is not None:
            row["availability"] = row["availability"] * 100

    st.dataframe(rows, width="stretch", hide_index=True, column_config=col_config)


def _render_par_breakdown(data: list[dict]) -> None:
    """PAR Breakdown subtab."""
    st.subheader("PAR Breakdown & Replacement Level")
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn("Player", width="medium"),
        "player_id": st.column_config.NumberColumn("ID", format="%d"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "baseline_points": st.column_config.NumberColumn("Baseline", format="%.2f"),
        "replacement_percentile_used": st.column_config.NumberColumn(
            "Repl Pct", format="%.2f"
        ),
        "replacement_level_points_pos": st.column_config.NumberColumn(
            "Repl Level", format="%.2f"
        ),
        "par_points": st.column_config.NumberColumn("PAR", format="%+.2f"),
        "par_rank_pos": st.column_config.NumberColumn("Rank (Pos)", format="%d"),
        "par_rank_gen": st.column_config.NumberColumn("Rank (All)", format="%d"),
        "position_depth_flag": st.column_config.TextColumn(
            "Depth", help="DEEP / MODERATE / SCARCE"
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(rows, width="stretch", hide_index=True, column_config=col_config)


def _render_stabilized(data: list[dict]) -> None:
    """Stabilized Mean & Shrinkage subtab."""
    st.subheader("Stabilized Mean & Shrinkage")
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn("Player", width="medium"),
        "player_id": st.column_config.NumberColumn("ID", format="%d"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "avg_points_this_season": st.column_config.NumberColumn(
            "Avg (This)", format="%.2f"
        ),
        "games_this_season": st.column_config.NumberColumn("Games (This)", format="%d"),
        "avg_points_last_season": st.column_config.NumberColumn(
            "Avg (Last)", format="%.2f"
        ),
        "games_last_season": st.column_config.NumberColumn("Games (Last)", format="%d"),
        "position_avg_last_season": st.column_config.NumberColumn(
            "Pos Avg", format="%.2f"
        ),
        "shrink_k_used": st.column_config.NumberColumn("k", format="%d"),
        "weight_this_season": st.column_config.NumberColumn("Wt (This)", format="%.2f"),
        "stabilized_mean_points": st.column_config.NumberColumn(
            "Stabilized", format="%.2f"
        ),
        "stabilized_rank_pos": st.column_config.NumberColumn("Rank (Pos)", format="%d"),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(rows, width="stretch", hide_index=True, column_config=col_config)


def _render_form_trend(data: list[dict]) -> None:
    """Form & Trend subtab."""
    st.subheader("Form (EWM) & Trend")
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn("Player", width="medium"),
        "player_id": st.column_config.NumberColumn("ID", format="%d"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "ewm_alpha": st.column_config.NumberColumn("Alpha", format="%.2f"),
        "ewm_points": st.column_config.NumberColumn("EWM", format="%.2f"),
        "last3_avg_points": st.column_config.NumberColumn("Last 3", format="%.2f"),
        "last5_avg_points": st.column_config.NumberColumn("Last 5", format="%.2f"),
        "season_avg_points": st.column_config.NumberColumn("Season Avg", format="%.2f"),
        "trend_ratio_last3": st.column_config.NumberColumn("Trend L3", format="%.3f"),
        "trend_ratio_ewm": st.column_config.NumberColumn("Trend EWM", format="%.3f"),
        "form_bucket": st.column_config.TextColumn("Form", help="UP / FLAT / DOWN"),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(rows, width="stretch", hide_index=True, column_config=col_config)


def _render_regression(data: list[dict]) -> None:
    """Regression Candidate subtab."""
    st.subheader("Regression Candidates")
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn("Player", width="medium"),
        "player_id": st.column_config.NumberColumn("ID", format="%d"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "ewm_points": st.column_config.NumberColumn("EWM", format="%.2f"),
        "stabilized_mean_points": st.column_config.NumberColumn(
            "Stabilized", format="%.2f"
        ),
        "performance_gap": st.column_config.NumberColumn("Gap", format="%+.2f"),
        "goal_assist_share": st.column_config.NumberColumn("GA Share", format="%.2f"),
        "consistency_rating": st.column_config.TextColumn("Consistency"),
        "regression_score": st.column_config.NumberColumn("Regr Score", format="%+.2f"),
        "signal_label": st.column_config.TextColumn(
            "Signal", help="SELL_HIGH / BUY_LOW / NEUTRAL"
        ),
        "confidence_flag": st.column_config.TextColumn(
            "Confidence", help="LOW_SAMPLE if <5 games"
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(rows, width="stretch", hide_index=True, column_config=col_config)


def _render_value_profile(data: list[dict]) -> None:
    """Value Profile subtab."""
    st.subheader("Value Profile - Risk vs Reward")
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn("Player", width="medium"),
        "player_id": st.column_config.NumberColumn("ID", format="%d"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "par_points": st.column_config.NumberColumn("PAR", format="%+.2f"),
        "stabilized_mean_points": st.column_config.NumberColumn(
            "Stabilized", format="%.2f"
        ),
        "floor_p20": st.column_config.NumberColumn("Floor (P20)", format="%.1f"),
        "median_p50": st.column_config.NumberColumn("Median (P50)", format="%.1f"),
        "ceiling_p80": st.column_config.NumberColumn("Ceiling (P80)", format="%.1f"),
        "consistency_rating": st.column_config.TextColumn("Consistency"),
        "availability_rate": st.column_config.NumberColumn("Avail%", format="%.0f%%"),
        "ga_dependency": st.column_config.NumberColumn("GA Dep", format="%.2f"),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]

    # Convert availability from fraction to percentage
    for row in rows:
        if row.get("availability_rate") is not None:
            row["availability_rate"] = row["availability_rate"] * 100

    st.dataframe(rows, width="stretch", hide_index=True, column_config=col_config)


def _render_round_by_round(data: list[dict]) -> None:
    """Round-by-Round Raw subtab."""
    st.subheader("Round-by-Round Raw Data")
    if not data:
        st.info("No data available.")
        return

    df = pd.DataFrame(data)

    display_cols = [
        "round",
        "player_name",
        "player_id",
        "position",
        "team",
        "points_total",
        "points_base",
        "goals",
        "assists",
        "did_play",
    ]

    scout_cols = [c for c in df.columns if c.startswith("scout_")]
    display_cols.extend(scout_cols)
    display_cols = [c for c in display_cols if c in df.columns]

    st.dataframe(
        df[display_cols],
        width="stretch",
        hide_index=True,
        column_config={
            "round": st.column_config.NumberColumn("Round", format="%d"),
            "player_name": st.column_config.TextColumn("Player", width="medium"),
            "player_id": st.column_config.NumberColumn("ID", format="%d"),
            "position": st.column_config.TextColumn("Pos", width="small"),
            "team": st.column_config.TextColumn("Team", width="small"),
            "points_total": st.column_config.NumberColumn("Total", format="%.1f"),
            "points_base": st.column_config.NumberColumn("Base", format="%.1f"),
            "goals": st.column_config.NumberColumn("G", format="%d"),
            "assists": st.column_config.NumberColumn("A", format="%d"),
            "did_play": st.column_config.CheckboxColumn("Played?"),
        },
    )


# ---------------------------------------------------------------------------
# Sidebar filters
# ---------------------------------------------------------------------------


def _sidebar_filters(data: list[dict]) -> tuple[str, str, str]:
    """Render sidebar filters and return (name, club, position)."""
    st.sidebar.header("Filters")
    name_filter = st.sidebar.text_input("Player Name", "", key="mv_name")

    clubs = sorted(
        {
            row.get("club", row.get("team", ""))
            for row in data
            if row.get("club") or row.get("team")
        }
    )
    club_filter = st.sidebar.selectbox("Club", ["All", *clubs], key="mv_club")

    positions = sorted({row.get("position", "") for row in data if row.get("position")})
    position_filter = st.sidebar.selectbox(
        "Position", ["All", *positions], key="mv_pos"
    )

    return name_filter, club_filter, position_filter


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    """Render Market Valuation page."""
    st.title("Market Valuation")

    rounds = load_available_rounds()
    if not rounds:
        st.warning("No rounds available.")
        return

    selected_round = st.selectbox("Select Round", rounds, index=0, key="mv_round")

    # Pre-load main data for filters
    main_data = load_mv_main(selected_round)
    name_f, club_f, pos_f = _sidebar_filters(main_data)

    tabs = st.tabs(
        [
            "Main",
            "PAR Breakdown",
            "Stabilized Mean",
            "Form & Trend",
            "Regression",
            "Value Profile",
            "Round-by-Round",
        ]
    )

    with tabs[0]:
        _render_main(filter_data(main_data, name_f, club_f, pos_f))

    with tabs[1]:
        data = load_mv_par_breakdown(selected_round)
        _render_par_breakdown(filter_data(data, name_f, club_f, pos_f))

    with tabs[2]:
        data = load_mv_stabilized(selected_round)
        _render_stabilized(filter_data(data, name_f, club_f, pos_f))

    with tabs[3]:
        data = load_mv_form_trend(selected_round)
        _render_form_trend(filter_data(data, name_f, club_f, pos_f))

    with tabs[4]:
        data = load_mv_regression(selected_round)
        _render_regression(filter_data(data, name_f, club_f, pos_f))

    with tabs[5]:
        data = load_mv_value_profile(selected_round)
        _render_value_profile(filter_data(data, name_f, club_f, pos_f))

    with tabs[6]:
        data = load_mv_round_by_round(selected_round)
        _render_round_by_round(filter_data(data, name_f, club_f, pos_f))

"""Start or Sit page - MAP projection with component breakdown and diagnostics."""

import pandas as pd
import streamlit as st
from utils import (
    filter_data,
    load_available_rounds,
    load_ss_distribution,
    load_ss_edge_cases,
    load_ss_home_away,
    load_ss_main,
    load_ss_map_breakdown,
    load_ss_mpap_debug,
    load_ss_round_by_round,
)

# fixit move each load_* function to its _render_*
# fixit add tooltips
# fixit update column names


def _render_main(data: list[dict]) -> None:
    """Render main consolidated tab with key decision columns."""
    st.subheader("Start or Sit Overview")
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "club_logo_url": st.column_config.ImageColumn("Club", width="small"),
        "club": st.column_config.TextColumn("Club", width="small"),
        "map_score": st.column_config.NumberColumn(
            "MAP", format="%.2f", help="Multi-factor Adjusted Projection"
        ),
        "floor_pts": st.column_config.NumberColumn(
            "Floor (P20)", format="%.1f", help="20th-percentile score"
        ),
        "ceiling_pts": st.column_config.NumberColumn(
            "Ceiling (P80)", format="%.1f", help="80th-percentile score"
        ),
        "consistency_rating": st.column_config.TextColumn(
            "Consistency", help="LOW / MED / HIGH"
        ),
        "is_home_next": st.column_config.CheckboxColumn(
            "Home?", help="Playing at home next round"
        ),
    }

    display_cols = [
        "name",
        "position",
        "club_logo_url",
        "club",
        "map_score",
        "floor_pts",
        "ceiling_pts",
        "consistency_rating",
        "is_home_next",
    ]
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(rows, width="stretch", hide_index=True, column_config=col_config)


def _render_map_breakdown(data: list[dict]) -> None:
    """MAP Breakdown subtab: every component of the MAP projection."""
    st.subheader("MAP Component Breakdown")
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn("Player", width="medium"),
        "player_id": st.column_config.NumberColumn("ID", format="%d"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "club": st.column_config.TextColumn("Club", width="small"),
        "opponent_club": st.column_config.TextColumn("Opponent", width="small"),
        "is_home": st.column_config.CheckboxColumn("Home?"),
        "baseline_points": st.column_config.NumberColumn("Baseline", format="%.2f"),
        "ewm_form_points": st.column_config.NumberColumn("EWM Form", format="%.2f"),
        "form_multiplier": st.column_config.NumberColumn("Form Mult", format="%.3f"),
        "home_away_multiplier": st.column_config.NumberColumn(
            "Venue Mult", format="%.3f"
        ),
        "mpap_multiplier": st.column_config.NumberColumn("MPAP Mult", format="%.3f"),
        "map_points": st.column_config.NumberColumn("MAP", format="%.2f"),
        "map_rank_pos": st.column_config.NumberColumn("Rank (Pos)", format="%d"),
        "map_rank_gen": st.column_config.NumberColumn("Rank (All)", format="%d"),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(rows, width="stretch", hide_index=True, column_config=col_config)


def _render_mpap_debug(data: list[dict]) -> None:
    """Opponent & MPAP Debug subtab."""
    st.subheader("Opponent & MPAP Debug")
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "opponent_club": st.column_config.TextColumn("Opponent", width="small"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "games_in_sample_this_season": st.column_config.NumberColumn(
            "Games (This)", format="%d"
        ),
        "games_in_sample_last_season": st.column_config.NumberColumn(
            "Games (Last)", format="%d"
        ),
        "points_allowed_this_season_avg": st.column_config.NumberColumn(
            "Allowed Avg (This)", format="%.2f"
        ),
        "points_allowed_last_season_avg": st.column_config.NumberColumn(
            "Allowed Avg (Last)", format="%.2f"
        ),
        "points_allowed_blended_avg": st.column_config.NumberColumn(
            "Allowed Blended", format="%.2f"
        ),
        "league_avg_allowed_pos": st.column_config.NumberColumn(
            "League Avg", format="%.2f"
        ),
        "mpap_ratio": st.column_config.NumberColumn("Ratio", format="%.3f"),
        "mpap_multiplier": st.column_config.NumberColumn("Multiplier", format="%.3f"),
        "last_updated_round": st.column_config.NumberColumn("Updated Rd", format="%d"),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(rows, width="stretch", hide_index=True, column_config=col_config)


def _render_home_away(data: list[dict]) -> None:
    """Player Home-Away subtab: home vs away performance."""
    st.subheader("Home vs Away Splits")
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn("Player", width="medium"),
        "player_id": st.column_config.NumberColumn("ID", format="%d"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "club": st.column_config.TextColumn("Club", width="small"),
        "games_home_this_season": st.column_config.NumberColumn(
            "Home G (This)", format="%d"
        ),
        "avg_points_home_this_season": st.column_config.NumberColumn(
            "Home Avg (This)", format="%.2f"
        ),
        "games_away_this_season": st.column_config.NumberColumn(
            "Away G (This)", format="%d"
        ),
        "avg_points_away_this_season": st.column_config.NumberColumn(
            "Away Avg (This)", format="%.2f"
        ),
        "games_home_last_season": st.column_config.NumberColumn(
            "Home G (Last)", format="%d"
        ),
        "avg_points_home_last_season": st.column_config.NumberColumn(
            "Home Avg (Last)", format="%.2f"
        ),
        "games_away_last_season": st.column_config.NumberColumn(
            "Away G (Last)", format="%d"
        ),
        "avg_points_away_last_season": st.column_config.NumberColumn(
            "Away Avg (Last)", format="%.2f"
        ),
        "home_away_delta": st.column_config.NumberColumn("H/A Delta", format="%+.2f"),
        "home_away_multiplier_home": st.column_config.NumberColumn(
            "Home Mult", format="%.3f"
        ),
        "home_away_multiplier_away": st.column_config.NumberColumn(
            "Away Mult", format="%.3f"
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(rows, width="stretch", hide_index=True, column_config=col_config)


def _render_distribution(data: list[dict]) -> None:
    """Distribution & Volatility subtab."""
    st.subheader("Distribution & Volatility")
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn("Player", width="medium"),
        "player_id": st.column_config.NumberColumn("ID", format="%d"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "n_games_total_used": st.column_config.NumberColumn("Games", format="%d"),
        "floor_p20": st.column_config.NumberColumn("Floor (P20)", format="%.1f"),
        "median_p50": st.column_config.NumberColumn("Median (P50)", format="%.1f"),
        "ceiling_p80": st.column_config.NumberColumn("Ceiling (P80)", format="%.1f"),
        "mean_points_used": st.column_config.NumberColumn("Mean", format="%.2f"),
        "std_points_used": st.column_config.NumberColumn("Std", format="%.2f"),
        "cv_points": st.column_config.NumberColumn("CV", format="%.2f"),
        "consistency_rating": st.column_config.TextColumn("Consistency"),
        "boom_rate_ge_8": st.column_config.NumberColumn("Boom% (>=8)", format="%.0f%%"),
        "bust_rate_le_2": st.column_config.NumberColumn("Bust% (<=2)", format="%.0f%%"),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(rows, width="stretch", hide_index=True, column_config=col_config)


def _render_round_by_round(data: list[dict]) -> None:
    """Round-by-Round Raw subtab."""
    st.subheader("Round-by-Round Raw Data")
    if not data:
        st.info("No data available.")
        return

    df = pd.DataFrame(data)

    # Display columns
    display_cols = [
        "round",
        "match_id",
        "player_name",
        "player_id",
        "position",
        "club",
        "opponent_club",
        "is_home",
        "points_total",
        "points_base",
        "goals",
        "assists",
        "did_play",
    ]

    # Add scout columns that exist
    scout_cols = [c for c in df.columns if c.startswith("scout_")]
    display_cols.extend(scout_cols)

    # Filter to existing columns
    display_cols = [c for c in display_cols if c in df.columns]

    st.dataframe(
        df[display_cols],
        width="stretch",
        hide_index=True,
        column_config={
            "round": st.column_config.NumberColumn("Round", format="%d"),
            "match_id": st.column_config.NumberColumn("Match", format="%d"),
            "player_name": st.column_config.TextColumn("Player", width="medium"),
            "player_id": st.column_config.NumberColumn("ID", format="%d"),
            "position": st.column_config.TextColumn("Pos", width="small"),
            "club": st.column_config.TextColumn("Club", width="small"),
            "opponent_club": st.column_config.TextColumn("Opponent", width="small"),
            "is_home": st.column_config.CheckboxColumn("Home?"),
            "points_total": st.column_config.NumberColumn("Total", format="%.1f"),
            "points_base": st.column_config.NumberColumn("Base", format="%.1f"),
            "goals": st.column_config.NumberColumn("G", format="%d"),
            "assists": st.column_config.NumberColumn("A", format="%d"),
            "did_play": st.column_config.CheckboxColumn("Played?"),
        },
    )


def _render_edge_cases(data: list[dict]) -> None:
    """Edge Cases & Missing Data subtab."""
    st.subheader("Edge Cases & Missing Data")
    if not data:
        st.info("No data available.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn("Player", width="medium"),
        "player_id": st.column_config.NumberColumn("ID", format="%d"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "club": st.column_config.TextColumn("Club", width="small"),
        "has_last_season_data": st.column_config.CheckboxColumn("Has Last Szn?"),
        "games_last_season": st.column_config.NumberColumn("Games (Last)", format="%d"),
        "games_this_season": st.column_config.NumberColumn("Games (This)", format="%d"),
        "first_round_seen": st.column_config.NumberColumn("First Rd", format="%d"),
        "last_round_seen": st.column_config.NumberColumn("Last Rd", format="%d"),
        "missing_home_away_flag": st.column_config.CheckboxColumn("Missing H/A?"),
        "missing_opponent_flag": st.column_config.CheckboxColumn("Missing Opp?"),
        "missing_points_flag": st.column_config.CheckboxColumn("Missing Pts?"),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(rows, width="stretch", hide_index=True, column_config=col_config)


def _sidebar_filters(data: list[dict]) -> tuple[str, str, str]:
    """Render sidebar filters and return (name, club, position)."""
    st.sidebar.header("Filters")
    name_filter = st.sidebar.text_input("Player Name", "")

    clubs = sorted({row.get("club") for row in data if row.get("club")})
    club_filter = st.sidebar.selectbox("Club", ["All", *clubs])

    positions = sorted({row.get("position", "") for row in data if row.get("position")})
    position_filter = st.sidebar.selectbox("Position", ["All", *positions])

    return name_filter, club_filter, position_filter


def main() -> None:
    """Render Start or Sit page."""
    st.title("Start or Sit")

    rounds = load_available_rounds()
    if not rounds:
        st.warning("No rounds available.")
        return

    selected_round = st.selectbox("Select Round", rounds, index=0)

    # Pre-load main data for filters
    main_data = load_ss_main(selected_round)
    name_f, club_f, pos_f = _sidebar_filters(main_data)

    tabs = st.tabs(
        [
            "Main",
            "MAP Breakdown",
            "Opponent & MPAP Debug",
            "Player Splits",
            "Distribution & Volatility",
            "Round-by-Round Raw",
            "Edge Cases",
        ]
    )

    with tabs[0]:
        _render_main(filter_data(main_data, name_f, club_f, pos_f))

    with tabs[1]:
        data = load_ss_map_breakdown(selected_round)
        _render_map_breakdown(filter_data(data, name_f, club_f, pos_f))

    with tabs[2]:
        data = load_ss_mpap_debug(selected_round)
        # MPAP debug has no player-level name/club, show as-is
        _render_mpap_debug(data)

    with tabs[3]:
        data = load_ss_home_away(selected_round)
        _render_home_away(filter_data(data, name_f, club_f, pos_f))

    with tabs[4]:
        data = load_ss_distribution(selected_round)
        _render_distribution(filter_data(data, name_f, club_f, pos_f))

    with tabs[5]:
        data = load_ss_round_by_round(selected_round)
        _render_round_by_round(filter_data(data, name_f, club_f, pos_f))

    with tabs[6]:
        data = load_ss_edge_cases()
        _render_edge_cases(filter_data(data, name_f, club_f, pos_f))

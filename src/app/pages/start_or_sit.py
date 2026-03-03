"""Start or Sit page."""

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
    render_sidebar_filters,
)


def _render_main() -> None:
    """Render main consolidated tab with key decision columns."""
    st.subheader("Start or Sit Overview")

    data = filter_data(load_ss_main(st.session_state.get("filter_round_id")))
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
        "club": st.column_config.TextColumn(
            "Club",
            width="small",
        ),
        "map_score": st.column_config.NumberColumn(
            "MAP",
            format="%.2f",
            help="MAP: baseline x form x venue x opponent multipliers",
        ),
        "pts_floor": st.column_config.NumberColumn(
            "Floor",
            format="%.1f",
            help="20th-percentile score — worst realistic outcome",
        ),
        "pts_ceiling": st.column_config.NumberColumn(
            "Ceiling",
            format="%.1f",
            help="80th-percentile score — best realistic outcome",
        ),
        "consistency_rating": st.column_config.TextColumn(
            "Consistency",
            help="Consistency: LOW (<0.5 CV) / MED / HIGH (>1.0 CV)",
        ),
        "is_home_next": st.column_config.CheckboxColumn(
            "Home?",
            help="Player's club is the home team next round",
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(
        rows, use_container_width=True, hide_index=True, column_config=col_config
    )


def _render_map_breakdown() -> None:
    """MAP Breakdown subtab: every component of the MAP projection."""
    st.subheader("MAP Component Breakdown")

    data = filter_data(load_ss_map_breakdown(st.session_state.get("filter_round_id")))
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
        "opponent_club": st.column_config.TextColumn(
            "Opponent",
            help="Club faced next round",
        ),
        "is_home": st.column_config.CheckboxColumn(
            "Home?",
            help="Player's club is the home team",
        ),
        "baseline_pts": st.column_config.NumberColumn(
            "Baseline",
            format="%.2f",
            help="Shrinkage-blended expected output (k=5)",
        ),
        "ewm_form_points": st.column_config.NumberColumn(
            "EWM Form",
            format="%.2f",
            help="Exponentially-weighted recent form",
        ),
        "form_multiplier": st.column_config.NumberColumn(
            "Form Mult",
            format="%.3f",
            help="Recent form relative to baseline, clamped 0.8-1.2",
        ),
        "home_away_multiplier": st.column_config.NumberColumn(
            "Venue Mult",
            format="%.3f",
            help="Home/away split relative to baseline, clamped 0.85-1.15",
        ),
        "mpap_multiplier": st.column_config.NumberColumn(
            "MPAP Mult",
            format="%.3f",
            help="Opponent multiplier: >1 = weak opponent, clamped 0.85-1.15",
        ),
        "map_points": st.column_config.NumberColumn(
            "MAP",
            format="%.2f",
            help="Final MAP score = baseline x form x venue x MPAP",
        ),
        "map_rank_pos": st.column_config.NumberColumn(
            "Rk (Pos)",
            format="%d",
            help="Rank within same position",
        ),
        "map_rank_gen": st.column_config.NumberColumn(
            "Rk (All)",
            format="%d",
            help="Rank across all positions",
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(
        rows, use_container_width=True, hide_index=True, column_config=col_config
    )


def _render_mpap_debug() -> None:
    """Opponent & MPAP Debug subtab."""
    st.subheader("Opponent Strength (MPAP Debug)")

    data = filter_data(load_ss_mpap_debug(st.session_state.get("filter_round_id")))
    if not data:
        st.info("No data available for this round.")
        return

    col_config = {
        "opponent_logo_url": st.column_config.ImageColumn(
            "Club",
            width="small",
        ),
        "opponent_club": st.column_config.TextColumn(
            "Opponent",
            width="small",
        ),
        "position": st.column_config.TextColumn(
            "Position",
            width="small",
        ),
        "matches_in_sample_this_season": st.column_config.NumberColumn(
            "Matches (This)",
            format="%d",
            help="Matches in sample this season",
        ),
        "matches_in_sample_last_season": st.column_config.NumberColumn(
            "Matches (Last)",
            format="%d",
            help="Matches in sample last season",
        ),
        "pts_allowed_this_season_avg": st.column_config.NumberColumn(
            "Allowed (This)",
            format="%.2f",
            help="Avg points allowed this season",
        ),
        "pts_allowed_last_season_avg": st.column_config.NumberColumn(
            "Allowed (Last)",
            format="%.2f",
            help="Avg points allowed last season",
        ),
        "pts_allowed_avg": st.column_config.NumberColumn(
            "Allowed (Blended)",
            format="%.2f",
            help="Blended (shrinkage k=5) avg points allowed",
        ),
        "pts_allowed_avg_league": st.column_config.NumberColumn(
            "League Avg",
            format="%.2f",
            help="League-wide average points allowed at this position",
        ),
        "mpap_ratio": st.column_config.NumberColumn(
            "Ratio",
            format="%.3f",
            help="Blended allowed / league avg (>1 = weak defence)",
        ),
        "mpap_multiplier": st.column_config.NumberColumn(
            "Multiplier",
            format="%.3f",
            help="Clamped MPAP ratio applied to MAP projection",
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(
        rows, use_container_width=True, hide_index=True, column_config=col_config
    )


def _render_home_away() -> None:
    """Player Home-Away subtab: home vs away performance."""
    st.subheader("Home vs Away Splits")

    data = filter_data(load_ss_home_away(st.session_state.get("filter_round_id")))
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
        "matches_home_this_season": st.column_config.NumberColumn(
            "H Matches (This)",
            format="%d",
        ),
        "avg_points_home_this_season": st.column_config.NumberColumn(
            "H Avg (This)",
            format="%.2f",
            help="Average points in home matches this season",
        ),
        "matches_away_this_season": st.column_config.NumberColumn(
            "A Matches (This)",
            format="%d",
        ),
        "avg_points_away_this_season": st.column_config.NumberColumn(
            "A Avg (This)",
            format="%.2f",
            help="Average points in away matches this season",
        ),
        "matches_home_last_season": st.column_config.NumberColumn(
            "H Matches (Last)",
            format="%d",
        ),
        "avg_points_home_last_season": st.column_config.NumberColumn(
            "H Avg (Last)",
            format="%.2f",
            help="Average points in home matches last season",
        ),
        "matches_away_last_season": st.column_config.NumberColumn(
            "A Matches (Last)",
            format="%d",
        ),
        "avg_points_away_last_season": st.column_config.NumberColumn(
            "A Avg (Last)",
            format="%.2f",
            help="Average points in away matches last season",
        ),
        "position_avg_points_home_last_season": st.column_config.NumberColumn(
            "Pos H Avg",
            format="%.2f",
            help="Position average for home matches (last season)",
        ),
        "position_avg_points_away_last_season": st.column_config.NumberColumn(
            "Pos A Avg",
            format="%.2f",
            help="Position average for away matches (last season)",
        ),
        "home_away_delta": st.column_config.NumberColumn(
            "H/A Delta",
            format="%+.2f",
            help="Home avg minus away avg (blended). Positive = better at home",
        ),
        "multiplier_home": st.column_config.NumberColumn(
            "Home Mult",
            format="%.3f",
            help="Home venue multiplier applied to MAP, clamped 0.85-1.15",
        ),
        "multiplier_away": st.column_config.NumberColumn(
            "Away Mult",
            format="%.3f",
            help="Away venue multiplier applied to MAP, clamped 0.85-1.15",
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(
        rows, use_container_width=True, hide_index=True, column_config=col_config
    )


def _render_distribution() -> None:
    """Distribution & Volatility subtab."""
    st.subheader("Distribution & Volatility")

    data = filter_data(load_ss_distribution(st.session_state.get("filter_round_id")))
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
        "matches_played": st.column_config.NumberColumn(
            "Matches",
            format="%d",
            help="Matches included in distribution",
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
        "pts_avg": st.column_config.NumberColumn(
            "Mean",
            format="%.2f",
            help="Simple mean of scores in sample",
        ),
        "pts_stddev": st.column_config.NumberColumn(
            "Std Dev",
            format="%.2f",
            help="Standard deviation of scores",
        ),
        "cv_points": st.column_config.NumberColumn(
            "CV",
            format="%.2f",
            help="Coefficient of variation (std/mean). Higher = more volatile",
        ),
        "consistency_rating": st.column_config.TextColumn(
            "Consistency",
            help="HIGH (CV<0.5) / MED / LOW (CV>1.0)",
        ),
        "boom_rate": st.column_config.NumberColumn(
            "Boom% (≥8)",
            format="%.0f%%",
            help="Fraction of matches where player scored ≥8 points",
        ),
        "bust_rate": st.column_config.NumberColumn(
            "Bust% (≤2)",
            format="%.0f%%",
            help="Fraction of matches where player scored ≤2 points",
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]

    # Convert rates from fractions to percentages
    for row in rows:
        for col in ("boom_rate", "bust_rate"):
            if row.get(col) is not None:
                row[col] = row[col] * 100

    st.dataframe(
        rows, use_container_width=True, hide_index=True, column_config=col_config
    )


def _render_round_by_round() -> None:
    """Round-by-Round Raw subtab."""
    st.subheader("Round-by-Round Raw Data")

    data = filter_data(load_ss_round_by_round(st.session_state.get("filter_round_id")))
    if not data:
        st.info("No data available for this round.")
        return

    df = pd.DataFrame(data)

    display_cols = [
        "round",
        "match_id",
        "player_name",
        "position",
        "club_logo_url",
        "club",
        "opponent_logo_url",
        "opponent_club",
        "is_home",
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
            "match_id": st.column_config.NumberColumn(
                "Match",
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
            "opponent_logo_url": st.column_config.ImageColumn(
                "Opp",
                width="small",
            ),
            "opponent_club": st.column_config.TextColumn(
                "Opponent",
                width="small",
            ),
            "is_home": st.column_config.CheckboxColumn(
                "Home?",
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


def _render_edge_cases() -> None:
    """Edge Cases & Missing Data subtab."""
    st.subheader("Edge Cases & Missing Data")

    data = filter_data(load_ss_edge_cases())
    if not data:
        st.info("No data available.")
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
        "club": st.column_config.TextColumn(
            "Club",
            width="small",
        ),
        "has_last_season_data": st.column_config.CheckboxColumn(
            "Last Szn?",
            help="Player has enough last-season data to serve as a prior",
        ),
        "matches_last_season": st.column_config.NumberColumn(
            "Matches (Last)",
            format="%d",
        ),
        "matches_this_season": st.column_config.NumberColumn(
            "Matches (This)",
            format="%d",
        ),
        "first_round_seen": st.column_config.NumberColumn(
            "First Rd",
            format="%d",
            help="First round the player appeared",
        ),
        "last_round_seen": st.column_config.NumberColumn(
            "Last Rd",
            format="%d",
            help="Most recent round the player appeared",
        ),
        "missing_home_away_flag": st.column_config.CheckboxColumn(
            "Missing H/A?",
            help="Home/away split data is missing",
        ),
        "missing_opponent_flag": st.column_config.CheckboxColumn(
            "Missing Opp?",
            help="Opponent mapping is missing",
        ),
        "missing_points_flag": st.column_config.CheckboxColumn(
            "Missing Pts?",
            help="Points data could not be computed",
        ),
    }

    display_cols = list(col_config.keys())
    rows = [{k: row.get(k) for k in display_cols} for row in data]
    st.dataframe(
        rows, use_container_width=True, hide_index=True, column_config=col_config
    )


def main() -> None:
    """Render Start or Sit page."""
    st.title("Start or Sit")

    rounds = load_available_rounds()
    if not rounds:
        st.warning("No rounds available.")
        return

    render_sidebar_filters()

    tabs = st.tabs(
        [
            "Main",
            "MAP Breakdown",
            "Opponent & MPAP",
            "Home / Away Splits",
            "Distribution",
            "Round-by-Round",
            "Edge Cases",
        ]
    )

    with tabs[0]:
        _render_main()
    with tabs[1]:
        _render_map_breakdown()
    with tabs[2]:
        _render_mpap_debug()
    with tabs[3]:
        _render_home_away()
    with tabs[4]:
        _render_distribution()
    with tabs[5]:
        # fixit failing on this tab (Unrecognized name: as_of_round_id)
        _render_round_by_round()
    with tabs[6]:
        _render_edge_cases()

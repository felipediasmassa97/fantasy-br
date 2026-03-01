"""Shared utilities for Fantasy BR Streamlit app."""

import datetime
from typing import TYPE_CHECKING

import pandas as pd
import streamlit as st
from google.cloud import bigquery
from google.oauth2 import service_account

if TYPE_CHECKING:
    from google.cloud.firestore import Client as FirestoreClient

PROJECT_ID = "fantasy-br"
DATASET_ID = "fdmdev_fantasy_br"
DEFAULT_USER_EMAIL = "firstname.lastname@google.com"  # fixit remove
FIRESTORE_DATABASE = "fantasy-br-dev"

TIME_PERIODS = {
    "This Season": "sct_this_season",
    "Last Match": "sct_last_1",
    "Last 5 Matches": "sct_last_5",
    "Last 10 Matches": "sct_last_10",
    "Last 5 Home": "sct_last_5_home",
    "Last 5 Away": "sct_last_5_away",
    "Last Season": "sct_last_season",
}

# Scout groupings by code
SCOUTS_OFFENSIVE_CODES = ["G", "A", "FT", "FD", "FF", "FS", "PS"]
SCOUTS_DEFENSIVE_CODES = ["DS", "SG", "DE", "DP"]
SCOUTS_NEGATIVE_CODES = ["FC", "PC", "CA", "CV", "GC", "GS", "I", "PP"]

COLUMN_CONFIG = {
    "name": {
        "tooltip": "Player name",
    },
    "position": {
        "tooltip": "GK=Goalkeeper, "
        "CB=Center Back, "
        "FB=Fullback, "
        "MD=Midfielder, "
        "AT=Forward",
    },
    "club_logo_url": {
        "tooltip": "Player's club",
    },
    "matches_counted": {
        "tooltip": "Matches played.",
        "format": "%d",
    },
    "availability": {
        "tooltip": "% matches played. Higher is better.",
        "format": "%.0f%%",
    },
    "pts_avg": {
        "tooltip": "Average points per match (including G/A). Higher is better.",
        "format": "%+.1f",
    },
    "base_avg": {
        "tooltip": "Base average points per match (excluding G/A). Higher is better.",
        "format": "%+.1f",
    },
    "ga_avg": {
        "tooltip": "G/A average points per match. Higher is better.",
        "format": "%+.1f",
    },
    "z_score_pos_avg": {
        "tooltip": "Z-Score: how many standard deviations above or below top position "
        "players mean. "
        ">0 is above average. "
        "Based on average points. "
        "Higher is better.",
        "format": "%+.2f",
    },
    "z_score_gen_avg": {
        "tooltip": "Z-Score: how many standard deviations above or below top 200 "
        "players mean. "
        ">0 is above average. "
        "Based on average points. "
        "Higher is better.",
        "format": "%+.2f",
    },
    "z_score_pos_base": {
        "tooltip": "Z-Score: how many standard deviations above or below top position "
        "players mean. "
        ">0 is above average. "
        "Based on base average points. "
        "Higher is better.",
        "format": "%+.2f",
    },
    "z_score_gen_base": {
        "tooltip": "Z-Score: how many standard deviations above or below top 200 "
        "players mean. "
        ">0 is above average. "
        "Based on base average points. "
        "Higher is better.",
        "format": "%+.2f",
    },
    "dvs_pos_avg": {
        "tooltip": "Draft Value Score: z-score adjusted by availability factor. "
        "Within position and based on average points. "
        "Higher is better.",
        "format": "%+.2f",
    },
    "dvs_gen_avg": {
        "tooltip": "Draft Value Score: z-score adjusted by availability factor. "
        "Across positions and based on average points. "
        "Higher is better.",
        "format": "%+.2f",
    },
    "dvs_pos_base": {
        "tooltip": "Draft Value Score: z-score adjusted by availability factor. "
        "Within position and based on base average points. "
        "Higher is better.",
        "format": "%+.2f",
    },
    "dvs_gen_base": {
        "tooltip": "Draft Value Score: z-score adjusted by availability factor. "
        "Across positions and based on base average points. "
        "Higher is better.",
        "format": "%+.2f",
    },
    "adp_pos_avg": {
        "tooltip": "Average Draft Position: rank within position. "
        "Based on DVS Avg. "
        "Lower is better.",
        "format": "%d",
    },
    "adp_gen_avg": {
        "tooltip": "Average Draft Position: rank across positions. "
        "Based on DVS Avg. "
        "Lower is better.",
        "format": "%d",
    },
    "adp_pos_base": {
        "tooltip": "Average Draft Position: rank within position. "
        "Based on DVS Base. "
        "Lower is better.",
        "format": "%d",
    },
    "adp_gen_base": {
        "tooltip": "Average Draft Position: rank across positions. "
        "Based on DVS Base. "
        "Lower is better.",
        "format": "%d",
    },
}


@st.cache_resource
def get_client() -> bigquery.Client:
    """Get BigQuery client."""
    credentials = service_account.Credentials.from_service_account_info(
        st.secrets["gcp_service_account"],
    )
    return bigquery.Client(project=PROJECT_ID, credentials=credentials)


def _query(sql: str) -> list[dict]:
    """Execute query and return list of dicts."""
    client = get_client()
    return [dict(row) for row in client.query(sql).result()]


@st.cache_data(ttl=300)
def load_available_rounds() -> list[int]:
    """Load available rounds from BigQuery."""
    return [
        int(r["as_of_round_id"])
        for r in _query(f"""
            SELECT DISTINCT as_of_round_id
            FROM `{PROJECT_ID}.{DATASET_ID}.sct_this_season`
            ORDER BY as_of_round_id DESC
        """)  # noqa: S608
    ]


@st.cache_data(ttl=300)
def load_scouting_data(view_name: str, round_id: int | None = None) -> list[dict]:
    """Load scouting data from a BigQuery view."""
    if view_name == "sct_last_season" or round_id is None:
        return _query(f"""
            SELECT *
            FROM `{PROJECT_ID}.{DATASET_ID}.{view_name}`
            ORDER BY adp_gen_avg ASC NULLS LAST
        """)  # noqa: S608
    return _query(f"""
        SELECT *
        FROM `{PROJECT_ID}.{DATASET_ID}.{view_name}`
        WHERE as_of_round_id = {round_id}
        ORDER BY adp_gen_avg ASC NULLS LAST
    """)  # noqa: S608


@st.cache_data(ttl=300)
def load_analytics(view: str, as_of_round_id: str | None, order_by: str) -> list[dict]:
    """Load analytics."""
    where_clause = ""
    if as_of_round_id is not None:
        where_clause = f"WHERE as_of_round_id = {as_of_round_id}"

    return _query(f"""
        SELECT *
        FROM `{PROJECT_ID}.{DATASET_ID}.{view}`
        {where_clause}
        ORDER BY {order_by} DESC NULLS LAST
    """)  # noqa: S608


def load_ss_main(round_id: int) -> list[dict]:
    """Load Start or Sit main tab data."""
    return load_analytics("ss_main", round_id, "map_score")


def load_ss_map_breakdown(round_id: int) -> list[dict]:
    """Load MAP breakdown data."""
    return load_analytics("ss_map_breakdown", round_id, "map_points")


def load_ss_mpap_debug(round_id: int) -> list[dict]:
    """Load MPAP debug data."""
    return load_analytics("ss_mpap_debug", round_id, "mpap_multiplier")


def load_ss_splits(round_id: int) -> list[dict]:
    """Load player home/away splits."""
    return load_analytics("ss_splits", round_id, "home_away_delta")


def load_ss_distribution(round_id: int) -> list[dict]:
    """Load distribution and volatility data."""
    return load_analytics("ss_distribution", round_id, "median_p50")


def load_ss_round_by_round(round_id: int) -> list[dict]:
    """Load round-by-round raw data."""
    return load_analytics("ss_round_by_round", round_id, "points_total")


def load_ss_edge_cases() -> list[dict]:
    """Load edge cases and missing data."""
    return load_analytics("ss_edge_cases", None, "games_this_season")


@st.cache_data(ttl=300)
def load_mv_main(round_id: int) -> list[dict]:
    """Load Market Valuation main tab data."""
    return load_analytics("mv_main", round_id, "par")


@st.cache_data(ttl=300)
def load_mv_par_breakdown(round_id: int) -> list[dict]:
    """Load PAR breakdown data."""
    return load_analytics("mv_par_breakdown", round_id, "par_points")


@st.cache_data(ttl=300)
def load_mv_stabilized(round_id: int) -> list[dict]:
    """Load stabilized mean and shrinkage data."""
    return load_analytics("mv_stabilized", round_id, "stabilized_mean_points")


@st.cache_data(ttl=300)
def load_mv_form_trend(round_id: int) -> list[dict]:
    """Load form and trend data."""
    return load_analytics("mv_form_trend", round_id, "ewm_points")


@st.cache_data(ttl=300)
def load_mv_regression(round_id: int) -> list[dict]:
    """Load regression candidate data."""
    return load_analytics("mv_regression", round_id, "regression_score")


@st.cache_data(ttl=300)
def load_mv_value_profile(round_id: int) -> list[dict]:
    """Load value profile data."""
    return load_analytics("mv_value_profile", round_id, "par_points")


@st.cache_data(ttl=300)
def load_mv_round_by_round(round_id: int) -> list[dict]:
    """Load MV round-by-round raw data."""
    return _query(f"""
        SELECT *
        FROM `{PROJECT_ID}.{DATASET_ID}.mv_round_by_round`
        WHERE round <= {round_id}
        ORDER BY round DESC, points_total DESC NULLS LAST
    """)  # noqa: S608


@st.cache_data(ttl=3600)
def load_scout_points() -> dict[str, tuple[str, float]]:
    """Load scout points from BigQuery."""
    return {
        row["code"]: (row["description_en"], float(row["points"]))
        for row in _query(f"""
            SELECT code, description_en, points
            FROM `{PROJECT_ID}.{DATASET_ID}.raw_scout_points`
        """)  # noqa: S608
    }


def get_scout_groups(
    scout_points: dict[str, tuple[str, float]],
) -> tuple[list[tuple[str, str, float]], ...]:
    """Build scout groups from loaded scout_points data."""
    offensive = [
        (f"avg_{code}", scout_points[code][0], scout_points[code][1])
        for code in SCOUTS_OFFENSIVE_CODES
        if code in scout_points
    ]
    defensive = [
        (f"avg_{code}", scout_points[code][0], scout_points[code][1])
        for code in SCOUTS_DEFENSIVE_CODES
        if code in scout_points
    ]
    negative = [
        (f"avg_{code}", scout_points[code][0], scout_points[code][1])
        for code in SCOUTS_NEGATIVE_CODES
        if code in scout_points
    ]
    return offensive, defensive, negative


def filter_data(
    data: list[dict],
    name_filter: str,
    club_filter: str,
    position_filter: str,
) -> list[dict]:
    """Apply filters to data."""
    filtered = data
    if name_filter:
        filtered = [
            row
            for row in filtered
            if name_filter.lower() in row.get("name", "").lower()
        ]
    if club_filter != "All":
        filtered = [row for row in filtered if row.get("club") == club_filter]
    if position_filter != "All":
        filtered = [row for row in filtered if row.get("position") == position_filter]
    return filtered


def color_zscore_dvs(val: float | None) -> str:
    """Return background color for z-score and DVS values."""
    if pd.isna(val) or val is None:
        return ""
    # Clamp value between -3 and 3 for color intensity
    clamped = max(-3, min(3, val))
    intensity = abs(clamped) / 3
    if val > 0:
        # Soft green gradient: light (200,230,200) to medium (120,180,120)
        r = int(200 - 80 * intensity)
        g = int(230 - 50 * intensity)
        b = int(200 - 80 * intensity)
    else:
        # Soft red gradient: light (240,200,200) to medium (220,140,140)
        r = int(240 - 20 * intensity)
        g = int(200 - 60 * intensity)
        b = int(200 - 60 * intensity)
    return f"background-color: rgba({r},{g},{b},0.6)"


def style_dataframe(
    df: pd.DataFrame, zscore_dvs_cols: list[str]
) -> "pd.io.formats.style.Styler":
    """Apply styling to dataframe with color-coded z-score and DVS columns."""
    styler = df.style
    for col in zscore_dvs_cols:
        if col in df.columns:
            styler = styler.map(color_zscore_dvs, subset=[col])
    return styler


def get_user_email() -> str:
    """Return the current user's email (from auth or default placeholder)."""
    if hasattr(st, "user") and st.user.is_logged_in:
        return st.user.email  # type: ignore[return-value]
    return DEFAULT_USER_EMAIL


@st.cache_resource
def get_firestore_client() -> "FirestoreClient":
    """Get Firestore client."""
    from google.cloud import firestore  # noqa: PLC0415

    credentials = service_account.Credentials.from_service_account_info(
        st.secrets["gcp_service_account"],
    )
    return firestore.Client(
        project=PROJECT_ID, credentials=credentials, database=FIRESTORE_DATABASE
    )


def load_squad(user_email: str) -> list[int]:
    """Load persisted squad player IDs for a user."""
    doc = get_firestore_client().collection("user_squads").document(user_email).get()
    if doc.exists:
        return doc.to_dict().get("player_ids", [])
    return []


def load_team(user_email: str) -> list[int]:
    """Load persisted team player IDs for a user."""
    doc = get_firestore_client().collection("user_teams").document(user_email).get()
    if doc.exists:
        return doc.to_dict().get("player_ids", [])
    return []


def save_squad(user_email: str, player_ids: list[int]) -> None:
    """Persist squad for a user (replaces existing document)."""
    get_firestore_client().collection("user_squads").document(user_email).set(
        {
            "player_ids": player_ids,
            "updated_at": datetime.datetime.now(tz=datetime.UTC),
        }
    )


def save_team(user_email: str, player_ids: list[int]) -> None:
    """Persist team for a user (replaces existing document)."""
    get_firestore_client().collection("user_teams").document(user_email).set(
        {
            "player_ids": player_ids,
            "updated_at": datetime.datetime.now(tz=datetime.UTC),
        }
    )


def load_latest_round_players() -> list[dict]:
    """Load all players from the latest round (for squad selection)."""
    return _query(f"""
        SELECT DISTINCT
            id AS player_id,
            name,
            club,
            club_logo_url,
            position
        FROM `{PROJECT_ID}.{DATASET_ID}.sct_this_season`
        WHERE as_of_round_id = (
            SELECT MAX(as_of_round_id)
            FROM `{PROJECT_ID}.{DATASET_ID}.sct_this_season`
        )
        ORDER BY position, name
    """)  # noqa: S608

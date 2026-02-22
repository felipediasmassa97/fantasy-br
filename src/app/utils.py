"""Shared utilities for Fantasy BR Streamlit app."""

import pandas as pd
import streamlit as st
from google.cloud import bigquery
from google.oauth2 import service_account

PROJECT_ID = "fantasy-br"
DATASET_ID = "fdmdev_fantasy_br"

TIME_PERIODS = {
    "This Season": "kpi_this_season",
    "Last Match": "kpi_last_1",
    "Last 5 Matches": "kpi_last_5",
    "Last 10 Matches": "kpi_last_10",
    "Last 5 Home": "kpi_last_5_home",
    "Last 5 Away": "kpi_last_5_away",
    "Last Season": "kpi_last_season",
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
        "tooltip": "GK=Goalkeeper, CB=Center Back, FB=Fullback, MD=Midfielder, AT=Forward",
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
        "tooltip": "Z-Score: how many standard deviations above or below top position players mean. >0 is above average. Based on average points. Higher is better.",
        "format": "%+.2f",
    },
    "z_score_gen_avg": {
        "tooltip": "Z-Score: how many standard deviations above or below top 200 players mean. >0 is above average. Based on average points. Higher is better.",
        "format": "%+.2f",
    },
    "z_score_pos_base": {
        "tooltip": "Z-Score: how many standard deviations above or below top position players mean. >0 is above average. Based on base average points. Higher is better.",
        "format": "%+.2f",
    },
    "z_score_gen_base": {
        "tooltip": "Z-Score: how many standard deviations above or below top 200 players mean. >0 is above average. Based on base average points. Higher is better.",
        "format": "%+.2f",
    },
    "dvs_pos_avg": {
        "tooltip": "Draft Value Score: z-score adjusted by availability factor. Within position and based on average points. Higher is better.",
        "format": "%+.2f",
    },
    "dvs_gen_avg": {
        "tooltip": "Draft Value Score: z-score adjusted by availability factor. Across positions and based on average points. Higher is better.",
        "format": "%+.2f",
    },
    "dvs_pos_base": {
        "tooltip": "Draft Value Score: z-score adjusted by availability factor. Within position and based on base average points. Higher is better.",
        "format": "%+.2f",
    },
    "dvs_gen_base": {
        "tooltip": "Draft Value Score: z-score adjusted by availability factor. Across positions and based on base average points. Higher is better.",
        "format": "%+.2f",
    },
    "adp_pos_avg": {
        "tooltip": "Average Draft Position: rank within position. Based on DVS Avg. Lower is better.",
        "format": "%d",
    },
    "adp_gen_avg": {
        "tooltip": "Average Draft Position: rank across positions. Based on DVS Avg. Lower is better.",
        "format": "%d",
    },
    "adp_pos_base": {
        "tooltip": "Average Draft Position: rank within position. Based on DVS Base. Lower is better.",
        "format": "%d",
    },
    "adp_gen_base": {
        "tooltip": "Average Draft Position: rank across positions. Based on DVS Base. Lower is better.",
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


@st.cache_data(ttl=300)
def load_available_rounds() -> list[int]:
    """Load available rounds from BigQuery."""
    client = get_client()
    query = f"""
        SELECT DISTINCT as_of_round_id
        FROM `{PROJECT_ID}.{DATASET_ID}.kpi_this_season`
        ORDER BY as_of_round_id DESC
    """  # noqa: S608
    return [int(row["as_of_round_id"]) for row in client.query(query).result()]


@st.cache_data(ttl=300)
def load_kpi_data(view_name: str, round_id: int | None = None) -> list[dict]:
    """Load KPI data from a BigQuery view."""
    client = get_client()
    # kpi_last_season doesn't have as_of_round_id (previous season data)
    if view_name == "kpi_last_season" or round_id is None:
        query = f"""
            SELECT * FROM `{PROJECT_ID}.{DATASET_ID}.{view_name}`
            ORDER BY adp_gen_avg ASC NULLS LAST
        """  # noqa: S608
    else:
        query = f"""
            SELECT * FROM `{PROJECT_ID}.{DATASET_ID}.{view_name}`
            WHERE as_of_round_id = {round_id}
            ORDER BY adp_gen_avg ASC NULLS LAST
        """  # noqa: S608
    return [dict(row) for row in client.query(query).result()]


@st.cache_data(ttl=300)
def load_map_data(round_id: int) -> list[dict]:
    """Load MAP data from BigQuery."""
    client = get_client()
    query = f"""
        SELECT * FROM `{PROJECT_ID}.{DATASET_ID}.map`
        WHERE as_of_round_id = {round_id}
        ORDER BY map_score DESC NULLS LAST
    """  # noqa: S608
    return [dict(row) for row in client.query(query).result()]


@st.cache_data(ttl=300)
def load_map_baseline(round_id: int) -> list[dict]:
    """Load MAP baseline component data from BigQuery."""
    client = get_client()
    query = f"""
        SELECT * FROM `{PROJECT_ID}.{DATASET_ID}.int_map_baseline`
        WHERE as_of_round_id = {round_id}
        ORDER BY baseline_pts DESC NULLS LAST
    """  # noqa: S608
    return [dict(row) for row in client.query(query).result()]


@st.cache_data(ttl=300)
def load_map_form(round_id: int) -> list[dict]:
    """Load MAP form component data from BigQuery."""
    client = get_client()
    query = f"""
        SELECT b.name, b.position, b.club, b.club_logo_url, f.*
        FROM `{PROJECT_ID}.{DATASET_ID}.int_map_form` f
        JOIN `{PROJECT_ID}.{DATASET_ID}.int_map_baseline` b
            ON f.as_of_round_id = b.as_of_round_id AND f.id = b.id
        WHERE f.as_of_round_id = {round_id}
        ORDER BY f.form_ratio DESC NULLS LAST
    """  # noqa: S608
    return [dict(row) for row in client.query(query).result()]


@st.cache_data(ttl=300)
def load_map_venue(round_id: int) -> list[dict]:
    """Load MAP venue component data from BigQuery."""
    client = get_client()
    query = f"""
        SELECT b.name, b.position, b.club, b.club_logo_url, v.*
        FROM `{PROJECT_ID}.{DATASET_ID}.int_map_venue` v
        JOIN `{PROJECT_ID}.{DATASET_ID}.int_map_baseline` b
            ON v.as_of_round_id = b.as_of_round_id AND v.id = b.id
        WHERE v.as_of_round_id = {round_id}
        ORDER BY v.home_multiplier DESC NULLS LAST
    """  # noqa: S608
    return [dict(row) for row in client.query(query).result()]


@st.cache_data(ttl=300)
def load_map_mpap(round_id: int) -> list[dict]:
    """Load MAP MPAP (Matchup Points Allowed by Position) component data from BigQuery."""
    client = get_client()
    query = f"""
        SELECT b.name, b.club, b.club_logo_url, o.*
        FROM `{PROJECT_ID}.{DATASET_ID}.int_map_mpap` o
        JOIN `{PROJECT_ID}.{DATASET_ID}.int_map_baseline` b
            ON o.as_of_round_id = b.as_of_round_id AND o.id = b.id
        WHERE o.as_of_round_id = {round_id}
        ORDER BY o.mpap_multiplier DESC NULLS LAST
    """  # noqa: S608
    return [dict(row) for row in client.query(query).result()]


@st.cache_data(ttl=300)
def load_ewm_form(round_id: int) -> list[dict]:
    """Load EWM (Exponentially Weighted Mean) form data from BigQuery."""
    client = get_client()
    query = f"""
        SELECT * FROM `{PROJECT_ID}.{DATASET_ID}.int_ewm_form`
        WHERE as_of_round_id = {round_id}
        ORDER BY ewm_pts DESC NULLS LAST
    """  # noqa: S608
    return [dict(row) for row in client.query(query).result()]


@st.cache_data(ttl=300)
def load_par_data(round_id: int) -> list[dict]:
    """Load PAR (Points Above Replacement) data from BigQuery."""
    client = get_client()
    query = f"""
        SELECT * FROM `{PROJECT_ID}.{DATASET_ID}.par`
        WHERE as_of_round_id = {round_id}
        ORDER BY par DESC NULLS LAST
    """  # noqa: S608
    return [dict(row) for row in client.query(query).result()]


@st.cache_data(ttl=3600)
def load_scout_points() -> dict[str, tuple[str, float]]:
    """Load scout points from BigQuery."""
    client = get_client()
    query = f"""
        SELECT code, description_en, points
        FROM `{PROJECT_ID}.{DATASET_ID}.scout_points`
    """  # noqa: S608
    return {
        row["code"]: (row["description_en"], float(row["points"]))
        for row in client.query(query).result()
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
    df: pd.DataFrame,
    zscore_dvs_cols: list[str],
) -> "pd.io.formats.style.Styler":
    """Apply styling to dataframe with color-coded z-score and DVS columns."""
    styler = df.style
    for col in zscore_dvs_cols:
        if col in df.columns:
            styler = styler.map(color_zscore_dvs, subset=[col])
    return styler

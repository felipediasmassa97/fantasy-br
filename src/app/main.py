"""Streamlit app for Fantasy BR player statistics."""

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
def load_data(view_name: str, round_id: int | None = None) -> list[dict]:
    """Load data from a BigQuery view."""
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
def load_map_baseline(round_id: int) -> list[dict]:
    """Load MAP baseline data from BigQuery."""
    client = get_client()
    query = f"""
        SELECT * FROM `{PROJECT_ID}.{DATASET_ID}.map_baseline`
        WHERE as_of_round_id = {round_id}
        ORDER BY baseline_pts DESC NULLS LAST
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


def format_zscore(val: float | None) -> str:
    """Format z-score with color indicator."""
    if val is None:
        return "-"
    return f"{val:+.2f}"


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


def render_rankings_tab(data: list[dict]) -> None:
    """Render rankings overview tab."""
    st.subheader("ADP Rankings Comparison")

    col_config = {
        "name": st.column_config.TextColumn(
            "Player", width="medium", help=COLUMN_CONFIG["name"]["tooltip"]
        ),
        "position": st.column_config.TextColumn(
            "Position", width="small", help=COLUMN_CONFIG["position"]["tooltip"]
        ),
        "club_logo_url": st.column_config.ImageColumn(
            "Club", width="small", help=COLUMN_CONFIG["club_logo_url"]["tooltip"]
        ),
        "pts_avg": st.column_config.NumberColumn(
            "Pts (Avg)",
            width="small",
            format=COLUMN_CONFIG["pts_avg"]["format"],
            help=COLUMN_CONFIG["pts_avg"]["tooltip"],
        ),
        "adp_pos_avg": st.column_config.NumberColumn(
            "Pos/Avg",
            width="small",
            format=COLUMN_CONFIG["adp_pos_avg"]["format"],
            help=COLUMN_CONFIG["adp_pos_avg"]["tooltip"],
        ),
        "adp_gen_avg": st.column_config.NumberColumn(
            "Gen/Avg",
            width="small",
            format=COLUMN_CONFIG["adp_gen_avg"]["format"],
            help=COLUMN_CONFIG["adp_gen_avg"]["tooltip"],
        ),
        "base_avg": st.column_config.NumberColumn(
            "Pts (Base)",
            width="small",
            format=COLUMN_CONFIG["base_avg"]["format"],
            help=COLUMN_CONFIG["base_avg"]["tooltip"],
        ),
        "adp_pos_base": st.column_config.NumberColumn(
            "Pos/Base",
            width="small",
            format=COLUMN_CONFIG["adp_pos_base"]["format"],
            help=COLUMN_CONFIG["adp_pos_base"]["tooltip"],
        ),
        "adp_gen_base": st.column_config.NumberColumn(
            "Gen/Base",
            width="small",
            format=COLUMN_CONFIG["adp_gen_base"]["format"],
            help=COLUMN_CONFIG["adp_gen_base"]["tooltip"],
        ),
        "availability": st.column_config.ProgressColumn(
            "Availability",
            width="small",
            format=COLUMN_CONFIG["availability"]["format"],
            min_value=0,
            max_value=100,
            help=COLUMN_CONFIG["availability"]["tooltip"],
        ),
    }

    display_cols = [
        "name",
        "position",
        "club_logo_url",
        "pts_avg",
        "adp_pos_avg",
        "adp_gen_avg",
        "base_avg",
        "adp_pos_base",
        "adp_gen_base",
        "availability",
    ]

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data, width="stretch", hide_index=True, column_config=col_config
    )


def render_details_tab(
    data: list[dict],
    scout_groups: tuple[list[tuple[str, str, float]], ...],
    time_period: str,
) -> None:
    """Render detailed metrics tab."""
    scouts_offensive, scouts_defensive, scouts_negative = scout_groups
    help_text = (
        "General compares against top 200 players overall. "
        "Position-based compares against top players in same position."
    )
    scope = st.radio(
        "Metric Scope",
        ["Position-based", "General"],
        horizontal=True,
        help=help_text,
    )

    is_general = "General" in scope

    st.subheader("General Metrics" if is_general else "Position Metrics")

    if is_general:
        col_config = {
            "adp_gen_avg": st.column_config.NumberColumn(
                "Rank (Avg)",
                width="small",
                format=COLUMN_CONFIG["adp_gen_avg"]["format"],
                help=COLUMN_CONFIG["adp_gen_avg"]["tooltip"],
            ),
            "adp_gen_base": st.column_config.NumberColumn(
                "Rank (Base)",
                width="small",
                format=COLUMN_CONFIG["adp_gen_base"]["format"],
                help=COLUMN_CONFIG["adp_gen_base"]["tooltip"],
            ),
            "name": st.column_config.TextColumn(
                "Player",
                width="medium",
                help=COLUMN_CONFIG["name"]["tooltip"],
            ),
            "position": st.column_config.TextColumn(
                "Position",
                width="small",
                help=COLUMN_CONFIG["position"]["tooltip"],
            ),
            "club_logo_url": st.column_config.ImageColumn(
                "Club",
                width="small",
                help=COLUMN_CONFIG["club_logo_url"]["tooltip"],
            ),
            "matches_counted": st.column_config.NumberColumn(
                "Matches",
                width="small",
                format=COLUMN_CONFIG["matches_counted"]["format"],
                help=COLUMN_CONFIG["matches_counted"]["tooltip"],
            ),
            "availability": st.column_config.ProgressColumn(
                "Availability",
                width="small",
                format=COLUMN_CONFIG["availability"]["format"],
                min_value=0,
                max_value=100,
                help=COLUMN_CONFIG["availability"]["tooltip"],
            ),
            "pts_avg": st.column_config.NumberColumn(
                "Pts (Avg)",
                width="small",
                format=COLUMN_CONFIG["pts_avg"]["format"],
                help=COLUMN_CONFIG["pts_avg"]["tooltip"],
            ),
            "ga_avg": st.column_config.NumberColumn(
                "Pts (G/A)",
                width="small",
                format=COLUMN_CONFIG["ga_avg"]["format"],
                help=COLUMN_CONFIG["ga_avg"]["tooltip"],
            ),
            "dvs_gen_avg": st.column_config.NumberColumn(
                "DVS (Avg)",
                width="small",
                format=COLUMN_CONFIG["dvs_gen_avg"]["format"],
                help=COLUMN_CONFIG["dvs_gen_avg"]["tooltip"],
            ),
            "z_score_gen_avg": st.column_config.NumberColumn(
                "Z (Avg)",
                width="small",
                format=COLUMN_CONFIG["z_score_gen_avg"]["format"],
                help=COLUMN_CONFIG["z_score_gen_avg"]["tooltip"],
            ),
            "base_avg": st.column_config.NumberColumn(
                "Pts (Base)",
                width="small",
                format=COLUMN_CONFIG["base_avg"]["format"],
                help=COLUMN_CONFIG["base_avg"]["tooltip"],
            ),
            "dvs_gen_base": st.column_config.NumberColumn(
                "DVS (Base)",
                width="small",
                format=COLUMN_CONFIG["dvs_gen_base"]["format"],
                help=COLUMN_CONFIG["dvs_gen_base"]["tooltip"],
            ),
            "z_score_gen_base": st.column_config.NumberColumn(
                "Z (Base)",
                width="small",
                format=COLUMN_CONFIG["z_score_gen_base"]["format"],
                help=COLUMN_CONFIG["z_score_gen_base"]["tooltip"],
            ),
        }
        display_cols = [
            "adp_gen_avg",
            "adp_gen_base",
            "name",
            "position",
            "club_logo_url",
            "matches_counted",
            "availability",
            "pts_avg",
            "ga_avg",
            "dvs_gen_avg",
            "z_score_gen_avg",
            "base_avg",
            "dvs_gen_base",
            "z_score_gen_base",
        ]
    else:
        col_config = {
            "adp_pos_avg": st.column_config.NumberColumn(
                "Rank (Avg)",
                width="small",
                format=COLUMN_CONFIG["adp_pos_avg"]["format"],
                help=COLUMN_CONFIG["adp_pos_avg"]["tooltip"],
            ),
            "adp_pos_base": st.column_config.NumberColumn(
                "Rank (Base)",
                width="small",
                format=COLUMN_CONFIG["adp_pos_base"]["format"],
                help=COLUMN_CONFIG["adp_pos_base"]["tooltip"],
            ),
            "name": st.column_config.TextColumn(
                "Player",
                width="medium",
                help=COLUMN_CONFIG["name"]["tooltip"],
            ),
            "position": st.column_config.TextColumn(
                "Position",
                width="small",
                help=COLUMN_CONFIG["position"]["tooltip"],
            ),
            "club_logo_url": st.column_config.ImageColumn(
                "Club",
                width="small",
                help=COLUMN_CONFIG["club_logo_url"]["tooltip"],
            ),
            "matches_counted": st.column_config.NumberColumn(
                "Matches",
                width="small",
                format=COLUMN_CONFIG["matches_counted"]["format"],
                help=COLUMN_CONFIG["matches_counted"]["tooltip"],
            ),
            "availability": st.column_config.ProgressColumn(
                "Availability",
                width="small",
                format=COLUMN_CONFIG["availability"]["format"],
                min_value=0,
                max_value=100,
                help=COLUMN_CONFIG["availability"]["tooltip"],
            ),
            "pts_avg": st.column_config.NumberColumn(
                "Pts (Avg)",
                width="small",
                format=COLUMN_CONFIG["pts_avg"]["format"],
                help=COLUMN_CONFIG["pts_avg"]["tooltip"],
            ),
            "ga_avg": st.column_config.NumberColumn(
                "G/A",
                width="small",
                format=COLUMN_CONFIG["ga_avg"]["format"],
                help=COLUMN_CONFIG["ga_avg"]["tooltip"],
            ),
            "dvs_pos_avg": st.column_config.NumberColumn(
                "DVS (Avg)",
                width="small",
                format=COLUMN_CONFIG["dvs_pos_avg"]["format"],
                help=COLUMN_CONFIG["dvs_pos_avg"]["tooltip"],
            ),
            "z_score_pos_avg": st.column_config.NumberColumn(
                "Z (Avg)",
                width="small",
                format=COLUMN_CONFIG["z_score_pos_avg"]["format"],
                help=COLUMN_CONFIG["z_score_pos_avg"]["tooltip"],
            ),
            "base_avg": st.column_config.NumberColumn(
                "Pts (Base)",
                width="small",
                format=COLUMN_CONFIG["base_avg"]["format"],
                help=COLUMN_CONFIG["base_avg"]["tooltip"],
            ),
            "dvs_pos_base": st.column_config.NumberColumn(
                "DVS (Base)",
                width="small",
                format=COLUMN_CONFIG["dvs_pos_base"]["format"],
                help=COLUMN_CONFIG["dvs_pos_base"]["tooltip"],
            ),
            "z_score_pos_base": st.column_config.NumberColumn(
                "Z (Base)",
                width="small",
                format=COLUMN_CONFIG["z_score_pos_base"]["format"],
                help=COLUMN_CONFIG["z_score_pos_base"]["tooltip"],
            ),
        }
        display_cols = [
            "adp_pos_avg",
            "adp_pos_base",
            "name",
            "position",
            "club_logo_url",
            "matches_counted",
            "availability",
            "pts_avg",
            "ga_avg",
            "dvs_pos_avg",
            "z_score_pos_avg",
            "base_avg",
            "dvs_pos_base",
            "z_score_pos_base",
        ]

    display_data = [{k: row.get(k) for k in display_cols} for row in data]
    df = pd.DataFrame(display_data)

    # Columns to apply color styling
    if is_general:
        zscore_dvs_cols = [
            "dvs_gen_avg",
            "z_score_gen_avg",
            "dvs_gen_base",
            "z_score_gen_base",
        ]
    else:
        zscore_dvs_cols = [
            "dvs_pos_avg",
            "z_score_pos_avg",
            "dvs_pos_base",
            "z_score_pos_base",
        ]

    # Add index column for selection tracking
    df_with_idx = df.copy()
    df_with_idx.insert(0, "_idx", range(len(df_with_idx)))

    styled_df = style_dataframe(df_with_idx, zscore_dvs_cols)
    styled_df = styled_df.format(
        {
            col: "{:+.2f}"
            for col in [*zscore_dvs_cols, "pts_avg", "base_avg"]
            if col in df_with_idx.columns
        },
    )

    event = st.dataframe(
        styled_df,
        width="stretch",
        hide_index=True,
        column_config={"_idx": None, **col_config},
        selection_mode="single-row",
        on_select="rerun",
    )

    # Player scout breakdown based on dataframe selection
    selected_rows = event.selection.rows
    if selected_rows:
        selected_idx = selected_rows[0]
        player = data[selected_idx]
        st.subheader(f"Scout Breakdown: {player['name']}")
        st.caption(f"{player['position']} | {player['club']}")

        for group_name, scouts in [
            ("Offensive", scouts_offensive),
            ("Defensive", scouts_defensive),
            ("Negative", scouts_negative),
        ]:
            cols = st.columns([1.5, 1, 1])
            cols[0].markdown(f"**{group_name}**")
            cols[1].markdown(f"**Count per Match** ({time_period})")
            cols[2].markdown(f"**Points per Match** ({time_period})")

            subtotal = 0.0
            for key, desc, pts in scouts:
                code = key.replace("avg_", "")
                val = player.get(key)
                cols = st.columns([1.5, 1, 1])
                cols[0].markdown(f"{code} :gray[{desc}]")
                if val is not None:
                    cols[1].write(f"{val:.2f}")
                    cols[2].write(f"{val * pts:+.2f}")
                    subtotal += val * pts
                else:
                    cols[1].write("-")
                    cols[2].write("-")
            # Subtotal row
            cols = st.columns([1.5, 1, 1])
            cols[0].markdown("**Subtotal**")
            cols[1].write("")
            cols[2].markdown(f"**{subtotal:+.2f}**")
            st.divider()


def render_comparison_tab(  # noqa: C901, PLR0912 # fixit lint
    data: list[dict],
    scout_groups: tuple[list[tuple[str, str, float]], ...],
    time_period: str,
) -> None:
    """Render player comparison tab."""
    _ = time_period  # Used for consistency with other tabs
    scouts_offensive, scouts_defensive, scouts_negative = scout_groups
    st.subheader("Player Comparison")

    selected = st.multiselect(
        "Select players to compare (up to 5)",
        options=sorted(data, key=lambda x: x["name"]),
        format_func=lambda x: f"{x['name']} ({x['position']} - {x['club']})",
        max_selections=5,
        placeholder="Search and select players...",
    )

    if not selected:
        st.info("Select players above to compare their metrics side-by-side.")
        return

    # Build metrics list (without scouts - they are handled separately)
    metrics: list[tuple[str, str | None, str | None, str | None]] = [
        (
            "Points (Avg)",
            "pts_avg",
            COLUMN_CONFIG["pts_avg"]["format"],
            COLUMN_CONFIG["pts_avg"]["tooltip"],
        ),
        (
            "Points (Base)",
            "base_avg",
            COLUMN_CONFIG["base_avg"]["format"],
            COLUMN_CONFIG["base_avg"]["tooltip"],
        ),
        (
            "Matches",
            "matches_counted",
            COLUMN_CONFIG["matches_counted"]["format"],
            COLUMN_CONFIG["matches_counted"]["tooltip"],
        ),
        (
            "Availability",
            "availability",
            COLUMN_CONFIG["availability"]["format"],
            COLUMN_CONFIG["availability"]["tooltip"],
        ),
        (
            "",
            None,
            None,
            None,
        ),
        (
            "Position Rankings",
            None,
            None,
            None,
        ),
        (
            "ADP (Avg)",
            "adp_pos_avg",
            COLUMN_CONFIG["adp_pos_avg"]["format"],
            COLUMN_CONFIG["adp_pos_avg"]["tooltip"],
        ),
        (
            "DVS (Avg)",
            "dvs_pos_avg",
            COLUMN_CONFIG["dvs_pos_avg"]["format"],
            COLUMN_CONFIG["dvs_pos_avg"]["tooltip"],
        ),
        (
            "Z-Score (Avg)",
            "z_score_pos_avg",
            COLUMN_CONFIG["z_score_pos_avg"]["format"],
            COLUMN_CONFIG["z_score_pos_avg"]["tooltip"],
        ),
        (
            "ADP (Base)",
            "adp_pos_base",
            COLUMN_CONFIG["adp_pos_base"]["format"],
            COLUMN_CONFIG["adp_pos_base"]["tooltip"],
        ),
        (
            "DVS (Base)",
            "dvs_pos_base",
            COLUMN_CONFIG["dvs_pos_base"]["format"],
            COLUMN_CONFIG["dvs_pos_base"]["tooltip"],
        ),
        (
            "Z-Score (Base)",
            "z_score_pos_base",
            COLUMN_CONFIG["z_score_pos_base"]["format"],
            COLUMN_CONFIG["z_score_pos_base"]["tooltip"],
        ),
        (
            "",
            None,
            None,
            None,
        ),
        (
            "General Rankings",
            None,
            None,
            None,
        ),
        (
            "ADP (Avg)",
            "adp_gen_avg",
            COLUMN_CONFIG["adp_gen_avg"]["format"],
            COLUMN_CONFIG["adp_gen_avg"]["tooltip"],
        ),
        (
            "DVS (Avg)",
            "dvs_gen_avg",
            COLUMN_CONFIG["dvs_gen_avg"]["format"],
            COLUMN_CONFIG["dvs_gen_avg"]["tooltip"],
        ),
        (
            "Z-Score (Avg)",
            "z_score_gen_avg",
            COLUMN_CONFIG["z_score_gen_avg"]["format"],
            COLUMN_CONFIG["z_score_gen_avg"]["tooltip"],
        ),
        (
            "ADP (Base)",
            "adp_gen_base",
            COLUMN_CONFIG["adp_gen_base"]["format"],
            COLUMN_CONFIG["adp_gen_base"]["tooltip"],
        ),
        (
            "DVS (Base)",
            "dvs_gen_base",
            COLUMN_CONFIG["dvs_gen_base"]["format"],
            COLUMN_CONFIG["dvs_gen_base"]["tooltip"],
        ),
        (
            "Z-Score (Base)",
            "z_score_gen_base",
            COLUMN_CONFIG["z_score_gen_base"]["format"],
            COLUMN_CONFIG["z_score_gen_base"]["tooltip"],
        ),
    ]

    cols = st.columns([1.5] + [1] * len(selected))
    cols[0].markdown("**Metric**")
    for i, player in enumerate(selected):
        cols[i + 1].markdown(f"**{player['name']}**")
        cols[i + 1].caption(f"{player['position']} | {player['club']}")

    for label, key, fmt, tooltip in metrics:
        if key is None:
            if label:
                cols = st.columns([1.5] + [1] * len(selected))
                cols[0].markdown(f"**{label}**")
                for i, player in enumerate(selected):
                    cols[i + 1].markdown(f"**{player['name']}**")
                    cols[i + 1].caption(f"{player['position']} | {player['club']}")
            else:
                st.divider()
            continue

        cols = st.columns([1.5] + [1] * len(selected))
        display_label = f"{label} :gray[{tooltip}]" if tooltip else label
        cols[0].markdown(display_label)
        for i, player in enumerate(selected):
            val = player.get(key)
            if val is None:
                cols[i + 1].write("-")
            elif fmt and "%" in fmt:
                cols[i + 1].write(fmt % val)
            else:
                cols[i + 1].write(fmt % val if fmt else str(val))

    # Scout sections with subtotals
    for group_name, scouts in [
        ("Scouts per Match: Offensive", scouts_offensive),
        ("Scouts per Match: Defensive", scouts_defensive),
        ("Scouts per Match: Negative", scouts_negative),
    ]:
        st.divider()
        cols = st.columns([1.5] + [1] * len(selected))
        cols[0].markdown(f"**{group_name}**")
        for i, player in enumerate(selected):
            cols[i + 1].markdown(f"**{player['name']}**")
            cols[i + 1].caption(f"{player['position']} | {player['club']}")

        for key, desc, pts in scouts:
            code = key.replace("avg_", "")
            cols = st.columns([1.5] + [1] * len(selected))
            cols[0].markdown(f"{code} :gray[{desc} ({pts:+.1f} pts)]")
            for i, player in enumerate(selected):
                val = player.get(key)
                if val is None:
                    cols[i + 1].write("-")
                else:
                    pts_val = val * pts
                    cols[i + 1].write(f"{pts_val:+.1f} pts ({val:.2f})")

        # Subtotal row
        cols = st.columns([1.5] + [1] * len(selected))
        cols[0].markdown("**Subtotal**")
        for i, player in enumerate(selected):
            subtotal = sum((player.get(k) or 0) * p for k, _, p in scouts)
            cols[i + 1].markdown(f"**{subtotal:+.1f}**")


def render_start_sit_tab(
    map_data: list[dict],
    name_filter: str,
    club_filter: str,
    position_filter: str,
) -> None:
    """Render Start or Sit tab with MAP baseline calculations."""
    st.subheader("MAP: Baseline + Form + Home/Away + Opponent")
    st.caption(
        "Baseline: who this player is. "
        "Form: last 5 games (±20%). "
        "Home/Away: contextual (±15%). "
        "Opponent: matchup strength (0.85-1.20)."
    )

    # Apply filters
    filtered = map_data
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

    # Convert availability to percentage for display
    for row in filtered:
        if row.get("availability_last_season") is not None:
            row["availability_last_season"] = row["availability_last_season"] * 100

    col_config = {
        "name": st.column_config.TextColumn(
            "Player",
            width="medium",
            help="Player name",
        ),
        "position": st.column_config.TextColumn(
            "Position",
            width="small",
            help="GK=Goalkeeper, CB=Center Back, FB=Fullback, MD=Midfielder, AT=Forward",
        ),
        "club_logo_url": st.column_config.ImageColumn(
            "Club",
            width="small",
            help="Player's club",
        ),
        "baseline_pts": st.column_config.NumberColumn(
            "Baseline Pts",
            width="small",
            format="%.2f",
            help="Weighted baseline points combining last season and this season",
        ),
        "pts_avg_this_season": st.column_config.NumberColumn(
            "This Season Avg",
            width="small",
            format="%.2f",
            help="Average points this season (as of selected round)",
        ),
        "matches_this_season": st.column_config.NumberColumn(
            "Matches (This)",
            width="small",
            format="%d",
            help="Matches played this season",
        ),
        "pts_avg_last_5": st.column_config.NumberColumn(
            "Last 5 Avg",
            width="small",
            format="%.2f",
            help="Average points in last 5 matches (recent form)",
        ),
        "matches_last_5": st.column_config.NumberColumn(
            "Matches (L5)",
            width="small",
            format="%d",
            help="Matches played in last 5 rounds",
        ),
        "form_ratio": st.column_config.NumberColumn(
            "Form Ratio",
            width="small",
            format="%.2f",
            help="Recent form vs baseline (clamped 0.8-1.2). >1 = hot, <1 = cold.",
        ),
        "home_multiplier": st.column_config.NumberColumn(
            "Home Mult",
            width="small",
            format="%.2f",
            help="Home performance multiplier (clamped 0.85-1.15). >1 = better at home.",
        ),
        "away_multiplier": st.column_config.NumberColumn(
            "Away Mult",
            width="small",
            format="%.2f",
            help="Away performance multiplier (clamped 0.85-1.15). >1 = better away.",
        ),
        "opponent_multiplier": st.column_config.NumberColumn(
            "Opp Mult",
            width="small",
            format="%.2f",
            help="Opponent weakness (0.85-1.20). >1 = weak opponent for this position.",
        ),
        "is_home_next": st.column_config.CheckboxColumn(
            "Home?",
            width="small",
            help="Is the player playing at home in the next match?",
        ),
        "pts_avg_last_season": st.column_config.NumberColumn(
            "Last Season Avg",
            width="small",
            format="%.2f",
            help="Average points last season",
        ),
        "matches_last_season": st.column_config.NumberColumn(
            "Matches (Last)",
            width="small",
            format="%d",
            help="Matches played last season",
        ),
        "availability_last_season": st.column_config.ProgressColumn(
            "Avail (Last)",
            width="small",
            format="%.0f%%",
            min_value=0,
            max_value=100,
            help="Availability last season. Must be >30% to use weighted_seasons.",
        ),
        "position_pts_avg": st.column_config.NumberColumn(
            "Position Avg",
            width="small",
            format="%.2f",
            help="Position average from last season (used for rookies)",
        ),
        "baseline_method": st.column_config.TextColumn(
            "Method",
            width="small",
            help="weighted_seasons: >=5 matches + >30% avail. rookie_shrinkage: otherwise.",
        ),
    }

    display_cols = [
        "name",
        "position",
        "club_logo_url",
        "baseline_pts",
        "form_ratio",
        "home_multiplier",
        "away_multiplier",
        "opponent_multiplier",
        "is_home_next",
        "pts_avg_last_5",
        "matches_last_5",
        "pts_avg_this_season",
        "matches_this_season",
        "pts_avg_last_season",
        "matches_last_season",
        "availability_last_season",
        "position_pts_avg",
        "baseline_method",
    ]

    display_data = [{k: row.get(k) for k in display_cols} for row in filtered]

    st.dataframe(
        display_data, width="stretch", hide_index=True, column_config=col_config
    )


def main() -> None:
    """Run app."""
    st.set_page_config(
        page_title="Scouting Panelas", page_icon=":shallow_pan_of_food:", layout="wide"
    )

    st.title(":shallow_pan_of_food: Scouting Panelas")

    # Sidebar filters
    with st.sidebar:
        st.header("Filters")

        selected_period = st.selectbox(
            "Time Period",
            options=list(TIME_PERIODS.keys()),
            index=0,
            help="Select the time window for calculating statistics",
        )
        view_name = TIME_PERIODS[selected_period]

        # Only show round filter for current season KPIs
        selected_round = None
        if selected_period != "Last Season":
            available_rounds = load_available_rounds()
            selected_round = st.selectbox(
                "As of Round",
                options=available_rounds,
                index=0,
                format_func=lambda x: f"Round {x}",
                help="View KPIs as if this was the latest round",
            )

        with st.spinner("Loading data..."):
            data = load_data(view_name, selected_round)
            scout_points = load_scout_points()
            scout_groups = get_scout_groups(scout_points)
            # Load MAP baseline data if round is selected
            map_data = load_map_baseline(selected_round) if selected_round else []

        # Convert availability to percentage
        for row in data:
            if row.get("availability") is not None:
                row["availability"] = row["availability"] * 100

        clubs = sorted({row["club"] for row in data if row.get("club")})
        positions = ["GK", "CB", "FB", "MD", "AT"]

        st.divider()

        name_filter = st.text_input("Player Name", placeholder="Search...")
        position_filter = st.selectbox("Position", options=["All", *positions])
        club_filter = st.selectbox("Club", options=["All", *clubs])

    filtered_data = filter_data(data, name_filter, club_filter, position_filter)

    # Main tabs
    tab1, tab2, tab3, tab4 = st.tabs(
        ["Rankings Overview", "Detailed Metrics", "Compare Players", "Start or Sit"],
    )

    with tab1:
        render_rankings_tab(filtered_data)

    with tab2:
        render_details_tab(filtered_data, scout_groups, selected_period)

    with tab3:
        render_comparison_tab(filtered_data, scout_groups, selected_period)

    with tab4:
        if selected_round:
            render_start_sit_tab(map_data, name_filter, club_filter, position_filter)
        else:
            st.info("Select a round to view MAP calculations.")


if __name__ == "__main__":
    main()

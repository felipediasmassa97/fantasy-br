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
    "Last 3 Home": "kpi_last_3_home",
    "Last 3 Away": "kpi_last_3_away",
    "Last Season": "kpi_last_season",
}

# Scout groupings by code
SCOUTS_OFFENSIVE_CODES = ["G", "A", "FT", "FD", "FF", "FS", "PS"]
SCOUTS_DEFENSIVE_CODES = ["DS", "SG", "DE", "DP"]
SCOUTS_NEGATIVE_CODES = ["FC", "PC", "CA", "CV", "GC", "GS", "I", "PP"]


@st.cache_resource
def get_client() -> bigquery.Client:
    """Get BigQuery client."""
    credentials = service_account.Credentials.from_service_account_info(
        st.secrets["gcp_service_account"],
    )
    return bigquery.Client(project=PROJECT_ID, credentials=credentials)


@st.cache_data(ttl=300)
def load_data(view_name: str) -> list[dict]:
    """Load data from a BigQuery view."""
    client = get_client()
    query = f"""
        SELECT * FROM `{PROJECT_ID}.{DATASET_ID}.{view_name}`
        ORDER BY adp_gen_avg ASC NULLS LAST
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
            "Player",
            width="medium",
        ),
        "position": st.column_config.TextColumn(
            "Position",
            width="small",
        ),
        "club": st.column_config.TextColumn(
            "Club",
            width="small",
        ),
        "pts_avg": st.column_config.NumberColumn(
            "Pts (Avg)", width="small", format="%+.1f"
        ),
        "adp_pos_avg": st.column_config.NumberColumn(
            "Pos/Avg",
            width="small",
            format="%d",
            help="Position ranking by average points",
        ),
        "adp_gen_avg": st.column_config.NumberColumn(
            "Gen/Avg",
            width="small",
            format="%d",
            help="General ranking by average points",
        ),
        "base_avg": st.column_config.NumberColumn(
            "Pts (Base)",
            width="small",
            format="%+.1f",
        ),
        "adp_pos_base": st.column_config.NumberColumn(
            "Pos/Base",
            width="small",
            format="%d",
            help="Position ranking by base average",
        ),
        "adp_gen_base": st.column_config.NumberColumn(
            "Gen/Base",
            width="small",
            format="%d",
            help="General ranking by base average",
        ),
        "availability": st.column_config.ProgressColumn(
            "Availability",
            width="small",
            format="%.0f%%",
            min_value=0,
            max_value=100,
        ),
    }

    display_cols = [
        "name",
        "position",
        "club",
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
                format="%d",
            ),
            "adp_gen_base": st.column_config.NumberColumn(
                "Rank (Base)",
                width="small",
                format="%d",
            ),
            "name": st.column_config.TextColumn(
                "Player",
                width="medium",
            ),
            "position": st.column_config.TextColumn(
                "Position",
                width="small",
            ),
            "club": st.column_config.TextColumn(
                "Club",
                width="small",
            ),
            "matches_counted": st.column_config.NumberColumn(
                "Matches",
                width="small",
                format="%d",
            ),
            "availability": st.column_config.ProgressColumn(
                "Availability",
                width="small",
                format="%.0f%%",
                min_value=0,
                max_value=100,
            ),
            "pts_avg": st.column_config.NumberColumn(
                "Pts (Avg)",
                width="small",
                format="%+.2f",
            ),
            "dvs_gen_avg": st.column_config.NumberColumn(
                "DVS (Avg)",
                width="small",
                format="%+.2f",
            ),
            "z_score_gen_avg": st.column_config.NumberColumn(
                "Z (Avg)",
                width="small",
                format="%+.2f",
            ),
            "base_avg": st.column_config.NumberColumn(
                "Pts (Base)",
                width="small",
                format="%+.2f",
            ),
            "dvs_gen_base": st.column_config.NumberColumn(
                "DVS (Base)",
                width="small",
                format="%+.2f",
            ),
            "z_score_gen_base": st.column_config.NumberColumn(
                "Z (Base)",
                width="small",
                format="%+.2f",
            ),
        }
        display_cols = [
            "adp_gen_avg",
            "adp_gen_base",
            "name",
            "position",
            "club",
            "matches_counted",
            "availability",
            "pts_avg",
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
                format="%d",
            ),
            "adp_pos_base": st.column_config.NumberColumn(
                "Rank (Base)",
                width="small",
                format="%d",
            ),
            "name": st.column_config.TextColumn(
                "Player",
                width="medium",
            ),
            "position": st.column_config.TextColumn(
                "Position",
                width="small",
            ),
            "club": st.column_config.TextColumn(
                "Club",
                width="small",
            ),
            "matches_counted": st.column_config.NumberColumn(
                "Matches",
                width="small",
                format="%d",
            ),
            "availability": st.column_config.ProgressColumn(
                "Availability",
                width="small",
                format="%.0f%%",
                min_value=0,
                max_value=100,
            ),
            "pts_avg": st.column_config.NumberColumn(
                "Pts (Avg)",
                width="small",
                format="%+.2f",
            ),
            "dvs_pos_avg": st.column_config.NumberColumn(
                "DVS (Avg)",
                width="small",
                format="%+.2f",
            ),
            "z_score_pos_avg": st.column_config.NumberColumn(
                "Z (Avg)",
                width="small",
                format="%+.2f",
            ),
            "base_avg": st.column_config.NumberColumn(
                "Pts (Base)",
                width="small",
                format="%+.2f",
            ),
            "dvs_pos_base": st.column_config.NumberColumn(
                "DVS (Base)",
                width="small",
                format="%+.2f",
            ),
            "z_score_pos_base": st.column_config.NumberColumn(
                "Z (Base)",
                width="small",
                format="%+.2f",
            ),
        }
        display_cols = [
            "adp_pos_avg",
            "adp_pos_base",
            "name",
            "position",
            "club",
            "matches_counted",
            "availability",
            "pts_avg",
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
            cols[1].markdown("**Count**")
            cols[2].markdown("**Points**")

            for key, desc, pts in scouts:
                code = key.replace("avg_", "")
                val = player.get(key)
                cols = st.columns([1.5, 1, 1])
                cols[0].markdown(f"{code} :gray[{desc}]")
                if val is not None:
                    cols[1].write(f"{val:.2f}")
                    cols[2].write(f"{val * pts:+.2f}")
                else:
                    cols[1].write("-")
                    cols[2].write("-")
            st.divider()


def render_comparison_tab(
    data: list[dict],
    scout_groups: tuple[list[tuple[str, str, float]], ...],
) -> None:
    """Render player comparison tab."""
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

    # Build metrics list including scouts
    metrics: list[tuple[str, str | None, str | None, str | None, float | None]] = [
        ("Points (Avg)", "pts_avg", "%+.2f", None, None),
        ("Points (Base)", "base_avg", "%+.2f", None, None),
        ("Matches", "matches_counted", "%d", None, None),
        ("Availability", "availability", "%.0f%%", None, None),
        ("", None, None, None, None),
        ("Position Rankings", None, None, None, None),
        ("ADP (Avg)", "adp_pos_avg", "%d", None, None),
        ("DVS (Avg)", "dvs_pos_avg", "%+.2f", None, None),
        ("Z-Score (Avg)", "z_score_pos_avg", "%+.2f", None, None),
        ("ADP (Base)", "adp_pos_base", "%d", None, None),
        ("DVS (Base)", "dvs_pos_base", "%+.2f", None, None),
        ("Z-Score (Base)", "z_score_pos_base", "%+.2f", None, None),
        ("", None, None, None, None),
        ("General Rankings", None, None, None, None),
        ("ADP (Avg)", "adp_gen_avg", "%d", None, None),
        ("DVS (Avg)", "dvs_gen_avg", "%+.2f", None, None),
        ("Z-Score (Avg)", "z_score_gen_avg", "%+.2f", None, None),
        ("ADP (Base)", "adp_gen_base", "%d", None, None),
        ("DVS (Base)", "dvs_gen_base", "%+.2f", None, None),
        ("Z-Score (Base)", "z_score_gen_base", "%+.2f", None, None),
        ("", None, None, None, None),
        ("Scouts: Offensive", None, None, None, None),
    ]
    for key, desc, pts in scouts_offensive:
        code = key.replace("avg_", "")
        metrics.append((code, key, None, f"{desc} ({pts:+.1f} pts)", pts))
    metrics.append(("", None, None, None, None))
    metrics.append(("Scouts: Defensive", None, None, None, None))
    for key, desc, pts in scouts_defensive:
        code = key.replace("avg_", "")
        metrics.append((code, key, None, f"{desc} ({pts:+.1f} pts)", pts))
    metrics.append(("", None, None, None, None))
    metrics.append(("Scouts: Negative", None, None, None, None))
    for key, desc, pts in scouts_negative:
        code = key.replace("avg_", "")
        metrics.append((code, key, None, f"{desc} ({pts:+.1f} pts)", pts))

    cols = st.columns([1.5] + [1] * len(selected))
    cols[0].markdown("**Metric**")
    for i, player in enumerate(selected):
        cols[i + 1].markdown(f"**{player['name']}**")
        cols[i + 1].caption(f"{player['position']} | {player['club']}")

    for label, key, fmt, tooltip, scout_pts in metrics:
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
            elif scout_pts is not None:
                # Scout metric: show points (count)
                pts_val = val * scout_pts
                cols[i + 1].write(f"{pts_val:+.1f} pts ({val:.2f})")
            elif fmt and "%" in fmt:
                cols[i + 1].write(fmt % val)
            else:
                cols[i + 1].write(fmt % val if fmt else str(val))


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
        )
        view_name = TIME_PERIODS[selected_period]

        with st.spinner("Loading data..."):
            data = load_data(view_name)
            scout_points = load_scout_points()
            scout_groups = get_scout_groups(scout_points)

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
    tab1, tab2, tab3 = st.tabs(
        ["Rankings Overview", "Detailed Metrics", "Compare Players"],
    )

    with tab1:
        render_rankings_tab(filtered_data)

    with tab2:
        render_details_tab(filtered_data, scout_groups)

    with tab3:
        render_comparison_tab(filtered_data, scout_groups)


if __name__ == "__main__":
    main()

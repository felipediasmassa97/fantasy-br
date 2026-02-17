"""Streamlit app for Fantasy BR player statistics."""

import streamlit as st
from google.cloud import bigquery
from google.oauth2 import service_account

PROJECT_ID = "fantasy-br"
DATASET_ID = "fdmdev_fantasy_br"

TIME_PERIODS = {
    "This Season": "kpi_this_season",
    "Last Season": "kpi_last_season",
    "Last Match": "kpi_last_1",
    "Last 5 Matches": "kpi_last_5",
    "Last 3 Home": "kpi_last_3_home",
    "Last 3 Away": "kpi_last_3_away",
}


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


def render_rankings_tab(data: list[dict]) -> None:
    """Render rankings overview tab."""
    st.subheader("ADP Rankings Comparison")
    st.caption("Compare player rankings across different metrics and scopes")

    col_config = {
        "name": st.column_config.TextColumn("Player", width="medium"),
        "club": st.column_config.TextColumn("Club", width="small"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "adp_gen_avg": st.column_config.NumberColumn(
            "Gen/Avg",
            format="%d",
            help="General ranking by average points",
        ),
        "adp_gen_base": st.column_config.NumberColumn(
            "Gen/Base",
            format="%d",
            help="General ranking by base average",
        ),
        "adp_pos_avg": st.column_config.NumberColumn(
            "Pos/Avg",
            format="%d",
            help="Position ranking by average points",
        ),
        "adp_pos_base": st.column_config.NumberColumn(
            "Pos/Base",
            format="%d",
            help="Position ranking by base average",
        ),
        "pts_avg": st.column_config.NumberColumn("Pts Avg", format="%.1f"),
        "base_avg": st.column_config.NumberColumn("Base Avg", format="%.1f"),
        "availability": st.column_config.ProgressColumn(
            "Avail",
            format="%.0f%%",
            min_value=0,
            max_value=100,
        ),
    }

    display_cols = [
        "name",
        "club",
        "position",
        "adp_gen_avg",
        "adp_gen_base",
        "adp_pos_avg",
        "adp_pos_base",
        "pts_avg",
        "base_avg",
        "availability",
    ]

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data,
        use_container_width=True,
        hide_index=True,
        column_config=col_config,
    )


def render_details_tab(data: list[dict]) -> None:
    """Render detailed metrics tab."""
    help_text = (
        "General compares against top 200 players overall. "
        "Position-based compares against top players in same position."
    )
    scope = st.radio(
        "Metric Scope",
        ["General (Top 200)", "Position-based"],
        horizontal=True,
        help=help_text,
    )

    is_general = "General" in scope

    st.subheader("Average Points Metrics" if is_general else "Position Metrics")

    if is_general:
        col_config = {
            "adp_gen_avg": st.column_config.NumberColumn("Rank (Avg)", format="%d"),
            "adp_gen_base": st.column_config.NumberColumn("Rank (Base)", format="%d"),
            "name": st.column_config.TextColumn("Player", width="medium"),
            "club": st.column_config.TextColumn("Club", width="small"),
            "position": st.column_config.TextColumn("Pos", width="small"),
            "dvs_gen_avg": st.column_config.NumberColumn("DVS (Avg)", format="%.2f"),
            "dvs_gen_base": st.column_config.NumberColumn("DVS (Base)", format="%.2f"),
            "z_score_gen_avg": st.column_config.NumberColumn("Z (Avg)", format="%+.2f"),
            "z_score_gen_base": st.column_config.NumberColumn(
                "Z (Base)",
                format="%+.2f",
            ),
            "pts_avg": st.column_config.NumberColumn("Pts Avg", format="%.1f"),
            "base_avg": st.column_config.NumberColumn("Base Avg", format="%.1f"),
            "matches_counted": st.column_config.NumberColumn("Matches", format="%d"),
            "availability": st.column_config.ProgressColumn(
                "Avail",
                format="%.0f%%",
                min_value=0,
                max_value=100,
            ),
        }
        display_cols = [
            "adp_gen_avg",
            "adp_gen_base",
            "name",
            "club",
            "position",
            "dvs_gen_avg",
            "dvs_gen_base",
            "z_score_gen_avg",
            "z_score_gen_base",
            "pts_avg",
            "base_avg",
            "matches_counted",
            "availability",
        ]
    else:
        col_config = {
            "adp_pos_avg": st.column_config.NumberColumn("Rank (Avg)", format="%d"),
            "adp_pos_base": st.column_config.NumberColumn("Rank (Base)", format="%d"),
            "name": st.column_config.TextColumn("Player", width="medium"),
            "club": st.column_config.TextColumn("Club", width="small"),
            "position": st.column_config.TextColumn("Pos", width="small"),
            "dvs_pos_avg": st.column_config.NumberColumn("DVS (Avg)", format="%.2f"),
            "dvs_pos_base": st.column_config.NumberColumn("DVS (Base)", format="%.2f"),
            "z_score_pos_avg": st.column_config.NumberColumn("Z (Avg)", format="%+.2f"),
            "z_score_pos_base": st.column_config.NumberColumn(
                "Z (Base)",
                format="%+.2f",
            ),
            "pts_avg": st.column_config.NumberColumn("Pts Avg", format="%.1f"),
            "base_avg": st.column_config.NumberColumn("Base Avg", format="%.1f"),
            "matches_counted": st.column_config.NumberColumn("Matches", format="%d"),
            "availability": st.column_config.ProgressColumn(
                "Avail",
                format="%.0f%%",
                min_value=0,
                max_value=100,
            ),
        }
        display_cols = [
            "adp_pos_avg",
            "adp_pos_base",
            "name",
            "club",
            "position",
            "dvs_pos_avg",
            "dvs_pos_base",
            "z_score_pos_avg",
            "z_score_pos_base",
            "pts_avg",
            "base_avg",
            "matches_counted",
            "availability",
        ]

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data,
        use_container_width=True,
        hide_index=True,
        column_config=col_config,
    )


def render_comparison_tab(data: list[dict]) -> None:
    """Render player comparison tab."""
    st.subheader("Player Comparison")

    player_names = [row["name"] for row in data if row.get("name")]

    selected = st.multiselect(
        "Select players to compare (up to 5)",
        options=player_names,
        max_selections=5,
        placeholder="Search and select players...",
    )

    if not selected:
        st.info("Select players above to compare their metrics side-by-side.")
        return

    selected_data = [row for row in data if row.get("name") in selected]

    metrics = [
        ("Points Average", "pts_avg", "%.1f"),
        ("Base Average", "base_avg", "%.1f"),
        ("Availability", "availability", "%.0f%%"),
        ("Matches", "matches_counted", "%d"),
        ("", None, None),
        ("General Rankings", None, None),
        ("ADP (Avg)", "adp_gen_avg", "%d"),
        ("ADP (Base)", "adp_gen_base", "%d"),
        ("DVS (Avg)", "dvs_gen_avg", "%.2f"),
        ("DVS (Base)", "dvs_gen_base", "%.2f"),
        ("Z-Score (Avg)", "z_score_gen_avg", "%+.2f"),
        ("Z-Score (Base)", "z_score_gen_base", "%+.2f"),
        ("", None, None),
        ("Position Rankings", None, None),
        ("ADP (Avg)", "adp_pos_avg", "%d"),
        ("ADP (Base)", "adp_pos_base", "%d"),
        ("DVS (Avg)", "dvs_pos_avg", "%.2f"),
        ("DVS (Base)", "dvs_pos_base", "%.2f"),
        ("Z-Score (Avg)", "z_score_pos_avg", "%+.2f"),
        ("Z-Score (Base)", "z_score_pos_base", "%+.2f"),
    ]

    cols = st.columns([1.5] + [1] * len(selected))
    cols[0].markdown("**Metric**")
    for i, player in enumerate(selected_data):
        cols[i + 1].markdown(f"**{player['name']}**")
        cols[i + 1].caption(f"{player['club']} | {player['position']}")

    for label, key, fmt in metrics:
        if key is None:
            if label:
                cols = st.columns([1.5] + [1] * len(selected))
                cols[0].markdown(f"**{label}**")
                for i in range(len(selected)):
                    cols[i + 1].markdown("---")
            else:
                st.divider()
            continue

        cols = st.columns([1.5] + [1] * len(selected))
        cols[0].write(label)
        for i, player in enumerate(selected_data):
            val = player.get(key)
            if val is None:
                cols[i + 1].write("-")
            elif "%" in fmt:
                cols[i + 1].write(fmt % val)
            else:
                cols[i + 1].write(fmt % val)


def main() -> None:
    """Run app."""
    st.set_page_config(page_title="Fantasy BR", page_icon="⚽", layout="wide")

    st.title("Fantasy BR - Draft Board")

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

        # Convert availability to percentage
        for row in data:
            if row.get("availability") is not None:
                row["availability"] = row["availability"] * 100

        clubs = sorted({row["club"] for row in data if row.get("club")})
        positions = sorted({row["position"] for row in data if row.get("position")})

        st.divider()

        position_filter = st.selectbox("Position", options=["All", *positions])
        club_filter = st.selectbox("Club", options=["All", *clubs])
        name_filter = st.text_input("Player Name", placeholder="Search...")

        st.divider()
        st.caption(f"Showing {selected_period}")

    filtered_data = filter_data(data, name_filter, club_filter, position_filter)

    st.caption(f"{len(filtered_data)} players")

    # Main tabs
    tab1, tab2, tab3 = st.tabs(
        ["Rankings Overview", "Detailed Metrics", "Compare Players"],
    )

    with tab1:
        render_rankings_tab(filtered_data)

    with tab2:
        render_details_tab(filtered_data)

    with tab3:
        render_comparison_tab(filtered_data)


if __name__ == "__main__":
    main()

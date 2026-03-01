"""Scouting page for Fantasy BR - Rankings, Detailed Metrics, and Player Comparison."""

import pandas as pd
import streamlit as st
from utils import (
    COLUMN_CONFIG,
    TIME_PERIODS,
    filter_data,
    get_scout_groups,
    load_available_rounds,
    load_scout_points,
    load_scouting_data,
    style_dataframe,
)

PAGE_COLUMN_CONFIG = {
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


def render_rankings_tab(data: list[dict]) -> None:
    """Render rankings overview tab."""
    st.subheader("ADP Rankings Comparison")

    col_config = {
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
        "pts_avg": st.column_config.NumberColumn(
            "Pts (Avg)",
            width="small",
            format=COLUMN_CONFIG["pts_avg"]["format"],
            help=COLUMN_CONFIG["pts_avg"]["tooltip"],
        ),
        "adp_pos_avg": st.column_config.NumberColumn(
            "Pos/Avg",
            width="small",
            format=PAGE_COLUMN_CONFIG["adp_pos_avg"]["format"],
            help=PAGE_COLUMN_CONFIG["adp_pos_avg"]["tooltip"],
        ),
        "adp_gen_avg": st.column_config.NumberColumn(
            "Gen/Avg",
            width="small",
            format=PAGE_COLUMN_CONFIG["adp_gen_avg"]["format"],
            help=PAGE_COLUMN_CONFIG["adp_gen_avg"]["tooltip"],
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
            format=PAGE_COLUMN_CONFIG["adp_pos_base"]["format"],
            help=PAGE_COLUMN_CONFIG["adp_pos_base"]["tooltip"],
        ),
        "adp_gen_base": st.column_config.NumberColumn(
            "Gen/Base",
            width="small",
            format=PAGE_COLUMN_CONFIG["adp_gen_base"]["format"],
            help=PAGE_COLUMN_CONFIG["adp_gen_base"]["tooltip"],
        ),
        "availability": st.column_config.ProgressColumn(
            "Availability",
            width="small",
            format=COLUMN_CONFIG["availability"]["format"],
            help=COLUMN_CONFIG["availability"]["tooltip"],
            min_value=0,
            max_value=100,
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
                format=PAGE_COLUMN_CONFIG["adp_gen_avg"]["format"],
                help=PAGE_COLUMN_CONFIG["adp_gen_avg"]["tooltip"],
            ),
            "adp_gen_base": st.column_config.NumberColumn(
                "Rank (Base)",
                width="small",
                format=PAGE_COLUMN_CONFIG["adp_gen_base"]["format"],
                help=PAGE_COLUMN_CONFIG["adp_gen_base"]["tooltip"],
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
                help=COLUMN_CONFIG["availability"]["tooltip"],
                min_value=0,
                max_value=100,
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
                format=PAGE_COLUMN_CONFIG["dvs_gen_avg"]["format"],
                help=PAGE_COLUMN_CONFIG["dvs_gen_avg"]["tooltip"],
            ),
            "z_score_gen_avg": st.column_config.NumberColumn(
                "Z (Avg)",
                width="small",
                format=PAGE_COLUMN_CONFIG["z_score_gen_avg"]["format"],
                help=PAGE_COLUMN_CONFIG["z_score_gen_avg"]["tooltip"],
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
                format=PAGE_COLUMN_CONFIG["dvs_gen_base"]["format"],
                help=PAGE_COLUMN_CONFIG["dvs_gen_base"]["tooltip"],
            ),
            "z_score_gen_base": st.column_config.NumberColumn(
                "Z (Base)",
                width="small",
                format=PAGE_COLUMN_CONFIG["z_score_gen_base"]["format"],
                help=PAGE_COLUMN_CONFIG["z_score_gen_base"]["tooltip"],
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
                format=PAGE_COLUMN_CONFIG["adp_pos_avg"]["format"],
                help=PAGE_COLUMN_CONFIG["adp_pos_avg"]["tooltip"],
            ),
            "adp_pos_base": st.column_config.NumberColumn(
                "Rank (Base)",
                width="small",
                format=PAGE_COLUMN_CONFIG["adp_pos_base"]["format"],
                help=PAGE_COLUMN_CONFIG["adp_pos_base"]["tooltip"],
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
                help=COLUMN_CONFIG["availability"]["tooltip"],
                min_value=0,
                max_value=100,
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
                format=PAGE_COLUMN_CONFIG["dvs_pos_avg"]["format"],
                help=PAGE_COLUMN_CONFIG["dvs_pos_avg"]["tooltip"],
            ),
            "z_score_pos_avg": st.column_config.NumberColumn(
                "Z (Avg)",
                width="small",
                format=PAGE_COLUMN_CONFIG["z_score_pos_avg"]["format"],
                help=PAGE_COLUMN_CONFIG["z_score_pos_avg"]["tooltip"],
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
                format=PAGE_COLUMN_CONFIG["dvs_pos_base"]["format"],
                help=PAGE_COLUMN_CONFIG["dvs_pos_base"]["tooltip"],
            ),
            "z_score_pos_base": st.column_config.NumberColumn(
                "Z (Base)",
                width="small",
                format=PAGE_COLUMN_CONFIG["z_score_pos_base"]["format"],
                help=PAGE_COLUMN_CONFIG["z_score_pos_base"]["tooltip"],
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


def render_comparison_tab(
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
            PAGE_COLUMN_CONFIG["adp_pos_avg"]["format"],
            PAGE_COLUMN_CONFIG["adp_pos_avg"]["tooltip"],
        ),
        (
            "DVS (Avg)",
            "dvs_pos_avg",
            PAGE_COLUMN_CONFIG["dvs_pos_avg"]["format"],
            PAGE_COLUMN_CONFIG["dvs_pos_avg"]["tooltip"],
        ),
        (
            "Z-Score (Avg)",
            "z_score_pos_avg",
            PAGE_COLUMN_CONFIG["z_score_pos_avg"]["format"],
            PAGE_COLUMN_CONFIG["z_score_pos_avg"]["tooltip"],
        ),
        (
            "ADP (Base)",
            "adp_pos_base",
            PAGE_COLUMN_CONFIG["adp_pos_base"]["format"],
            PAGE_COLUMN_CONFIG["adp_pos_base"]["tooltip"],
        ),
        (
            "DVS (Base)",
            "dvs_pos_base",
            PAGE_COLUMN_CONFIG["dvs_pos_base"]["format"],
            PAGE_COLUMN_CONFIG["dvs_pos_base"]["tooltip"],
        ),
        (
            "Z-Score (Base)",
            "z_score_pos_base",
            PAGE_COLUMN_CONFIG["z_score_pos_base"]["format"],
            PAGE_COLUMN_CONFIG["z_score_pos_base"]["tooltip"],
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
            PAGE_COLUMN_CONFIG["adp_gen_avg"]["format"],
            PAGE_COLUMN_CONFIG["adp_gen_avg"]["tooltip"],
        ),
        (
            "DVS (Avg)",
            "dvs_gen_avg",
            PAGE_COLUMN_CONFIG["dvs_gen_avg"]["format"],
            PAGE_COLUMN_CONFIG["dvs_gen_avg"]["tooltip"],
        ),
        (
            "Z-Score (Avg)",
            "z_score_gen_avg",
            PAGE_COLUMN_CONFIG["z_score_gen_avg"]["format"],
            PAGE_COLUMN_CONFIG["z_score_gen_avg"]["tooltip"],
        ),
        (
            "ADP (Base)",
            "adp_gen_base",
            PAGE_COLUMN_CONFIG["adp_gen_base"]["format"],
            PAGE_COLUMN_CONFIG["adp_gen_base"]["tooltip"],
        ),
        (
            "DVS (Base)",
            "dvs_gen_base",
            PAGE_COLUMN_CONFIG["dvs_gen_base"]["format"],
            PAGE_COLUMN_CONFIG["dvs_gen_base"]["tooltip"],
        ),
        (
            "Z-Score (Base)",
            "z_score_gen_base",
            PAGE_COLUMN_CONFIG["z_score_gen_base"]["format"],
            PAGE_COLUMN_CONFIG["z_score_gen_base"]["tooltip"],
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


def main() -> None:
    """Run Scouting page."""
    st.title("🔍 Scouting")
    st.caption("Player rankings, detailed metrics, and comparison tools")

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
            data = load_scouting_data(view_name, selected_round)
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
        render_details_tab(filtered_data, scout_groups, selected_period)

    with tab3:
        render_comparison_tab(filtered_data, scout_groups, selected_period)


if __name__ == "__main__":
    main()

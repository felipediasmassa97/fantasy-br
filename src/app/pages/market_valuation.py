"""Market Valuation page for Fantasy BR - Player value analysis."""

import streamlit as st
from utils import filter_data, load_available_rounds, load_par_data


def render_par_tab(data: list[dict]) -> None:
    """Render PAR (Points Above Replacement) tab."""
    st.subheader("Points Above Replacement (PAR)")
    st.caption(
        "PAR = baseline_pts - replacement_level. "
        "Measures value over a replacement-level player at the same position."
    )

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
        "par": st.column_config.NumberColumn(
            "PAR",
            width="small",
            format="%.2f",
            help="Points Above Replacement. Positive = better than replacement level.",
        ),
        "baseline_pts": st.column_config.NumberColumn(
            "Baseline",
            width="small",
            format="%.2f",
            help="Player's expected baseline points",
        ),
        "replacement_level": st.column_config.NumberColumn(
            "Replacement",
            width="small",
            format="%.2f",
            help="Replacement level for this position (percentile-based)",
        ),
        "replacement_pct": st.column_config.NumberColumn(
            "Rep %",
            width="small",
            format="%.0f%%",
            help="Percentile used to define replacement level for this position",
        ),
        "baseline_method": st.column_config.TextColumn(
            "Method",
            width="small",
            help="weighted_seasons or rookie_shrinkage",
        ),
    }

    display_cols = [
        "name",
        "position",
        "club_logo_url",
        "par",
        "baseline_pts",
        "replacement_level",
        "replacement_pct",
        "baseline_method",
    ]

    # Convert replacement_pct to percentage display
    for row in data:
        if row.get("replacement_pct") is not None:
            row["replacement_pct"] = row["replacement_pct"] * 100

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data, width="stretch", hide_index=True, column_config=col_config
    )


def main() -> None:
    """Run Market Valuation page."""
    st.title("💰 Market Valuation")
    st.caption("Player value analysis and market opportunities")

    # Sidebar filters
    with st.sidebar:
        st.header("Filters")

        available_rounds = load_available_rounds()
        selected_round = st.selectbox(
            "As of Round",
            options=available_rounds,
            index=0,
            format_func=lambda x: f"Round {x}",
            help="View metrics as if this was the latest round",
        )

        with st.spinner("Loading PAR data..."):
            par_data = load_par_data(selected_round)

        clubs = sorted({row["club"] for row in par_data if row.get("club")})
        positions = ["GK", "CB", "FB", "MD", "AT"]

        st.divider()

        name_filter = st.text_input("Player Name", placeholder="Search...")
        position_filter = st.selectbox("Position", options=["All", *positions])
        club_filter = st.selectbox("Club", options=["All", *clubs])

    # Apply filters
    filtered_par = filter_data(par_data, name_filter, club_filter, position_filter)

    # Main tabs
    tab_par, tab_future = st.tabs(["PAR Rankings", "More Metrics (Coming Soon)"])

    with tab_par:
        render_par_tab(filtered_par)

    with tab_future:
        st.info("Additional market valuation metrics will be added in future updates.")
        st.markdown(
            """
            ### Planned Features

            - **Price vs Performance**: Compare player prices to their expected output
            - **Value Opportunities**: Identify underpriced players
            - **Price Trends**: Track price changes over time
            - **Budget Optimization**: Build optimal teams within budget constraints
            """
        )


if __name__ == "__main__":
    main()

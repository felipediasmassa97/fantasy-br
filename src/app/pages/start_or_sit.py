"""Start or Sit page for Fantasy BR - MAP (Matchup-Adjusted Projection) metrics."""

import streamlit as st
from utils import (
    filter_data,
    load_available_rounds,
    load_map_baseline,
    load_map_data,
    load_map_form,
    load_map_opponent,
    load_map_venue,
)


def render_map_overview_tab(data: list[dict]) -> None:
    """Render MAP overview tab with final scores."""
    st.subheader("MAP Score Overview")
    st.caption(
        "MAP = Baseline x Form x Venue x Opponent. "
        "Proxy for expected points in the next match."
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
        "map_score": st.column_config.NumberColumn(
            "MAP",
            width="small",
            format="%.2f",
            help="Matchup-Adjusted Projection: baseline x form x venue x opponent",
        ),
        "baseline_pts": st.column_config.NumberColumn(
            "Baseline",
            width="small",
            format="%.2f",
            help="Weighted baseline points combining last season and this season",
        ),
        "form_ratio": st.column_config.NumberColumn(
            "Form",
            width="small",
            format="%.2f",
            help="Recent form vs baseline (clamped 0.8-1.2). >1 = hot, <1 = cold.",
        ),
        "venue_multiplier": st.column_config.NumberColumn(
            "Venue",
            width="small",
            format="%.2f",
            help="Home or Away multiplier based on next match location.",
        ),
        "opponent_multiplier": st.column_config.NumberColumn(
            "Opponent",
            width="small",
            format="%.2f",
            help="Opponent weakness (0.85-1.20). >1 = weak opponent for this position.",
        ),
        "is_home_next": st.column_config.CheckboxColumn(
            "Home?",
            width="small",
            help="Is the player playing at home in the next match?",
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
        "map_score",
        "baseline_pts",
        "form_ratio",
        "venue_multiplier",
        "opponent_multiplier",
        "is_home_next",
        "baseline_method",
    ]

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data, width="stretch", hide_index=True, column_config=col_config
    )


def render_baseline_tab(data: list[dict]) -> None:
    """Render Baseline component tab."""
    st.subheader("Component 1: Baseline Ability")
    st.caption(
        "Expected baseline points per player. "
        "Returning players: 0.6 * last_season + 0.4 * this_season. "
        "Rookies: 0.7 * this_season + 0.3 * position_avg."
    )

    col_config = {
        "name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Position", width="small"),
        "club_logo_url": st.column_config.ImageColumn("Club", width="small"),
        "baseline_pts": st.column_config.NumberColumn(
            "Baseline Pts",
            width="small",
            format="%.2f",
            help="Final baseline expected points",
        ),
        "baseline_method": st.column_config.TextColumn(
            "Method",
            width="small",
            help="weighted_seasons or rookie_shrinkage",
        ),
        "pts_avg_this_season": st.column_config.NumberColumn(
            "This Season Avg",
            width="small",
            format="%.2f",
            help="Average points this season",
        ),
        "matches_this_season": st.column_config.NumberColumn(
            "Matches (This)",
            width="small",
            format="%d",
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
        "has_last_season_data": st.column_config.CheckboxColumn(
            "Has Last Season?",
            width="small",
            help=">=5 matches AND >30% availability last season",
        ),
    }

    display_cols = [
        "name",
        "position",
        "club_logo_url",
        "baseline_pts",
        "baseline_method",
        "pts_avg_this_season",
        "matches_this_season",
        "pts_avg_last_season",
        "matches_last_season",
        "availability_last_season",
        "position_pts_avg",
        "has_last_season_data",
    ]

    # Convert availability to percentage
    for row in data:
        if row.get("availability_last_season") is not None:
            row["availability_last_season"] = row["availability_last_season"] * 100

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data, width="stretch", hide_index=True, column_config=col_config
    )


def render_form_tab(data: list[dict]) -> None:
    """Render Form component tab."""
    st.subheader("Component 2: Recent Form")
    st.caption(
        "Recent form adjustment from last 5 games. "
        "form_ratio = last_5_avg / baseline. Clamped between 0.8 and 1.2."
    )

    col_config = {
        "name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Position", width="small"),
        "club_logo_url": st.column_config.ImageColumn("Club", width="small"),
        "form_ratio": st.column_config.NumberColumn(
            "Form Ratio",
            width="small",
            format="%.3f",
            help="Recent form vs baseline. >1 = hot, <1 = cold.",
        ),
        "pts_avg_last_5": st.column_config.NumberColumn(
            "Last 5 Avg",
            width="small",
            format="%.2f",
            help="Average points in last 5 matches",
        ),
        "matches_last_5": st.column_config.NumberColumn(
            "Matches (L5)",
            width="small",
            format="%d",
            help="Matches played in last 5 rounds",
        ),
    }

    display_cols = [
        "name",
        "position",
        "club_logo_url",
        "form_ratio",
        "pts_avg_last_5",
        "matches_last_5",
    ]

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data, width="stretch", hide_index=True, column_config=col_config
    )


def render_venue_tab(data: list[dict]) -> None:
    """Render Venue component tab."""
    st.subheader("Component 3: Home/Away Context")
    st.caption(
        "Venue adjustment based on historical home/away performance. "
        "Blended: 0.7 * last_season + 0.3 * this_season. Clamped +-15%."
    )

    col_config = {
        "name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Position", width="small"),
        "club_logo_url": st.column_config.ImageColumn("Club", width="small"),
        "home_multiplier": st.column_config.NumberColumn(
            "Home Mult",
            width="small",
            format="%.3f",
            help="Home performance multiplier. >1 = better at home.",
        ),
        "away_multiplier": st.column_config.NumberColumn(
            "Away Mult",
            width="small",
            format="%.3f",
            help="Away performance multiplier. >1 = better away.",
        ),
        "home_avg": st.column_config.NumberColumn(
            "Home Avg",
            width="small",
            format="%.2f",
            help="Blended home average points",
        ),
        "away_avg": st.column_config.NumberColumn(
            "Away Avg",
            width="small",
            format="%.2f",
            help="Blended away average points",
        ),
        "pts_avg_home_last_season": st.column_config.NumberColumn(
            "Home (Last)",
            width="small",
            format="%.2f",
        ),
        "pts_avg_away_last_season": st.column_config.NumberColumn(
            "Away (Last)",
            width="small",
            format="%.2f",
        ),
        "pts_avg_home_this_season": st.column_config.NumberColumn(
            "Home (This)",
            width="small",
            format="%.2f",
        ),
        "pts_avg_away_this_season": st.column_config.NumberColumn(
            "Away (This)",
            width="small",
            format="%.2f",
        ),
        "matches_home_last_season": st.column_config.NumberColumn(
            "Home Matches (Last)",
            width="small",
            format="%d",
        ),
        "matches_away_last_season": st.column_config.NumberColumn(
            "Away Matches (Last)",
            width="small",
            format="%d",
        ),
    }

    display_cols = [
        "name",
        "position",
        "club_logo_url",
        "home_multiplier",
        "away_multiplier",
        "home_avg",
        "away_avg",
        "pts_avg_home_last_season",
        "pts_avg_away_last_season",
        "pts_avg_home_this_season",
        "pts_avg_away_this_season",
    ]

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data, width="stretch", hide_index=True, column_config=col_config
    )


def render_opponent_tab(data: list[dict]) -> None:
    """Render Opponent component tab."""
    st.subheader("Component 4: Opponent Strength")
    st.caption(
        "Matchup adjustment based on opponent's defensive weakness. "
        "opponent_multiplier = pts_conceded / league_avg. Clamped 0.85-1.20."
    )

    col_config = {
        "name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Position", width="small"),
        "club_logo_url": st.column_config.ImageColumn("Club", width="small"),
        "opponent_multiplier": st.column_config.NumberColumn(
            "Opponent Mult",
            width="small",
            format="%.3f",
            help="Opponent weakness. >1 = weak opponent for this position.",
        ),
        "opponent_pts_conceded": st.column_config.NumberColumn(
            "Pts Conceded",
            width="small",
            format="%.2f",
            help="Avg points opponent concedes to this position (last 5 games)",
        ),
        "league_avg_pts": st.column_config.NumberColumn(
            "League Avg",
            width="small",
            format="%.2f",
            help="League average points for this position",
        ),
        "opponent_matches_conceded": st.column_config.NumberColumn(
            "Opp Matches",
            width="small",
            format="%d",
            help="Matches used to calculate opponent conceded",
        ),
        "is_home_next": st.column_config.CheckboxColumn(
            "Home?",
            width="small",
            help="Is the player playing at home in the next match?",
        ),
        "opponent_id": st.column_config.NumberColumn(
            "Opponent ID",
            width="small",
            format="%d",
            help="Opponent club ID for next match",
        ),
    }

    display_cols = [
        "name",
        "position",
        "club_logo_url",
        "opponent_multiplier",
        "opponent_pts_conceded",
        "league_avg_pts",
        "opponent_matches_conceded",
        "is_home_next",
        "opponent_id",
    ]

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data, width="stretch", hide_index=True, column_config=col_config
    )


def main() -> None:
    """Run Start or Sit page."""
    st.title(":scales: Start or Sit")
    st.caption("Matchup-Adjusted Projection (MAP) for next match decisions")

    # Sidebar filters
    with st.sidebar:
        st.header("Filters")

        available_rounds = load_available_rounds()
        selected_round = st.selectbox(
            "As of Round",
            options=available_rounds,
            index=0,
            format_func=lambda x: f"Round {x}",
            help="View MAP as if this was the latest round",
        )

        with st.spinner("Loading MAP data..."):
            map_data = load_map_data(selected_round)
            baseline_data = load_map_baseline(selected_round)
            form_data = load_map_form(selected_round)
            venue_data = load_map_venue(selected_round)
            opponent_data = load_map_opponent(selected_round)

        clubs = sorted({row["club"] for row in map_data if row.get("club")})
        positions = ["GK", "CB", "FB", "MD", "AT"]

        st.divider()

        name_filter = st.text_input("Player Name", placeholder="Search...")
        position_filter = st.selectbox("Position", options=["All", *positions])
        club_filter = st.selectbox("Club", options=["All", *clubs])

    # Apply filters to all datasets
    filtered_map = filter_data(map_data, name_filter, club_filter, position_filter)
    filtered_baseline = filter_data(
        baseline_data, name_filter, club_filter, position_filter
    )
    filtered_form = filter_data(form_data, name_filter, club_filter, position_filter)
    filtered_venue = filter_data(venue_data, name_filter, club_filter, position_filter)
    filtered_opponent = filter_data(
        opponent_data, name_filter, club_filter, position_filter
    )

    # Main tabs for each component
    tab_overview, tab_baseline, tab_form, tab_venue, tab_opponent = st.tabs(
        ["MAP Overview", "1. Baseline", "2. Form", "3. Venue", "4. Opponent"],
    )

    with tab_overview:
        render_map_overview_tab(filtered_map)

    with tab_baseline:
        render_baseline_tab(filtered_baseline)

    with tab_form:
        render_form_tab(filtered_form)

    with tab_venue:
        render_venue_tab(filtered_venue)

    with tab_opponent:
        render_opponent_tab(filtered_opponent)


if __name__ == "__main__":
    main()

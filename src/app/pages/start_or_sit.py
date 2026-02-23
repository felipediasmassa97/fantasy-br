"""Start or Sit page for Fantasy BR - MAP (Matchup-Adjusted Projection) metrics."""

import streamlit as st
from utils import (
    filter_data,
    load_available_rounds,
    load_distribution_stats,
    load_ewm_form,
    load_map_baseline,
    load_map_data,
    load_map_form,
    load_map_mpap,
    load_map_venue,
    load_poe_data,
)


def render_map_overview_tab(data: list[dict]) -> None:
    """Render MAP overview tab with final scores."""
    st.subheader("MAP Score Overview")
    st.caption(
        "MAP = Baseline x Form x Venue x MPAP. "
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
            help="Matchup-Adjusted Projection: baseline x form x venue x MPAP",
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
        "mpap_multiplier": st.column_config.NumberColumn(
            "MPAP",
            width="small",
            format="%.2f",
            help="Matchup Points Allowed by Position (0.85-1.20). >1 = weak opponent.",
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
        "mpap_multiplier",
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


def render_mpap_tab(data: list[dict]) -> None:
    """Render MPAP (Matchup Points Allowed by Position) component tab."""
    st.subheader("Component 4: MPAP (Matchup Points Allowed by Position)")
    st.caption(
        "How many fantasy points does the opponent allow to this position? "
        "mpap_multiplier = pts_conceded / league_avg. Clamped 0.85-1.20."
    )

    col_config = {
        "name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Position", width="small"),
        "club_logo_url": st.column_config.ImageColumn("Club", width="small"),
        "mpap_multiplier": st.column_config.NumberColumn(
            "MPAP Mult",
            width="small",
            format="%.3f",
            help="Matchup Points Allowed multiplier. >1 = weak opponent for this position.",
        ),
        "mpap_pts_conceded": st.column_config.NumberColumn(
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
        "mpap_matches": st.column_config.NumberColumn(
            "MPAP Matches",
            width="small",
            format="%d",
            help="Matches used to calculate MPAP",
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
        "mpap_multiplier",
        "mpap_pts_conceded",
        "league_avg_pts",
        "mpap_matches",
        "is_home_next",
        "opponent_id",
    ]

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data, width="stretch", hide_index=True, column_config=col_config
    )


def render_ewm_tab(data: list[dict]) -> None:
    """Render EWM (Exponentially Weighted Mean) form tab."""
    st.subheader("Recency-Weighted Form (EWM Points)")
    st.caption(
        "Player form with more weight on recent games. "
        "More stable than last-3 average, faster than season average. Alpha=0.25."
    )

    col_config = {
        "name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Position", width="small"),
        "club_logo_url": st.column_config.ImageColumn("Club", width="small"),
        "ewm_pts": st.column_config.NumberColumn(
            "EWM Pts",
            width="small",
            format="%.2f",
            help="Exponentially weighted mean points (recent games weighted more)",
        ),
        "ewm_ratio": st.column_config.NumberColumn(
            "EWM/Baseline",
            width="small",
            format="%.2f",
            help="EWM vs baseline ratio. >1 = hot streak, <1 = cold streak.",
        ),
        "ewm_vs_season_ratio": st.column_config.NumberColumn(
            "EWM/Season",
            width="small",
            format="%.2f",
            help="EWM vs season average. >1 = recent form better than season avg.",
        ),
        "baseline_pts": st.column_config.NumberColumn(
            "Baseline",
            width="small",
            format="%.2f",
            help="Player baseline points for comparison",
        ),
        "pts_avg_this_season": st.column_config.NumberColumn(
            "Season Avg",
            width="small",
            format="%.2f",
            help="Simple season average for comparison",
        ),
        "matches_used": st.column_config.NumberColumn(
            "Matches",
            width="small",
            format="%d",
            help="Number of matches used in EWM calculation",
        ),
    }

    display_cols = [
        "name",
        "position",
        "club_logo_url",
        "ewm_pts",
        "ewm_ratio",
        "ewm_vs_season_ratio",
        "baseline_pts",
        "pts_avg_this_season",
        "matches_used",
    ]

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data, width="stretch", hide_index=True, column_config=col_config
    )


def render_distribution_tab(data: list[dict]) -> None:
    """Render distribution stats (floor/median/ceiling + consistency) tab."""
    st.subheader("Floor / Median / Ceiling + Consistency")
    st.caption(
        "Risk profile based on score distribution. "
        "Floor (20th pct), Median (50th pct), Ceiling (80th pct). "
        "Blended with position avg if <10 games."
    )

    col_config = {
        "name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Position", width="small"),
        "club_logo_url": st.column_config.ImageColumn("Club", width="small"),
        "floor_pts": st.column_config.NumberColumn(
            "Floor",
            width="small",
            format="%.2f",
            help="20th percentile: bad-but-normal game",
        ),
        "median_pts": st.column_config.NumberColumn(
            "Median",
            width="small",
            format="%.2f",
            help="50th percentile: typical game",
        ),
        "ceiling_pts": st.column_config.NumberColumn(
            "Ceiling",
            width="small",
            format="%.2f",
            help="80th percentile: great-but-realistic game",
        ),
        "pts_range": st.column_config.NumberColumn(
            "Range",
            width="small",
            format="%.2f",
            help="Ceiling - Floor: measure of volatility",
        ),
        "consistency_rating": st.column_config.NumberColumn(
            "Consistency",
            width="small",
            format="%.2f",
            help="1/(1+CV): Higher = more consistent. Range 0-1.",
        ),
        "cv": st.column_config.NumberColumn(
            "CV",
            width="small",
            format="%.2f",
            help="Coefficient of Variation (std/mean). Lower = more stable.",
        ),
        "matches_played": st.column_config.NumberColumn(
            "Matches",
            width="small",
            format="%d",
            help="Games played (blend with position avg if <10)",
        ),
        "blend_weight": st.column_config.ProgressColumn(
            "Blend",
            width="small",
            format="%.0f%%",
            min_value=0,
            max_value=100,
            help="How much position avg is blended in (0% = pure player data)",
        ),
    }

    display_cols = [
        "name",
        "position",
        "club_logo_url",
        "floor_pts",
        "median_pts",
        "ceiling_pts",
        "pts_range",
        "consistency_rating",
        "cv",
        "matches_played",
        "blend_weight",
    ]

    # Convert blend_weight to percentage
    for row in data:
        if row.get("blend_weight") is not None:
            row["blend_weight"] = row["blend_weight"] * 100

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data, width="stretch", hide_index=True, column_config=col_config
    )


def render_poe_tab(data: list[dict]) -> None:
    """Render PoE (Points over Expected) tab."""
    st.subheader("Points over Expected (PoE)")
    st.caption(
        "How much a player over/underperforms their MAP projection. "
        "Positive = exceeding expectations, Negative = underperforming."
    )

    col_config = {
        "name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Position", width="small"),
        "club_logo_url": st.column_config.ImageColumn("Club", width="small"),
        "poe_total": st.column_config.NumberColumn(
            "PoE Total",
            width="small",
            format="%.2f",
            help="Cumulative points over expected this season",
        ),
        "poe_avg": st.column_config.NumberColumn(
            "PoE Avg",
            width="small",
            format="%.2f",
            help="Average PoE per round",
        ),
        "poe_rounds_total": st.column_config.NumberColumn(
            "Rounds",
            width="small",
            format="%d",
            help="Rounds with PoE data (needs MAP from previous round)",
        ),
        "poe_last_5": st.column_config.NumberColumn(
            "PoE Last 5",
            width="small",
            format="%.2f",
            help="Cumulative PoE over last 5 rounds",
        ),
        "poe_avg_last_5": st.column_config.NumberColumn(
            "PoE Avg L5",
            width="small",
            format="%.2f",
            help="Average PoE per round (last 5)",
        ),
        "poe_category": st.column_config.TextColumn(
            "Category",
            width="small",
            help="overperforming (>5), underperforming (<-5), or as_expected",
        ),
        "baseline_pts": st.column_config.NumberColumn(
            "Baseline",
            width="small",
            format="%.2f",
            help="Player baseline for reference",
        ),
    }

    display_cols = [
        "name",
        "position",
        "club_logo_url",
        "poe_total",
        "poe_avg",
        "poe_rounds_total",
        "poe_last_5",
        "poe_avg_last_5",
        "poe_category",
        "baseline_pts",
    ]

    display_data = [{k: row.get(k) for k in display_cols} for row in data]

    st.dataframe(
        display_data, width="stretch", hide_index=True, column_config=col_config
    )


def main() -> None:
    """Run Start or Sit page."""
    st.title("⚖️ Start or Sit")
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
            mpap_data = load_map_mpap(selected_round)
            ewm_data = load_ewm_form(selected_round)
            dist_data = load_distribution_stats(selected_round)
            poe_data = load_poe_data(selected_round)

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
    filtered_mpap = filter_data(mpap_data, name_filter, club_filter, position_filter)
    filtered_ewm = filter_data(ewm_data, name_filter, club_filter, position_filter)
    filtered_dist = filter_data(dist_data, name_filter, club_filter, position_filter)
    filtered_poe = filter_data(poe_data, name_filter, club_filter, position_filter)

    # Main tabs for each component
    tab_overview, tab_baseline, tab_form, tab_venue, tab_mpap, tab_ewm, tab_dist, tab_poe = (
        st.tabs(
            [
                "MAP Overview",
                "1. Baseline",
                "2. Form",
                "3. Venue",
                "4. MPAP",
                "EWM Form",
                "Distribution",
                "PoE",
            ],
        )
    )

    with tab_overview:
        render_map_overview_tab(filtered_map)

    with tab_baseline:
        render_baseline_tab(filtered_baseline)

    with tab_form:
        render_form_tab(filtered_form)

    with tab_venue:
        render_venue_tab(filtered_venue)

    with tab_mpap:
        render_mpap_tab(filtered_mpap)

    with tab_ewm:
        render_ewm_tab(filtered_ewm)

    with tab_dist:
        render_distribution_tab(filtered_dist)

    with tab_poe:
        render_poe_tab(filtered_poe)


if __name__ == "__main__":
    main()

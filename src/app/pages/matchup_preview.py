"""Matchup Preview page — compare My Team vs Opponent Team using MAP scores."""

import streamlit as st
from utils import (
    load_available_rounds,
    load_opponent_squad,
    load_opponent_team,
    load_squad,
    load_ss_main,
    load_team,
)


def _build_roster_table(
    data: list[dict], player_ids: set[int]
) -> tuple[list[dict], float]:
    """Build display rows for a set of player IDs and return (rows, total_map)."""
    rows = [row for row in data if row.get("player_id") in player_ids]
    rows.sort(key=lambda r: (r.get("position", ""), r.get("player_name", "")))
    total_map = sum(r.get("map_score") or 0.0 for r in rows)
    return rows, total_map


def _render_roster(
    label: str, rows: list[dict], total_map: float, *, is_team: bool
) -> None:
    """Render a roster table with MAP total."""
    kind = "Team" if is_team else "Squad"
    st.markdown(f"**{label} — {kind} ({len(rows)} players)**")

    if not rows:
        st.info(f"No players in {label.lower()} {kind.lower()}.")
        return

    col_config = {
        "player_name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "club_logo_url": st.column_config.ImageColumn("Club", width="small"),
        "club": st.column_config.TextColumn("Club", width="small"),
        "map_score": st.column_config.NumberColumn("MAP", format="%.2f"),
        "is_home_next": st.column_config.CheckboxColumn("Home?"),
    }
    display_cols = list(col_config.keys())
    display_rows = [{k: r.get(k) for k in display_cols} for r in rows]
    st.dataframe(
        display_rows,
        use_container_width=True,
        hide_index=True,
        column_config=col_config,
    )
    st.metric(f"Total MAP ({kind})", f"{total_map:.2f}")


def _render_comparison(
    my_rows: list[dict],
    opp_rows: list[dict],
    my_total: float,
    opp_total: float,
    *,
    is_team: bool,
) -> None:
    """Render side-by-side roster comparison."""
    col_left, col_right = st.columns(2)
    with col_left:
        _render_roster("My", my_rows, my_total, is_team=is_team)
    with col_right:
        _render_roster("Opponent", opp_rows, opp_total, is_team=is_team)

    delta = my_total - opp_total
    kind = "Team" if is_team else "Squad"
    st.divider()
    col_metric, col_verdict = st.columns(2)
    with col_metric:
        st.metric(f"MAP Delta — {kind} (My - Opp)", f"{delta:+.2f}")
    with col_verdict:
        if delta > 0:
            st.markdown(f"### :white_check_mark: My {kind} leads")
        elif delta < 0:
            st.markdown(f"### :warning: Opponent {kind} leads")
        else:
            st.markdown(f"### :balance_scale: {kind}s are tied")


def main() -> None:
    """Render the Matchup Preview page."""
    st.title("Matchup Preview")

    rounds = load_available_rounds()
    if not rounds:
        st.warning("No rounds available.")
        return

    with st.sidebar:
        st.header("Round")
        round_id = st.selectbox(
            "As of round",
            options=rounds,
            index=len(rounds) - 1,
            key="matchup_round_id",
        )

    data = load_ss_main(round_id)
    if not data:
        st.info("No MAP data available for this round.")
        return

    ids_my_squad = load_squad()
    ids_my_team = load_team()
    ids_opp_squad = load_opponent_squad()
    ids_opp_team = load_opponent_team()

    tab_team, tab_squad = st.tabs(["Team", "Squad"])

    with tab_team:
        my_team_rows, my_team_total = _build_roster_table(data, ids_my_team)
        opp_team_rows, opp_team_total = _build_roster_table(data, ids_opp_team)
        _render_comparison(
            my_team_rows, opp_team_rows, my_team_total, opp_team_total, is_team=True
        )

    with tab_squad:
        my_squad_rows, my_squad_total = _build_roster_table(data, ids_my_squad)
        opp_squad_rows, opp_squad_total = _build_roster_table(data, ids_opp_squad)
        _render_comparison(
            my_squad_rows,
            opp_squad_rows,
            my_squad_total,
            opp_squad_total,
            is_team=False,
        )

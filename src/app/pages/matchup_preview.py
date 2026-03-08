"""Matchup Preview page — compare My Team vs Opponent Team using MAP and PAR scores."""

from typing import NamedTuple

import streamlit as st
from utils import (
    load_available_rounds,
    load_mv_main,
    load_opponent_squad,
    load_opponent_team,
    load_squad,
    load_ss_main,
    load_team,
)


class _ScoreConfig(NamedTuple):
    """Score field and display label for a comparison view."""

    field: str
    label: str
    is_team: bool


def _build_roster_table(
    data: list[dict], player_ids: set[int], score_field: str
) -> tuple[list[dict], float]:
    """Build display rows for a set of player IDs and return (rows, total_score)."""
    rows = [row for row in data if row.get("player_id") in player_ids]
    rows.sort(key=lambda r: (r.get("position", ""), r.get("player_name", "")))
    total = sum(r.get(score_field) or 0.0 for r in rows)
    return rows, total


def _render_roster(
    label: str, rows: list[dict], total_score: float, cfg: _ScoreConfig
) -> None:
    """Render a roster table with score total."""
    kind = "Team" if cfg.is_team else "Squad"
    st.markdown(f"**{label} {kind} ({len(rows)} players)**")

    if not rows:
        st.info(f"No players in {label.lower()} {kind.lower()}.")
        return

    base_cols = {
        "player_name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "club_logo_url": st.column_config.ImageColumn("Club", width="small"),
        "club": st.column_config.TextColumn("Club", width="small"),
    }
    score_col = {cfg.field: st.column_config.NumberColumn(cfg.label, format="%.2f")}
    home_col = {"is_home_next": st.column_config.CheckboxColumn("Home?")}
    extra_cols: dict = home_col if cfg.is_team else {}
    col_config = {**base_cols, **score_col, **extra_cols}
    display_cols = list(col_config.keys())
    display_rows = [{k: r.get(k) for k in display_cols} for r in rows]
    st.dataframe(
        display_rows,
        use_container_width=True,
        hide_index=True,
        column_config=col_config,
    )
    st.metric(f"Total {cfg.label} ({kind})", f"{total_score:.2f}")


def _render_comparison(
    my_rows: list[dict],
    opp_rows: list[dict],
    my_total: float,
    opp_total: float,
    cfg: _ScoreConfig,
) -> None:
    """Render side-by-side roster comparison."""
    col_left, col_right = st.columns(2)
    with col_left:
        _render_roster("My", my_rows, my_total, cfg)
    with col_right:
        _render_roster("Opponent", opp_rows, opp_total, cfg)

    delta = my_total - opp_total
    kind = "Team" if cfg.is_team else "Squad"
    st.divider()
    col_metric, col_verdict = st.columns(2)
    with col_metric:
        st.metric(f"{cfg.label} {kind} Delta (My - Opp)", f"{delta:+.2f}")
    with col_verdict:
        if delta > 0:
            st.markdown(f"### :white_check_mark: My {kind} leads")
        elif delta < 0:
            st.markdown(f"### :warning: Opponent {kind} leads")
        else:
            st.markdown(f"### :balance_scale: {kind}s are tied")


def main() -> None:
    """Render the Matchup Preview page."""
    st.title("🆚 Matchup Preview")

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

    map_data = load_ss_main(round_id)
    par_data = load_mv_main(round_id)

    if not map_data and not par_data:
        st.info("No data available for this round.")
        return

    ids_my_squad = load_squad()
    ids_my_team = load_team()
    ids_opp_squad = load_opponent_squad()
    ids_opp_team = load_opponent_team()

    tab_team, tab_squad = st.tabs(["Team", "Squad"])

    with tab_team:
        if not map_data:
            st.info("No MAP data available for this round.")
        else:
            cfg_team = _ScoreConfig(field="map_score", label="MAP", is_team=True)
            my_team_rows, my_team_total = _build_roster_table(
                map_data, ids_my_team, cfg_team.field
            )
            opp_team_rows, opp_team_total = _build_roster_table(
                map_data, ids_opp_team, cfg_team.field
            )
            _render_comparison(
                my_team_rows, opp_team_rows, my_team_total, opp_team_total, cfg_team
            )

    with tab_squad:
        if not par_data:
            st.info("No PAR data available for this round.")
        else:
            cfg_squad = _ScoreConfig(field="par", label="PAR", is_team=False)
            my_squad_rows, my_squad_total = _build_roster_table(
                par_data, ids_my_squad, cfg_squad.field
            )
            opp_squad_rows, opp_squad_total = _build_roster_table(
                par_data, ids_opp_squad, cfg_squad.field
            )
            _render_comparison(
                my_squad_rows,
                opp_squad_rows,
                my_squad_total,
                opp_squad_total,
                cfg_squad,
            )

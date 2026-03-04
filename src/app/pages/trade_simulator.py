"""Trade Simulator page."""

import streamlit as st
from utils import load_available_rounds, load_mv_main

FAIR_TRADE_THRESHOLD = 0.5


def _build_player_options(data: list[dict]) -> list[dict]:
    """Build sorted player options with display labels."""
    players = []
    for row in data:
        if row.get("par") is None:
            continue
        players.append(
            {
                "player_id": row["player_id"],
                "label": f"{row['player_name']} ({row['position']} — {row['club']})",
                "player_name": row["player_name"],
                "position": row["position"],
                "club": row["club"],
                "baseline_pts": row.get("baseline_pts"),
                "par": row["par"],
            }
        )
    return sorted(players, key=lambda p: p["label"])


def _render_side(player_by_id: dict, player_ids: list[int], label: str) -> float:
    """Render a side's player table and return total PAR."""
    rows = [player_by_id[pid] for pid in player_ids]
    total_par = sum(r["par"] for r in rows)

    col_config = {
        "player_name": st.column_config.TextColumn("Player", width="medium"),
        "position": st.column_config.TextColumn("Pos", width="small"),
        "club": st.column_config.TextColumn("Club", width="small"),
        "baseline_pts": st.column_config.NumberColumn("Baseline", format="%.2f"),
        "par": st.column_config.NumberColumn("PAR", format="%+.2f"),
    }
    display_cols = list(col_config.keys())
    table_rows = [{k: r.get(k) for k in display_cols} for r in rows]
    st.dataframe(
        table_rows,
        use_container_width=True,
        hide_index=True,
        column_config=col_config,
    )
    st.metric(f"Total PAR ({label})", f"{total_par:+.2f}")
    return total_par


def _render_verdict(par_a: float, par_b: float) -> None:
    """Render the trade verdict based on PAR delta."""
    delta = par_a - par_b

    if abs(delta) < FAIR_TRADE_THRESHOLD:
        verdict = "roughly fair"
        icon = ":balance_scale:"
    elif delta > 0:
        verdict = "Side A has the edge"
        icon = ":arrow_left:"
    else:
        verdict = "Side B has the edge"
        icon = ":arrow_right:"

    st.subheader("Trade Verdict")
    col_metric, col_verdict = st.columns(2)
    with col_metric:
        st.metric("PAR Delta (A - B)", f"{delta:+.2f}")
    with col_verdict:
        st.markdown(f"### {icon} {verdict}")


def _render_selections(
    players: list[dict], player_by_id: dict
) -> tuple[list[int], list[int]]:
    """Render player selection multiselects and return selected IDs."""
    col_left, col_right = st.columns(2)

    with col_left:
        st.subheader("Side A")
        selected_left = st.multiselect(
            "Players (Side A)",
            options=[p["player_id"] for p in players],
            format_func=lambda pid: player_by_id[pid]["label"],
            key="trade_side_a",
        )

    with col_right:
        st.subheader("Side B")
        available_right = [
            p["player_id"] for p in players if p["player_id"] not in selected_left
        ]
        selected_right = st.multiselect(
            "Players (Side B)",
            options=available_right,
            format_func=lambda pid: player_by_id[pid]["label"],
            key="trade_side_b",
        )

    return selected_left, selected_right


def main() -> None:
    """Render Trade Simulator page."""
    st.title("Trade Simulator")

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
            key="trade_round_id",
        )

    data = load_mv_main(round_id)
    if not data:
        st.info("No valuation data available for this round.")
        return

    players = _build_player_options(data)
    if not players:
        st.info("No players with PAR data available.")
        return

    player_by_id = {p["player_id"]: p for p in players}

    st.markdown(
        "Select players on each side of a trade. "
        "The PAR delta shows which side has the edge."
    )

    selected_left, selected_right = _render_selections(players, player_by_id)

    if not selected_left and not selected_right:
        return

    st.divider()

    col_left, col_right = st.columns(2)
    par_a = 0.0
    par_b = 0.0

    with col_left:
        if selected_left:
            par_a = _render_side(player_by_id, selected_left, "Side A")
        else:
            st.info("No players selected for Side A.")

    with col_right:
        if selected_right:
            par_b = _render_side(player_by_id, selected_right, "Side B")
        else:
            st.info("No players selected for Side B.")

    if selected_left and selected_right:
        st.divider()
        _render_verdict(par_a, par_b)

"""Squad and Team management page."""

# fixit test squad feature
# fixit test team feature
# fixit test with different email too

import pandas as pd
import streamlit as st
from utils import (
    get_user_email,
    load_clubs,
    load_players,
    load_positions,
    load_squad,
    load_team,
    save_squad,
    save_team,
)

MAX_SQUAD_SIZE = 23
MAX_TEAM_SIZE = 11

PLAYER_CONFIG = {
    "player_id": None,
    "club_logo_url": st.column_config.ImageColumn("Club", width=50),
}


def _sort_players(df: pd.DataFrame) -> pd.DataFrame:
    """Sort players by position order then name."""
    df = df.copy()
    df["_pos_order"] = (
        df["position"]
        .map({pos["position"]: pos["id"] for pos in load_positions()})
        .fillna(99)
    )
    return df.sort_values(["_pos_order", "player_name"]).drop(columns=["_pos_order"])


def _player_label(row: pd.Series) -> str:
    """Format a player row as a human-readable label."""
    return f"{row['player_name']} ({row['position']} - {row['club']})"


def _render_players(df: pd.DataFrame, ids_player: set[int]) -> None:
    """Display a dataframe for the given player IDs."""
    df_ = _sort_players(df[df["player_id"].isin(ids_player)])
    st.dataframe(
        df_, column_config=PLAYER_CONFIG, use_container_width=True, hide_index=True
    )


def _apply_filters(df: pd.DataFrame) -> pd.DataFrame:
    """Render filter widgets and return the filtered DataFrame."""
    cols = st.columns(3)
    with cols[0]:
        filter_name = st.text_input(
            "Search by name", placeholder="Type a name...", key="squad_filter_name"
        )
    with cols[1]:
        clubs = ["All", *sorted([c["name"] for c in load_clubs()])]
        filter_club = st.selectbox("Club", clubs, key="squad_filter_club")
    with cols[2]:
        positions = ["All", *sorted([p["position"] for p in load_positions()])]
        filter_pos = st.selectbox("Position", positions, key="squad_filter_position")

    df_filtered = df
    if filter_name:
        df_filtered = df_filtered[
            df_filtered["player_name"].str.contains(filter_name, case=False, na=False)
        ]
    if filter_club != "All":
        df_filtered = df_filtered[df_filtered["club"] == filter_club]
    if filter_pos != "All":
        df_filtered = df_filtered[df_filtered["position"] == filter_pos]
    return _sort_players(df_filtered)


def _render_add_section(
    df: pd.DataFrame,
    ids_pool: set[int],
    ids_stored: set[int],
    max_size: int,
    scope: str,
) -> None:
    """Render a multiselect and a button to add players to a target set."""
    df_pool = df[df["player_id"].isin(ids_pool)]
    if df_pool.empty:
        st.write(f"No players available to add to {scope.capitalize()}.")
        return

    players_to_add = st.multiselect(
        f"Select players to add to {scope.capitalize()}",
        options=_sort_players(df_pool),
        format_func=_player_label,
        max_selections=max(0, max_size - len(ids_stored)),
        key=f"select_add_{scope}",
    )
    if (
        st.button(f"Add to {scope.capitalize()}", key=f"btn_add_{scope}")
        and players_to_add
    ):
        for player in players_to_add:
            ids_stored.add(player["player_id"])
        st.rerun()


def _render_remove_section(
    df: pd.DataFrame,
    ids_stored: set[int],
    scope: str,
    also_remove_from: set[int] | None = None,
) -> None:
    """Render a multiselect and a button to remove players from a target set."""
    if not ids_stored:
        return

    st.divider()
    st.markdown(f"**Remove players from {scope.capitalize()}**")
    players_to_remove = st.multiselect(
        f"Select players to remove from {scope.capitalize()}",  # noqa: S608
        options=_sort_players(df[df["player_id"].isin(ids_stored)]),
        format_func=_player_label,
        key=f"select_remove_{scope}",
    )
    if (
        st.button(f"Remove from {scope.capitalize()}", key=f"btn_remove_{scope}")
        and players_to_remove
    ):
        for player in players_to_remove:
            player_id = player["player_id"]
            ids_stored.discard(player_id)
            if also_remove_from is not None:
                also_remove_from.discard(player_id)
        st.rerun()


def _render_squad_tab(
    df: pd.DataFrame, ids_squad: set[int], ids_team: set[int]
) -> None:
    """Render squad management tab content."""
    st.subheader(f"Squad ({len(ids_squad)}/{MAX_SQUAD_SIZE})")

    if ids_squad:
        _render_players(df, ids_squad)
    else:
        st.info("Your squad is empty. Add players below.")

    st.divider()
    st.markdown("**Add players to squad**")

    df_available = df[~df["player_id"].isin(ids_squad)]
    filtered = _apply_filters(df_available)
    ids_available = set(filtered["player_id"].tolist())

    _render_add_section(df, ids_available, ids_squad, MAX_SQUAD_SIZE, scope="squad")
    _render_remove_section(df, ids_squad, scope="squad", also_remove_from=ids_team)


def _render_team_tab(df: pd.DataFrame, ids_squad: set[int], ids_team: set[int]) -> None:
    """Render team management tab content."""
    st.subheader(f"Team ({len(ids_team)}/{MAX_TEAM_SIZE})")

    if not ids_squad:
        st.warning("Build your squad first before selecting a team.")
        return

    if ids_team:
        _render_players(df, ids_team)
    else:
        st.info("Your team is empty. Add players from your squad below.")

    st.divider()
    st.markdown("**Add players to team (from squad)**")

    ids_bench = ids_squad - ids_team

    _render_add_section(df, ids_bench, ids_team, MAX_TEAM_SIZE, scope="team")
    _render_remove_section(df, ids_team, scope="team")


def _render_save_bar(user_email: str, ids_squad: set[int], ids_team: set[int]) -> None:
    """Render the save button and success message."""
    st.divider()
    col_save, col_status = st.columns([1, 3])
    with col_save:
        if st.button("Save to database", type="primary", use_container_width=True):
            save_squad(user_email, sorted(ids_squad))
            save_team(user_email, sorted(ids_team))
            st.session_state["_save_success"] = True
            st.rerun()
    with col_status:
        if st.session_state.get("_save_success"):
            st.success(
                f"Saved squad ({len(ids_squad)} players) "
                f"and team ({len(ids_team)} players)."
            )
            st.session_state["_save_success"] = False


def main() -> None:
    """Render the Squad and Team page."""
    st.title("Squad and Team")

    user_email = get_user_email()

    players_all = load_players()
    if not players_all:
        st.error("No player data available.")
        return

    df_all = pd.DataFrame(players_all)
    ids_valid = set(df_all["player_id"].tolist())

    # Load persisted selections and validate against current data
    persisted_squad = set(load_squad(user_email)) & ids_valid
    persisted_team = set(load_team(user_email)) & persisted_squad

    if "ids_squad" not in st.session_state:
        st.session_state["ids_squad"] = persisted_squad
    if "ids_team" not in st.session_state:
        st.session_state["ids_team"] = persisted_team

    ids_squad: set[int] = st.session_state["ids_squad"]
    ids_team: set[int] = st.session_state["ids_team"]

    tab_squad, tab_team = st.tabs(
        [f"Squad ({len(ids_squad)})", f"Team ({len(ids_team)})"]
    )
    with tab_squad:
        _render_squad_tab(df_all, ids_squad, ids_team)
    with tab_team:
        _render_team_tab(df_all, ids_squad, ids_team)

    _render_save_bar(user_email, ids_squad, ids_team)

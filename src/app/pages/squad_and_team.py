"""Squad and Team management page."""

from collections.abc import Callable

import pandas as pd
import streamlit as st
from utils import (
    get_user_email,
    load_clubs,
    load_enriched_players,
    load_opponent_squad,
    load_opponent_team,
    load_positions,
    load_squad,
    load_team,
    save_opponent_squad,
    save_opponent_team,
    save_squad,
    save_team,
)

MAX_SQUAD_SIZE = 23
MAX_TEAM_SIZE = 11

PLAYER_COLUMNS = [
    "player_name",
    "position",
    "club_logo_url",
    "map_score",
    "avg_poe_last_5",
    "opponent_club",
    "is_home_next",
    "par",
    "regression_score",
]

PLAYER_CONFIG = {
    "player_id": None,
    "club": None,
    "player_name": st.column_config.TextColumn("Player"),
    "position": st.column_config.TextColumn("Pos"),
    "club_logo_url": st.column_config.ImageColumn("Club", width=50),
    "map_score": st.column_config.NumberColumn("MAP", format="%.1f"),
    "avg_poe_last_5": st.column_config.NumberColumn("Avg PoE L5", format="%+.1f"),
    "opponent_club": st.column_config.TextColumn("Next Opp"),
    "is_home_next": st.column_config.CheckboxColumn("Home?"),
    "par": st.column_config.NumberColumn("PAR", format="%.1f"),
    "regression_score": st.column_config.NumberColumn("Regr.", format="%.2f"),
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
    df_ = _sort_players(df[df["player_id"].isin(ids_player)])[PLAYER_COLUMNS]
    st.dataframe(
        df_, column_config=PLAYER_CONFIG, use_container_width=True, hide_index=True
    )


def _apply_filters(df: pd.DataFrame, prefix: str) -> pd.DataFrame:
    """Render filter widgets and return the filtered DataFrame."""
    cols = st.columns(3)
    with cols[0]:
        filter_name = st.text_input(
            "Search by name",
            placeholder="Type a name...",
            key=f"{prefix}_filter_name",
        )
    with cols[1]:
        club_list = load_clubs()
        club_options = [{"abbreviation": "All", "club": "All"}]
        club_options.extend(sorted(club_list, key=lambda c: c["club"]))
        filter_club = st.selectbox(
            "Club",
            options=club_options,
            format_func=lambda c: c["club"],
            key=f"{prefix}_filter_club",
        )
    with cols[2]:
        positions = ["All", *sorted([p["position"] for p in load_positions()])]
        filter_pos = st.selectbox(
            "Position", positions, key=f"{prefix}_filter_position"
        )

    df_filtered = df
    if filter_name:
        df_filtered = df_filtered[
            df_filtered["player_name"].str.contains(filter_name, case=False, na=False)
        ]
    if filter_club["abbreviation"] != "All":
        df_filtered = df_filtered[df_filtered["club"] == filter_club["abbreviation"]]
    if filter_pos != "All":
        df_filtered = df_filtered[df_filtered["position"] == filter_pos]
    return _sort_players(df_filtered)


def _render_add_section(  # noqa: PLR0913
    df: pd.DataFrame,
    ids_pool: set[int],
    ids_stored: set[int],
    max_size: int,
    scope: str,
    save_fn: Callable,
) -> None:
    """Render a dataframe with row selection and a button to add players."""
    label = " ".join([word.capitalize() for word in scope.replace("_", " ").split(" ")])
    slots_left = max(0, max_size - len(ids_stored))

    df_pool = _sort_players(df[df["player_id"].isin(ids_pool)])[
        ["player_id", *PLAYER_COLUMNS]
    ].reset_index(drop=True)
    if df_pool.empty:
        st.write(f"No players available to add to {label}.")
        return

    club_filter = st.session_state.get(f"{scope}_filter_club", {})
    filter_hash = abs(
        hash(
            (
                st.session_state.get(f"{scope}_filter_name", ""),
                str(club_filter.get("abbreviation", "All")),
                str(st.session_state.get(f"{scope}_filter_position", "All")),
            )
        )
    )
    event = st.dataframe(
        df_pool,
        column_config=PLAYER_CONFIG,
        use_container_width=True,
        hide_index=True,
        selection_mode="multi-row",
        on_select="rerun",
        key=f"df_add_{scope}_{filter_hash}",
    )

    selected_rows = [
        r for r in (event.selection.rows if event.selection else []) if r < len(df_pool)
    ]
    selected_ids = [int(df_pool.iloc[r]["player_id"]) for r in selected_rows]
    n_selected = len(selected_ids)

    if n_selected > slots_left:
        st.warning(
            f"Selected {n_selected} players but only {slots_left} slots left. "
            f"Deselect {n_selected - slots_left} player(s)."
        )
    elif n_selected > 0 and st.button(
        f"Add {n_selected} to {label}", key=f"btn_add_{scope}", type="primary"
    ):
        ids_stored.update(selected_ids)
        save_fn(ids_stored)
        st.session_state.pop(f"df_add_{scope}_{filter_hash}", None)
        st.rerun()


def _render_remove_section(  # noqa: PLR0913
    df: pd.DataFrame,
    ids_stored: set[int],
    scope: str,
    save_fn: Callable,
    also_remove_from: set[int] | None = None,
    also_save_fn: Callable | None = None,
) -> None:
    """Render a multiselect and a button to remove players from a target set."""
    if not ids_stored:
        return

    label = " ".join([word.capitalize() for word in scope.replace("_", " ").split(" ")])

    st.divider()
    st.markdown(f"**Remove players from {label}**")
    players_to_remove = st.multiselect(
        f"Select players to remove from {label}",  # noqa: S608
        options=_sort_players(df[df["player_id"].isin(ids_stored)]).to_dict("records"),
        format_func=_player_label,
        key=f"select_remove_{scope}",
    )
    if (
        st.button(f"Remove from {label}", key=f"btn_remove_{scope}")
        and players_to_remove
    ):
        for player in players_to_remove:
            player_id = player["player_id"]
            ids_stored.discard(player_id)
            if also_remove_from is not None:
                also_remove_from.discard(player_id)
        save_fn(ids_stored)
        if also_save_fn is not None and also_remove_from is not None:
            also_save_fn(also_remove_from)
        st.rerun()


def _render_squad_tab(  # noqa: PLR0913
    df: pd.DataFrame,
    ids_squad: set[int],
    ids_team: set[int],
    save_squad_fn: Callable,
    save_team_fn: Callable,
    *,
    prefix: str = "squad",
    ids_excluded: set[int] | None = None,
) -> None:
    """Render squad management tab content."""
    st.subheader(f"Squad ({len(ids_squad)}/{MAX_SQUAD_SIZE})")

    if ids_squad:
        _render_players(df, ids_squad)
    else:
        st.info("Your squad is empty. Add players below.")

    st.divider()
    st.markdown("**Add players to squad**")

    exclude = ids_squad | (ids_excluded or set())
    df_available = df[~df["player_id"].isin(exclude)]
    filtered = _apply_filters(df_available, prefix)
    ids_available = set(filtered["player_id"].tolist())

    _render_add_section(
        df,
        ids_available,
        ids_squad,
        MAX_SQUAD_SIZE,
        scope=prefix,
        save_fn=save_squad_fn,
    )
    _render_remove_section(
        df,
        ids_squad,
        prefix,
        save_squad_fn,
        also_remove_from=ids_team,
        also_save_fn=save_team_fn,
    )


def _render_team_tab(
    df: pd.DataFrame,
    ids_squad: set[int],
    ids_team: set[int],
    save_team_fn: Callable,
    *,
    prefix: str = "team",
) -> None:
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

    _render_add_section(
        df,
        ids_bench,
        ids_team,
        MAX_TEAM_SIZE,
        scope=prefix,
        save_fn=save_team_fn,
    )
    _render_remove_section(df, ids_team, prefix, save_team_fn)


def _render_view(
    df_all: pd.DataFrame,
    ids: tuple[set[int], set[int]],
    save_fns: tuple[Callable, Callable],
    *,
    prefix: str,
    ids_excluded: set[int] | None = None,
) -> None:
    """Render the squad and team tabs for a given view."""
    ids_squad, ids_team = ids
    save_squad_fn, save_team_fn = save_fns
    tab_squad, tab_team = st.tabs(
        [f"Squad ({len(ids_squad)})", f"Team ({len(ids_team)})"]
    )
    with tab_squad:
        _render_squad_tab(
            df_all,
            ids_squad,
            ids_team,
            save_squad_fn,
            save_team_fn,
            prefix=f"{prefix}_squad",
            ids_excluded=ids_excluded,
        )
    with tab_team:
        _render_team_tab(
            df_all,
            ids_squad,
            ids_team,
            save_team_fn,
            prefix=f"{prefix}_team",
        )


def _load_ids(
    load_squad_fn: Callable,
    load_team_fn: Callable,
    ids_valid: set[int],
    *,
    squad_key: str,
    team_key: str,
) -> tuple[set[int], set[int]]:
    """Load and initialise session-state sets for a squad/team pair."""
    persisted_squad = load_squad_fn() & ids_valid
    persisted_team = load_team_fn() & persisted_squad

    if squad_key not in st.session_state:
        st.session_state[squad_key] = persisted_squad
    if team_key not in st.session_state:
        st.session_state[team_key] = persisted_team

    return st.session_state[squad_key], st.session_state[team_key]


def main() -> None:
    """Render the Squad and Team page."""
    st.title("👥 Squad and Team")

    get_user_email()

    players_all = load_enriched_players()
    if not players_all:
        st.error("No player data available.")
        return

    df_all = pd.DataFrame(players_all)
    ids_valid = set(df_all["player_id"].tolist())

    # Load both sets
    ids_squad, ids_team = _load_ids(
        load_squad,
        load_team,
        ids_valid,
        squad_key="ids_squad",
        team_key="ids_team",
    )
    ids_opp_squad, ids_opp_team = _load_ids(
        load_opponent_squad,
        load_opponent_team,
        ids_valid,
        squad_key="ids_opp_squad",
        team_key="ids_opp_team",
    )

    view = st.radio(
        "View",
        options=["My Squad and Team", "Opponent Squad and Team"],
        horizontal=True,
        key="squad_view_selector",
    )

    if view == "My Squad and Team":
        _render_view(
            df_all,
            (ids_squad, ids_team),
            (save_squad, save_team),
            prefix="my",
            ids_excluded=ids_opp_squad,
        )
    else:
        _render_view(
            df_all,
            (ids_opp_squad, ids_opp_team),
            (save_opponent_squad, save_opponent_team),
            prefix="opp",
            ids_excluded=ids_squad,
        )

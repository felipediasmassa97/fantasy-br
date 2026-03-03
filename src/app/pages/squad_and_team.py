"""Squad and Team management page."""

# fixit test squad feature
# fixit test team feature
# fixit test with different email too

import pandas as pd
import streamlit as st
from utils import (
    get_user_email,
    load_players,
    load_squad,
    load_team,
    save_squad,
    save_team,
)

MAX_SQUAD_SIZE = 23
MAX_TEAM_SIZE = 11

# Position ordering for display
POSITION_ORDER = {"GK": 0, "CB": 1, "FB": 2, "MD": 3, "AT": 4}

_PLAYER_COL_CONFIG = {
    "player_id": None,
    "club_logo_url": st.column_config.ImageColumn("Club", width=50),
}


def _sort_players(df: pd.DataFrame) -> pd.DataFrame:
    """Sort players by position order then name."""
    df = df.copy()
    df["_pos_order"] = df["position"].map(POSITION_ORDER).fillna(99)
    return df.sort_values(["_pos_order", "player_name"]).drop(columns=["_pos_order"])


def _player_label(row: pd.Series) -> str:
    """Format a player row as a human-readable label."""
    return f"{row['player_name']} ({row['position']} - {row['club']})"


def _build_options(df: pd.DataFrame) -> dict[str, int]:
    """Build label -> player_id mapping from a sorted DataFrame."""
    return {_player_label(row): row["player_id"] for _, row in df.iterrows()}


def _show_player_table(all_df: pd.DataFrame, player_ids: set[int]) -> None:
    """Display a dataframe for the given player IDs."""
    df = _sort_players(all_df[all_df["player_id"].isin(player_ids)])
    st.dataframe(
        df,
        column_config=_PLAYER_COL_CONFIG,
        use_container_width=True,
        hide_index=True,
    )


def _apply_filters(
    df: pd.DataFrame,
    name_key: str,
    club_key: str,
    pos_key: str,
) -> pd.DataFrame:
    """Render filter widgets and return the filtered DataFrame."""
    col1, col2, col3 = st.columns(3)
    with col1:
        name_search = st.text_input(
            "Search by name", key=name_key, placeholder="Type a name..."
        )
    with col2:
        clubs = ["All", *sorted(df["club"].unique())]
        club_filter = st.selectbox("Club", clubs, key=club_key)
    with col3:
        positions = ["All", *sorted(df["position"].unique())]
        pos_filter = st.selectbox("Position", positions, key=pos_key)

    filtered = df
    if name_search:
        filtered = filtered[
            filtered["player_name"].str.contains(name_search, case=False, na=False)
        ]
    if club_filter != "All":
        filtered = filtered[filtered["club"] == club_filter]
    if pos_filter != "All":
        filtered = filtered[filtered["position"] == pos_filter]
    return _sort_players(filtered)


def _render_add_section(
    all_df: pd.DataFrame,
    pool_ids: set[int],
    target_ids: set[int],
    max_size: int,
    *,
    select_key: str,
    btn_key: str,
    label: str,
    also_remove_from: set[int] | None = None,
) -> None:
    """Render a multiselect + button to add players to a target set."""
    pool_df = all_df[all_df["player_id"].isin(pool_ids)]
    if pool_df.empty:
        st.write(f"No players available to add to {label.lower()}.")
        return

    options = _build_options(_sort_players(pool_df))
    selected = st.multiselect(
        f"Select players to add to {label.lower()}",
        options=list(options.keys()),
        key=select_key,
        max_selections=max(0, max_size - len(target_ids)),
    )
    if st.button(f"Add to {label.lower()}", key=btn_key) and selected:
        for lbl in selected:
            target_ids.add(options[lbl])
        _ = also_remove_from  # unused but kept for API symmetry
        st.rerun()


def _render_remove_section(
    all_df: pd.DataFrame,
    target_ids: set[int],
    *,
    select_key: str,
    btn_key: str,
    label: str,
    also_remove_from: set[int] | None = None,
) -> None:
    """Render a multiselect + button to remove players from a target set."""
    if not target_ids:
        return
    st.divider()
    st.markdown(f"**Remove players from {label.lower()}**")
    df = _sort_players(all_df[all_df["player_id"].isin(target_ids)])
    options = _build_options(df)
    selected = st.multiselect(
        f"Select players to remove from {label.lower()}",
        options=list(options.keys()),
        key=select_key,
    )
    if st.button(f"Remove from {label.lower()}", key=btn_key) and selected:
        for lbl in selected:
            pid = options[lbl]
            target_ids.discard(pid)
            if also_remove_from is not None:
                also_remove_from.discard(pid)
        st.rerun()


def _render_squad_tab(
    all_df: pd.DataFrame, squad_ids: set[int], team_ids: set[int]
) -> None:
    """Render squad management tab content."""
    st.subheader(f"Squad ({len(squad_ids)}/{MAX_SQUAD_SIZE})")

    if squad_ids:
        _show_player_table(all_df, squad_ids)
    else:
        st.info("Your squad is empty. Add players below.")

    st.divider()
    st.markdown("**Add players to squad**")

    available_df = all_df[~all_df["player_id"].isin(squad_ids)]
    filtered = _apply_filters(
        available_df, "squad_name_search", "squad_club_filter", "squad_pos_filter"
    )

    available_ids = set(filtered["player_id"].tolist())
    _render_add_section(
        all_df,
        available_ids,
        squad_ids,
        MAX_SQUAD_SIZE,
        select_key="squad_add_select",
        btn_key="btn_add_squad",
        label="Squad",
    )

    _render_remove_section(
        all_df,
        squad_ids,
        select_key="squad_remove_select",
        btn_key="btn_remove_squad",
        label="Squad",
        also_remove_from=team_ids,
    )


def _render_team_tab(
    all_df: pd.DataFrame, squad_ids: set[int], team_ids: set[int]
) -> None:
    """Render team management tab content."""
    st.subheader(f"Team ({len(team_ids)}/{MAX_TEAM_SIZE})")

    if not squad_ids:
        st.warning("Build your squad first before selecting a team.")
        return

    if team_ids:
        _show_player_table(all_df, team_ids)
    else:
        st.info("Your team is empty. Add players from your squad below.")

    st.divider()
    st.markdown("**Add players to team (from squad)**")

    bench_ids = squad_ids - team_ids
    _render_add_section(
        all_df,
        bench_ids,
        team_ids,
        MAX_TEAM_SIZE,
        select_key="team_add_select",
        btn_key="btn_add_team",
        label="Team",
    )

    _render_remove_section(
        all_df,
        team_ids,
        select_key="team_remove_select",
        btn_key="btn_remove_team",
        label="Team",
    )


def _render_save_bar(user_email: str, squad_ids: set[int], team_ids: set[int]) -> None:
    """Render the save button and success message."""
    st.divider()
    col_save, col_status = st.columns([1, 3])
    with col_save:
        if st.button("Save to database", type="primary", use_container_width=True):
            save_squad(user_email, sorted(squad_ids))
            save_team(user_email, sorted(team_ids))
            st.session_state["_save_success"] = True
            st.rerun()
    with col_status:
        if st.session_state.get("_save_success"):
            st.success(
                f"Saved squad ({len(squad_ids)} players) "
                f"and team ({len(team_ids)} players)."
            )
            st.session_state["_save_success"] = False


def main() -> None:
    """Render the Squad and Team page."""
    st.title("Squad and Team")

    user_email = get_user_email()

    all_players = load_players()
    if not all_players:
        st.error("No player data available. Run the dbt pipeline first.")
        return

    all_df = pd.DataFrame(all_players)
    valid_ids = set(all_df["player_id"].tolist())

    # Load persisted selections and validate against current data
    persisted_squad = set(load_squad(user_email)) & valid_ids
    persisted_team = set(load_team(user_email)) & persisted_squad

    if "squad_ids" not in st.session_state:
        st.session_state["squad_ids"] = persisted_squad
    if "team_ids" not in st.session_state:
        st.session_state["team_ids"] = persisted_team

    squad_ids: set[int] = st.session_state["squad_ids"]
    team_ids: set[int] = st.session_state["team_ids"]

    tab_squad, tab_team = st.tabs(["Squad (23)", "Team (11)"])
    with tab_squad:
        _render_squad_tab(all_df, squad_ids, team_ids)
    with tab_team:
        _render_team_tab(all_df, squad_ids, team_ids)

    _render_save_bar(user_email, squad_ids, team_ids)

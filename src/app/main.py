"""Streamlit app for Fantasy BR player statistics."""

import streamlit as st
from google.cloud import bigquery
from google.oauth2 import service_account

PROJECT_ID = "fantasy-br"
DATASET_ID = "fdmdev_fantasy_br"


@st.cache_resource
def get_client() -> bigquery.Client:
    """Get BigQuery client."""
    credentials = service_account.Credentials.from_service_account_info(
        st.secrets["gcp_service_account"],
    )
    return bigquery.Client(project=PROJECT_ID, credentials=credentials)


@st.cache_data(ttl=300)
def load_data(view_name: str) -> list[dict]:
    """Load data from a BigQuery view."""
    client = get_client()
    query = f"""
        SELECT * FROM `{PROJECT_ID}.{DATASET_ID}.{view_name}`
        ORDER BY pts_avg DESC
    """  # noqa: S608
    return [dict(row) for row in client.query(query).result()]


def main() -> None:
    """Run app."""
    st.set_page_config(page_title="Fantasy BR", page_icon="⚽", layout="wide")
    st.title("Fantasy BR - Player Statistics")

    filter_options = {
        "Last Match": "kpi_last_played",
        "Last 5 Matches": "kpi_last_5_played",
        "Last 3 Home Matches": "kpi_last_3_home",
        "Last 3 Away Matches": "kpi_last_3_away",
        "This Season": "kpi_this_season",
        "Last Season": "kpi_last_season",
    }

    selected_filter = st.selectbox("Select Filter", options=list(filter_options.keys()))
    view_name = filter_options[selected_filter]

    with st.spinner("Loading data..."):
        data = load_data(view_name)

    # Extract unique values for dropdowns
    clubs = sorted({row["club"] for row in data if row.get("club")})
    positions = sorted({row["position"] for row in data if row.get("position")})

    # Post-filters
    col1, col2, col3 = st.columns(3)
    with col1:
        name_filter = st.text_input("Player Name", placeholder="Search by name...")
    with col2:
        club_filter = st.selectbox("Club", options=["All", *clubs])
    with col3:
        position_filter = st.selectbox("Position", options=["All", *positions])

    # Apply filters
    filtered_data = data
    if name_filter:
        filtered_data = [
            row
            for row in filtered_data
            if name_filter.lower() in row.get("name", "").lower()
        ]
    if club_filter != "All":
        filtered_data = [row for row in filtered_data if row.get("club") == club_filter]
    if position_filter != "All":
        filtered_data = [
            row for row in filtered_data if row.get("position") == position_filter
        ]

    st.subheader(f"Players ({len(filtered_data)} of {len(data)})")
    st.dataframe(
        filtered_data,
        use_container_width=True,
        hide_index=True,
        column_config={
            "id": st.column_config.NumberColumn("ID", format="%d"),
            "name": st.column_config.TextColumn("Name"),
            "club": st.column_config.TextColumn("Club"),
            "position": st.column_config.TextColumn("Position"),
            "matches_counted": st.column_config.NumberColumn("Matches", format="%d"),
            "pts_avg": st.column_config.NumberColumn("Avg Points", format="%.2f"),
            "availability": st.column_config.NumberColumn("Availability", format=".0%"),
        },
    )


if __name__ == "__main__":
    main()

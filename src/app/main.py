"""Streamlit app for Fantasy BR player statistics."""

import streamlit as st
from google.cloud import bigquery
from google.oauth2 import service_account

PROJECT_ID = "fantasy-br"
DATASET_ID = "fdmdev_fantasy_br"


@st.cache_resource
def get_client() -> bigquery.Client:
    """Get BigQuery client."""
    if "gcp_service_account" in st.secrets:
        credentials = service_account.Credentials.from_service_account_info(
            st.secrets["gcp_service_account"],
        )
        return bigquery.Client(project=PROJECT_ID, credentials=credentials)
    return bigquery.Client(project=PROJECT_ID)


@st.cache_data(ttl=300)
def load_data(view_name: str) -> list[dict]:
    """Load data from a BigQuery view."""
    client = get_client()
    query = f"""
        SELECT * FROM `{PROJECT_ID}.{DATASET_ID}.{view_name}`
        ORDER BY pts_avg DESC
    """
    return [dict(row) for row in client.query(query).result()]


def main() -> None:
    """Run app."""
    st.set_page_config(page_title="Fantasy BR", page_icon="⚽", layout="wide")
    st.title("Fantasy BR - Player Statistics")

    filter_options = {
        "Last Played (Current Season)": "kpi_last_played",
        "Last 5 Played (Current Season)": "kpi_last_5_played",
        "Last Season (2025)": "kpi_last_season",
    }

    selected_filter = st.selectbox("Select Filter", options=list(filter_options.keys()))
    view_name = filter_options[selected_filter]

    with st.spinner("Loading data..."):
        data = load_data(view_name)

    st.subheader(f"Players ({len(data)} total)")
    st.dataframe(
        data,
        use_container_width=True,
        hide_index=True,
        column_config={
            "id": st.column_config.NumberColumn("ID", format="%d"),
            "name": st.column_config.TextColumn("Name"),
            "club": st.column_config.TextColumn("Club"),
            "position": st.column_config.TextColumn("Position"),
            "pts_avg": st.column_config.NumberColumn("Avg Points", format="%.2f"),
            "pts_round": st.column_config.NumberColumn("Round Points", format="%.2f"),
            "round_id": st.column_config.NumberColumn("Round", format="%d"),
            "matches_counted": st.column_config.NumberColumn("Matches", format="%d"),
        },
    )


if __name__ == "__main__":
    main()

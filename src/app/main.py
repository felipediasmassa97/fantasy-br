"""Fantasy BR - Streamlit application entry point."""

import streamlit as st
from pages.market_valuation import main as market_valuation
from pages.scouting import main as scouting
from pages.start_or_sit import main as start_or_sit

st.set_page_config(
    page_title="Fantasy BR",
    page_icon=":shallow_pan_of_food:",
    layout="wide",
)

pg = st.navigation(
    [
        st.Page(scouting, title="Scouting", icon="🔍", url_path="scouting"),
        st.Page(start_or_sit, title="Start or Sit", icon="⚖️", url_path="start-or-sit"),
        st.Page(
            market_valuation,
            title="Market Valuation",
            icon="💰",
            url_path="market-valuation",
        ),
    ]
)
pg.run()

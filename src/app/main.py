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

# Auth with Google account (using Streamlit's built-in authentication)
if not st.user.is_logged_in:
    st.title(":shallow_pan_of_food: Fantasy BR")
    st.write("Sign in with your Google account to continue.")
    st.button("Sign in with Google", on_click=st.login, use_container_width=False)
    st.stop()

with st.sidebar:
    st.write(f"Welcome, **{st.user.name}**!")
    st.button("Sign out", on_click=st.logout, key="signout")

pg = st.navigation(
    [
        st.Page(
            scouting,
            title="Scouting",
            icon="🔍",
            url_path="scouting",
        ),
        st.Page(
            start_or_sit,
            title="Start or Sit",
            icon="⚖️",
            url_path="start-or-sit",
        ),
        st.Page(
            market_valuation,
            title="Market Valuation",
            icon="💰",
            url_path="market-valuation",
        ),
    ]
)
pg.run()

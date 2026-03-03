# To-Dos

- Data Loading

- Data Model
  - Performance
  - Refactoring
  - KPIs
    - [ ] !!! Remove red card and own goal from base average
    - [ ] !!! Add PoE (points over expected) to Start/Sit (cumulative PoE + last 5 PoE)
    - [ ] !!! Add trade fairness delta
    - [ ] Add Strength of Schedule for next 10 games (based on MPAP) -> Market Valuation metric
    - [ ] Add Strength of Schedule for next 5 home games (based on MPAP) -> Market Valuation metric
    - [ ] Add Strength of Schedule for next 5 away games (based on MPAP) -> Market Valuation metric
    - [ ] Add ELO or Power Index for each player
    - [ ] Update ELO or Power Index each week (start with base ELO maybe)
  - Scouts
    - [ ] !!! Show scouts for home matches
    - [ ] !!! Show scouts for away matches
  - Validation

- Streamlit App
  - Refactoring
    - [ ] !!! Refactor squad and team page
    - [ ] Remove noqa and apply best practices
  - [ ] !!! Fix interaction bug on Scouting page
  - [ ] !!! Fix round-by-round bug on Start or Sit
  - [ ] Improve tooltips (clear, with intuition on metric definition, must say whether higher is better or worse, must disclaim premises and assumptions)
  - [ ] !!! Add trade-fairness page (select players for trade)
  - [ ] !!! Add trade fairness delta (select groups of players from both sides and check overall PAR delta)
  - !!! Squad and Team
    - [ ] Add user-specific squads (persist in database)
    - [ ] Add "My Squad" (using user info from auth)
    - [ ] Add "My Team" (subset of my squad)
    - [ ] Add toggles for my team and my squad on visualizations
    - [ ] Add "My Opponent Squad" - goal: estimate points, evaluate trades
    - [ ] Add "My Opponent Team" - goal: estimate points
    - [ ] Test Squad feature
    - [ ] Test Team feature
    - [ ] Test Squad and Team with other email

- Documentation

- Panela FC
  - [ ] Emulate mobile app to get internal API to fetch players' squads

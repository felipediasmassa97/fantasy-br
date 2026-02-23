# To-Dos

- Data loading

- Data model
  - KPIs
    - [x] Add last 10 matches view
    - [x] Last 5 home matches and last 5 away matches KPIs
    - [x] Adapt views for "as of round" data
    - [ ] Add Matchup-Adjusted Projection (MAP)
      - [ ] Add player baseline
      - [ ] Add home-away effect
      - [ ] Add form effect
      - [ ] Add opponent strength effect
    - [ ] Add ELO or Power Index for each player
    - [ ] Update ELO or Power Index each week (start with base ELO maybe)
  - Scouts
    - [ ] Show scouts for home games
    - [ ] Show scouts for away games
  - Validation
    - [ ] Validate metrics
    - [ ] Add tests for validated metrics (anchor on round 3)
  - Materalization
    - [ ] Materialize views as tables to reduce load time

- Streamlit app
  - [x] Add clubs logos
  - [x] Add tooltips for all metrics
  - [x] Add G/A per match to detailed metrics
  - [ ] Add authentication (login)
  - [ ] Add user-specific squads (persist in database)

- Text files
  - [ ] Review files (pyproject.toml, schemas, profiles, ...)
  - [ ] Review and improve documentation (README.md, AGENTS.md, ...)

- Panela FC
  - [ ] Emulate mobile app to get internal API to fetch players' squads

- Intelligence
  - Weekly lineup optimization
    - !!! Matchup-Adjusted Projection (MAP): A single-week projection blending player baseline + home/away + matchup.
    - ! Matchup Points Allowed by Position (MPAP): Difficulty of the opponent for a position
    - ! Recency-Weighted Form (EWM points): A “hotness” metric built as exponentially weighted moving average of points.
    - ! Floor / Median / Ceiling: Percentile-based range of outcomes (e.g., floor=25th percentile, ceiling=75th/85th).
    - ! Consistency Rating (CV of points): Volatility normalized by production.
    - ! Points Over Expected (PoE): Actual minus expected.
  - Market decisions
    - !!! Points Above Replacement (PAR): Value over a replacement-level player at the same position.
    - ! Stabilized Mean / Shrinkage Value: Prevents small-sample miracles from polluting rankings.
    - ! Regression Candidate Score (Buy-Low / Sell-High): Combines PoE and opportunity to find mispriced players.
    - ! Trade Fairness Delta (ΔPAR): A cross-position “fairness” view aligned with trade value chart logic.

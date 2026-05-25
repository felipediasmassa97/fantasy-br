#!/bin/bash
set -euo pipefail
STATE_FILE="/tmp/bqml_model_state.json"
if [ -f "${STATE_FILE}" ]; then
  PROJECT=$(python3 -c "import json; print(json.load(open('${STATE_FILE}'))['project_id'])" 2>/dev/null)
  DATASET=$(python3 -c "import json; print(json.load(open('${STATE_FILE}'))['dataset_id'])" 2>/dev/null)
  MODEL=$(python3 -c "import json; print(json.load(open('${STATE_FILE}'))['model_name'])" 2>/dev/null)
  echo "==> Dropping BigQuery ML model from ${PROJECT}:${DATASET}..."
  bq rm -f "${PROJECT}:${DATASET}.${MODEL}" || true
  echo "    Done."
else
  echo "    State file not found — assuming already gone."
fi

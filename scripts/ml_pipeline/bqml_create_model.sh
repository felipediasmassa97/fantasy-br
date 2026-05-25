#!/bin/bash
# Main step: run CREATE MODEL if retrain is needed.
# Terraform variables passed via environment.

set -euo pipefail

PROJECT="${TF_PROJECT_ID}"
DATASET="${TF_DATASET}"
MODEL="${TF_MODEL}"
SQL_FILE="${TF_SQL_FILE}"
STATE_FILE="${TF_STATE_FILE}"

RETRAIN_NEEDED=$(python3 -c "import json; print(json.load(open('${STATE_FILE}'))['retrain_needed'])" 2>/dev/null || echo "yes")

if [ "${RETRAIN_NEEDED}" != "yes" ]; then
  echo "    No retrain needed — skipping CREATE MODEL."
  exit 0
fi

echo "==> Checking if BigQuery ML model '${MODEL}' exists..."
if bq ls "${PROJECT}:${DATASET}.${MODEL}" > /dev/null 2>&1; then
  echo "    Model exists — deleting old version for clean retrain..."
  bq rm -f "${PROJECT}:${DATASET}.${MODEL}"
fi

echo "==> Substituting dataset placeholder in training SQL..."
SQL_CONTENT=$(sed "s/DUMMY_DATASET_PLACEHOLDER/${DATASET}/g" "${SQL_FILE}")

echo "==> Registering BigQuery ML model..."
echo "${SQL_CONTENT}" | bq query --nouse_legacy_sql --use_legacy_sql=false --dataset_id="${DATASET}"

echo "==> Verifying model registration..."
bq show -model "${PROJECT}:${DATASET}.${MODEL}"

echo "    Model '${MODEL}' registered successfully."
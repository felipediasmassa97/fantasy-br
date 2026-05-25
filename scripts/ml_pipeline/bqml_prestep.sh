#!/bin/bash
# Pre-step: compute hash of training query output and decide if retrain is needed.
# Builds full training features SQL from ml_training_features.sql.

set -euo pipefail

PROJECT="${TF_PROJECT_ID}"
DATASET="${TF_DATASET}"
MODEL="${TF_MODEL}"
SQL_FILE="${TF_SQL_FILE}"
FEATURES_FILE="${TF_FEATURES_FILE}"
STATE_FILE="${TF_STATE_FILE}"

echo "==> Computing training query output hash..."
echo "    FEATURES_FILE=${FEATURES_FILE}"
echo "    STATE_FILE=${STATE_FILE}"

if ! command -v bq > /dev/null 2>&1; then
  echo "ERROR: bq CLI not found"
  exit 1
fi

if [ ! -f "${STATE_FILE}" ]; then
  echo "ERROR: State file not found: ${STATE_FILE}"
  exit 1
fi

# Extract the full features SQL:
# 1. WITH block: from "WITH" line to just before "training_data AS ("
# 2. training_data AS block: from "training_data AS (" to end of file (includes final SELECT)
WITH_LINE=$(grep -n "^WITH$" "${FEATURES_FILE}" | head -1 | cut -d: -f1)
TD_START=$(grep -n "training_data AS (" "${FEATURES_FILE}" | head -1 | cut -d: -f1)
WITH_BLOCK=$(sed -n "${WITH_LINE},$((TD_START - 1))p" "${FEATURES_FILE}")
TD_BLOCK=$(tail -n +"${TD_START}" "${FEATURES_FILE}")
FEATURES_SQL="${WITH_BLOCK}${TD_BLOCK}"

echo "    Built features SQL: ${#FEATURES_SQL} chars"

# Replace hardcoded dataset with actual dataset in all model references
FEATURES_SQL=$(echo "${FEATURES_SQL}" | sed "s/fdmdev_fantasy_br/${DATASET}/g")

echo "    Running features query for hash computation..."
set +e
BQ_OUTPUT=$(bq query --nouse_legacy_sql --use_legacy_sql=false \
  --format=json \
  --max_rows=100000 \
  "SELECT * FROM (${FEATURES_SQL}) ORDER BY 1,2" 2>&1)
BQ_EXIT=$?
set -e

if [ ${BQ_EXIT} -ne 0 ]; then
  echo "ERROR: bq query failed with exit code ${BQ_EXIT}"
  echo "Output: ${BQ_OUTPUT:0:1000}"
  exit 1
fi

RESULT_HASH=$(echo "${BQ_OUTPUT}" | sha256sum | cut -d' ' -f1)
echo "    Result hash: ${RESULT_HASH}"

PREV_SQL_HASH=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('sql_hash','none'))")
PREV_FEATURES_HASH=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('features_hash','none'))")
PREV_RESULT_HASH=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('result_hash','none'))")

CURRENT_SQL_HASH=$(sha256sum "${SQL_FILE}" | cut -d' ' -f1)
CURRENT_FEATURES_HASH=$(sha256sum "${FEATURES_FILE}" | cut -d' ' -f1)

SQL_CHANGED=$([ "${PREV_SQL_HASH}" != "${CURRENT_SQL_HASH}" ] && echo "yes" || echo "no")
FEATURES_CHANGED=$([ "${PREV_FEATURES_HASH}" != "${CURRENT_FEATURES_HASH}" ] && echo "yes" || echo "no")
RESULT_CHANGED=$([ "${PREV_RESULT_HASH}" != "${RESULT_HASH}" ] && echo "yes" || echo "no")

echo "    SQL changed: ${SQL_CHANGED}"
echo "    Features changed: ${FEATURES_CHANGED}"
echo "    Result changed: ${RESULT_CHANGED}"

RETRAIN_NEEDED="no"
if [ "${SQL_CHANGED}" == "yes" ] || [ "${FEATURES_CHANGED}" == "yes" ] || [ "${RESULT_CHANGED}" == "yes" ]; then
  RETRAIN_NEEDED="yes"
  echo "    Retrain will be triggered."
else
  echo "    No retrain needed — model is up to date."
fi

python3 - << PYEOF
import json
d = {
    'sql_hash': '${CURRENT_SQL_HASH}',
    'features_hash': '${CURRENT_FEATURES_HASH}',
    'result_hash': '${RESULT_HASH}',
    'retrain_needed': '${RETRAIN_NEEDED}',
    'project_id': '${PROJECT}',
    'dataset_id': '${DATASET}',
    'model_name': '${MODEL}'
}
with open('${STATE_FILE}', 'w') as f:
    json.dump(d, f)
PYEOF

echo "    State file updated."
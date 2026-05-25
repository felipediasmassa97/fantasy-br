#!/usr/bin/env bash
# Pre-step: compute hash of training query output and decide if retrain is needed.

set -euo pipefail

PROJECT="${TF_PROJECT_ID}"
DATASET="${TF_DATASET}"
MODEL="${TF_MODEL}"
SQL_FILE="${TF_SQL_FILE}"
FEATURES_FILE="${TF_FEATURES_FILE}"
STATE_FILE="${TF_STATE_FILE}"

echo "==> Computing training query output hash..."

if ! command -v bq > /dev/null 2>&1; then
  echo "ERROR: bq CLI not found"
  exit 1
fi

if [ ! -f "${STATE_FILE}" ]; then
  echo "ERROR: State file not found: ${STATE_FILE}"
  exit 1
fi

# Extract features SQL via dedicated helper script
SCRIPT_DIR=$(cd "${path.module}/../../../scripts/ml_pipeline" && pwd)
FEATURES_SQL=$(python3 "${SCRIPT_DIR}/extract_features.py" "${FEATURES_FILE}" "${DATASET}")

echo "    Built features SQL: ${#FEATURES_SQL} chars"

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

PREV=$(python3 -c "import json; print(json.load(open('${STATE_FILE}')).get('sql_hash','none'))")
PREV_FEAT=$(python3 -c "import json; print(json.load(open('${STATE_FILE}')).get('features_hash','none'))")
PREV_RES=$(python3 -c "import json; print(json.load(open('${STATE_FILE}')).get('result_hash','none'))")

CURRENT_SQL_HASH=$(sha256sum "${SQL_FILE}" | cut -d' ' -f1)
CURRENT_FEATURES_HASH=$(sha256sum "${FEATURES_FILE}" | cut -d' ' -f1)

SQL_CHANGED=$([ "${PREV}" != "${CURRENT_SQL_HASH}" ] && echo "yes" || echo "no")
FEATURES_CHANGED=$([ "${PREV_FEAT}" != "${CURRENT_FEATURES_HASH}" ] && echo "yes" || echo "no")
RESULT_CHANGED=$([ "${PREV_RES}" != "${RESULT_HASH}" ] && echo "yes" || echo "no")

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

# Write state file
python3 -c "
import json, sys
d = {
    'sql_hash': sys.argv[1],
    'features_hash': sys.argv[2],
    'result_hash': sys.argv[3],
    'retrain_needed': sys.argv[4],
    'project_id': sys.argv[5],
    'dataset_id': sys.argv[6],
    'model_name': sys.argv[7]
}
with open(sys.argv[8], 'w') as f:
    json.dump(d, f)
" -- \
  "${CURRENT_SQL_HASH}" "${CURRENT_FEATURES_HASH}" "${RESULT_HASH}" \
  "${RETRAIN_NEEDED}" "${PROJECT}" "${DATASET}" "${MODEL}" "${STATE_FILE}"

echo "    State file updated."
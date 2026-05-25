#!/bin/bash
# Pre-step: compute hash of training query output and decide if retrain is needed.

set -euo pipefail

PROJECT="${TF_PROJECT_ID}"
DATASET="${TF_DATASET}"
MODEL="${TF_MODEL}"
SQL_FILE="${TF_SQL_FILE}"
FEATURES_FILE="${TF_FEATURES_FILE}"
STATE_FILE="${TF_STATE_FILE}"

echo "==> Computing training query output hash..."
echo "    SQL_FILE=${SQL_FILE}"
echo "    STATE_FILE=${STATE_FILE}"
echo "    DATASET=${DATASET}"

# Check bq availability
if ! command -v bq > /dev/null 2>&1; then
  echo "ERROR: bq CLI not found in PATH"
  echo "PATH=$PATH"
  exit 1
fi
echo "    bq found at: $(which bq)"

# Check state file exists (written by local_file resource)
if [ ! -f "${STATE_FILE}" ]; then
  echo "ERROR: State file not found: ${STATE_FILE}"
  exit 1
fi
echo "    State file OK"

# Replace DUMMY_DATASET_PLACEHOLDER in the features SQL
FEATURES_SQL=$(sed '/WITH/,/training_data AS (/p' "${SQL_FILE}" | head -n -1 | sed "s/DUMMY_DATASET_PLACEHOLDER/${DATASET}/g")
echo "    FEATURES_SQL extracted: ${FEATURES_SQL:0:100}..."

# Run the features query and compute hash
set +e  # Don't fail on bq error — we want to see the output
BQ_OUTPUT=$(bq query --nouse_legacy_sql --use_legacy_sql=false \
  --format=json \
  --max_rows=100000 \
  "SELECT * FROM (${FEATURES_SQL}) ORDER BY 1,2" 2>&1)
BQ_EXIT=$?
echo "    bq exit code: ${BQ_EXIT}"
echo "    bq output (first 200 chars): ${BQ_OUTPUT:0:200}"

if [ ${BQ_EXIT} -ne 0 ]; then
  echo "ERROR: bq query failed with exit code ${BQ_EXIT}"
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
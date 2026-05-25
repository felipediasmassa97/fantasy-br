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

if ! command -v bq > /dev/null 2>&1; then
  echo "ERROR: bq CLI not found"
  exit 1
fi

if [ ! -f "${STATE_FILE}" ]; then
  echo "ERROR: State file not found: ${STATE_FILE}"
  exit 1
fi

# Extract features SQL using Python (inline script avoids fragile shell escaping):
# - WITH block: line after "WITH" to just before "training_data AS ("
# - training_data AS block: from "training_data AS (" to end, stripped of trailing SELECT/ORDER BY
# - Replace fdmdev_fantasy_br with actual dataset
FEATURES_SQL=$(python3 - "$FEATURES_FILE" "$DATASET" << 'PYEOF'
import sys, re
features_file = sys.argv[1]
dataset = sys.argv[2]
with open(features_file) as f:
    content = f.read()
lines = content.split('\n')
with_line = next(i for i, l in enumerate(lines, 1) if l.strip() == 'WITH')
td_start = next(i for i, l in enumerate(lines, 1) if 'training_data AS (' in l)
with_block = '\n'.join(lines[with_line-1:td_start-1])
td_block = '\n'.join(lines[td_start-1:])
td_block = re.sub(r'\nSELECT \* FROM training_data\n.*$', '', td_block, flags=re.DOTALL)
features_sql = (with_block + '\n' + td_block).replace('fdmdev_fantasy_br', dataset)
print(features_sql)
PYEOF
)

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

PREV_SQL_HASH=$(python3 -c "
import json
d=json.load(open('${STATE_FILE}'))
print(d.get('sql_hash','none'))
")
PREV_FEATURES_HASH=$(python3 -c "
import json
d=json.load(open('${STATE_FILE}'))
print(d.get('features_hash','none'))
")
PREV_RESULT_HASH=$(python3 -c "
import json
d=json.load(open('${STATE_FILE}'))
print(d.get('result_hash','none'))
")

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

python3 - "${STATE_FILE}" "${CURRENT_SQL_HASH}" "${CURRENT_FEATURES_HASH}" "${RESULT_HASH}" "${RETRAIN_NEEDED}" "${PROJECT}" "${DATASET}" "${MODEL}" << 'PYEOF'
import sys, json
state_file = sys.argv[1]
d = {
    'sql_hash': sys.argv[2],
    'features_hash': sys.argv[3],
    'result_hash': sys.argv[4],
    'retrain_needed': sys.argv[5],
    'project_id': sys.argv[6],
    'dataset_id': sys.argv[7],
    'model_name': sys.argv[8]
}
with open(state_file, 'w') as f:
    json.dump(d, f)
PYEOF

echo "    State file updated."
#!/usr/bin/env python3
"""Extract and prepare the training features SQL from ml_training_features.sql."""
import sys, re

features_file = sys.argv[1]
dataset = sys.argv[2]

with open(features_file) as f:
    content = f.read()

lines = content.split('\n')

# Find WITH line and training_data AS ( line
with_line = next(i for i, l in enumerate(lines, 1) if l.strip() == 'WITH')
td_start = next(i for i, l in enumerate(lines, 1) if 'training_data AS (' in l)

# WITH block: from WITH to just before training_data AS (
with_block = ''.join(lines[with_line - 1:td_start - 1])

# training_data AS block: from training_data AS ( to end of file
# Remove trailing "SELECT * FROM training_data ORDER BY ..."
td_block = ''.join(lines[td_start - 1:])
td_block = re.sub(r'\nSELECT \* FROM training_data\n.*$', '', td_block, flags=re.DOTALL)

# Combine WITH + training_data and replace dataset
features_sql = with_block + td_block
features_sql = features_sql.replace('fdmdev_fantasy_br', dataset)

# Remove ORDER BY from inside the training_data block (only the outer query should have it)
features_sql = re.sub(r'\n\s*ORDER BY.*$', '', features_sql, flags=re.MULTILINE)

print(features_sql)
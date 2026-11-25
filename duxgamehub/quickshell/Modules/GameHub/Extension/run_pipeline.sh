#!/bin/bash
# Wrapper to run enricher phases and log everything
echo "[$(date -Iseconds)] run_pipeline.sh called with: $@" >> /tmp/gamehub_debug.log
python3 -u "$@" 2>&1 | while read -r line; do
    echo "$line"
    if [[ "$line" == PROGRESS* ]] || [[ "$line" == RELOAD* ]] || [[ "$line" == METADATA_* ]]; then
        echo "[$(date -Iseconds)] $line" >> /tmp/gamehub_debug.log
    fi
done

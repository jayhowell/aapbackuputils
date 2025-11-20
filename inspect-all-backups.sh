#!/bin/bash

# Namespace containing the AAP restore environment
NAMESPACE="aap"

# Script that inspects a single PVC
INSPECT_SCRIPT="./inspectpvc.sh"

# Check that the inspect script exists and is executable
if [ ! -x "$INSPECT_SCRIPT" ]; then
  echo "❌ Error: $INSPECT_SCRIPT not found or not executable."
  exit 1
fi

echo "🔎 Collecting backup PVCs from namespace: $NAMESPACE"
echo ""

# Get all PVC names containing the word "backup"
PVC_LIST=$(oc -n "$NAMESPACE" get pvc -o name | grep backup | sed 's@persistentvolumeclaim/@@')

if [ -z "$PVC_LIST" ]; then
  echo "⚠️ No PVCs found containing the word 'backup'."
  exit 0
fi

# Arrays to store results
declare -a PVC_NAMES
declare -a BACKUP_DIRS

# Loop through PVCs
for pvc in $PVC_LIST; do
  echo "==============================================="
  echo "📦 Inspecting PVC: $pvc"
  echo "==============================================="
  
  # Capture the output of inspectpvc
  OUTPUT=$($INSPECT_SCRIPT "$pvc" 2>/dev/null)

  # Extract lines containing directories with "backup" in the name
  DIR_LIST=$(echo "$OUTPUT" | grep backup | awk '{print $9}')

  # If no directories found, record "(none)"
  if [ -z "$DIR_LIST" ]; then
    DIR_LIST="(none)"
  fi

  PVC_NAMES+=("$pvc")
  BACKUP_DIRS+=("$DIR_LIST")

  echo ""
done

echo ""
echo "====================================================="
echo "📊 BACKUP DIRECTORY SUMMARY"
echo "====================================================="
printf "%-35s | %-60s\n" "PVC NAME" "BACKUP DIRECTORIES"
printf "%-35s-+-%-60s\n" "-----------------------------------" "------------------------------------------------------------"

# Print table rows
for i in "${!PVC_NAMES[@]}"; do
  # Replace newlines with commas for multi-directory result
  CLEAN_DIRS=$(echo "${BACKUP_DIRS[$i]}" | tr '\n' ',' | sed 's/,$//')
  printf "%-35s | %-60s\n" "${PVC_NAMES[$i]}" "$CLEAN_DIRS"
done

echo "====================================================="
echo "✔ Completed."


#!/bin/bash

# ============================================================
# inspect-all-backups.sh
#
# Usage:
#   ./inspect-all-backups.sh [-n <namespace>] [--namespace=<namespace>]
#
# Only ONE namespace argument may be used.
# If none is provided, the current oc namespace is used.
# ============================================================

set -e

INSPECT_SCRIPT="./inspectpvc.sh"
NAMESPACE=""
NS_ARG_PROVIDED=0

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case $1 in
    -n)
      if [[ $NS_ARG_PROVIDED -eq 1 ]]; then
        echo "❌ Error: Namespace already provided. Use either -n <ns> OR --namespace=<ns>, not both."
        exit 1
      fi
      NS_ARG_PROVIDED=1
      shift
      NAMESPACE="$1"
      shift
      ;;
    --namespace=*)
      if [[ $NS_ARG_PROVIDED -eq 1 ]]; then
        echo "❌ Error: Namespace already provided. Use either -n <ns> OR --namespace=<ns>, not both."
        exit 1
      fi
      NS_ARG_PROVIDED=1
      NAMESPACE="${1#*=}"
      shift
      ;;
    *)
      echo "❌ Unknown argument: $1"
      echo "Usage: $0 [-n <namespace>] [--namespace=<ns>]"
      exit 1
      ;;
  esac
done

# --- Determine oc namespace flag ---
if [[ -n "$NAMESPACE" ]]; then
  NS_FLAG="-n $NAMESPACE"
  echo "🔎 Collecting backup PVCs from namespace: $NAMESPACE"
else
  NS_FLAG=""
  echo "🔎 Collecting backup PVCs from *current* namespace"
fi
echo ""

# --- Validate inspect script ---
if [[ ! -x "$INSPECT_SCRIPT" ]]; then
  echo "❌ Error: $INSPECT_SCRIPT not found or not executable."
  exit 1
fi

# --- Get PVC list containing 'backup' ---
PVC_LIST=$(oc $NS_FLAG get pvc -o name 2>/dev/null | grep backup | sed 's@persistentvolumeclaim/@@' || true)

if [[ -z "$PVC_LIST" ]]; then
  echo "⚠️ No PVCs found containing the word 'backup'."
  exit 0
fi

# Arrays to store results
declare -a PVC_NAMES
declare -a BACKUP_DIRS

# --- Loop through PVCs ---
for pvc in $PVC_LIST; do
  echo "==============================================="
  echo "📦 Inspecting PVC: $pvc"
  echo "==============================================="

  if [[ -n "$NAMESPACE" ]]; then
    OUTPUT=$($INSPECT_SCRIPT "$pvc" --namespace="$NAMESPACE" 2>/dev/null)
  else
    OUTPUT=$($INSPECT_SCRIPT "$pvc" 2>/dev/null)
  fi

  DIR_LIST=$(echo "$OUTPUT" | grep backup | awk '{print $9}')

  if [[ -z "$DIR_LIST" ]]; then
    DIR_LIST="(none)"
  fi

  PVC_NAMES+=("$pvc")
  BACKUP_DIRS+=("$DIR_LIST")
  echo ""
done

# --- Print summary table ---
echo ""
echo "====================================================="
echo "📊 BACKUP DIRECTORY SUMMARY"
echo "====================================================="
printf "%-35s | %-60s\n" "PVC NAME" "BACKUP DIRECTORIES"
printf "%-35s-+-%-60s\n" "-----------------------------------" "------------------------------------------------------------"

for i in "${!PVC_NAMES[@]}"; do
  CLEAN_DIRS=$(echo "${BACKUP_DIRS[$i]}" | tr '\n' ',' | sed 's/,$//')
  printf "%-35s | %-60s\n" "${PVC_NAMES[$i]}" "$CLEAN_DIRS"
done

echo "====================================================="
echo "✔ Completed."




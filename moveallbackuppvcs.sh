#!/bin/bash

# ============================================================
# move-all-backup-pvcs.sh
#
# Moves all PVCs containing the word "backup" from one namespace
# to another, using move-pvc.sh for each PVC.
#
# Usage:
#   ./move-all-backup-pvcs.sh \
#       --sourceNamespace=aap \
#       --destNamespace=aap-new
#
# Requires: move-pvc.sh in the same directory and executable.
# ============================================================

set -e

# --- Parse named arguments ---
for arg in "$@"; do
  case $arg in
    --sourceNamespace=*)
      SRC_NS="${arg#*=}"
      shift
      ;;
    --destNamespace=*)
      DEST_NS="${arg#*=}"
      shift
      ;;
    *)
      echo "❌ Unknown argument: $arg"
      echo "Usage:"
      echo "./move-all-backup-pvcs.sh --sourceNamespace=<ns> --destNamespace=<ns>"
      exit 1
      ;;
  esac
done

# --- Validate arguments ---
if [ -z "$SRC_NS" ] || [ -z "$DEST_NS" ]; then
  echo "❌ Missing required arguments."
  echo "Usage: ./move-all-backup-pvcs.sh --sourceNamespace=<ns> --destNamespace=<ns>"
  exit 1
fi

# --- Ensure move-pvc.sh exists ---
if [ ! -x "./move-pvc.sh" ]; then
  echo "❌ Error: move-pvc.sh not found or not executable in current directory."
  exit 1
fi

echo "📦 Moving all backup PVCs from '$SRC_NS' → '$DEST_NS'"
echo ""

# --- Get the PVC list ---
PVC_LIST=$(oc -n "$SRC_NS" get pvc -o name | grep backup | sed 's@persistentvolumeclaim/@@')

if [ -z "$PVC_LIST" ]; then
  echo "⚠️ No PVCs containing 'backup' found in namespace '$SRC_NS'"
  exit 0
fi

# --- Loop through PVCs ---
for pvc in $PVC_LIST; do
  echo "========================================================="
  echo "➡️ Moving PVC: $pvc"
  echo "========================================================="
  
  ./move-pvc.sh \
    --sourceNamespace="$SRC_NS" \
    --destNamespace="$DEST_NS" \
    --pvcName="$pvc"

  echo ""
done

echo "🎉 Done! All backup PVCs moved successfully."

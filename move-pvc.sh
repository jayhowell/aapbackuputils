#!/bin/bash

# ============================================
# move-pvc.sh
#
# Moves a PVC and its underlying PV from one
# namespace to another using named arguments:
#
#   ./move-pvc.sh --sourceNamespace=aap \
#                 --destNamespace=aap-new \
#                 --pvcName=aap-backup-claim
#
# ============================================

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
    --pvcName=*)
      PVC_NAME="${arg#*=}"
      shift
      ;;
    *)
      echo "❌ Unknown argument: $arg"
      echo "Usage:"
      echo "  ./move-pvc.sh --sourceNamespace=<ns> --destNamespace=<ns> --pvcName=<name>"
      exit 1
      ;;
  esac
done

# --- Validate required args ---
if [ -z "$SRC_NS" ] || [ -z "$DEST_NS" ] || [ -z "$PVC_NAME" ]; then
  echo "❌ Missing required arguments."
  echo "Usage:"
  echo "  ./move-pvc.sh --sourceNamespace=<ns> --destNamespace=<ns> --pvcName=<name>"
  exit 1
fi

echo "📦 Moving PVC '$PVC_NAME'"
echo "   From: $SRC_NS"
echo "   To:   $DEST_NS"
echo ""

# --- Ensure PVC exists ---
if ! oc -n "$SRC_NS" get pvc "$PVC_NAME" >/dev/null 2>&1; then
  echo "❌ PVC '$PVC_NAME' not found in namespace '$SRC_NS'"
  exit 1
fi

# --- Get PV backing the PVC ---
PV=$(oc -n "$SRC_NS" get pvc "$PVC_NAME" -o jsonpath='{.spec.volumeName}')

if [ -z "$PV" ]; then
  echo "❌ PVC '$PVC_NAME' has no bound PV. Cannot proceed."
  exit 1
fi

echo "🔍 Found PV: $PV"

# --- Set reclaimPolicy to Retain ---
echo "🔧 Setting PV reclaim policy to Retain..."
oc patch pv "$PV" -p '{"spec": {"persistentVolumeReclaimPolicy": "Retain"}}' >/dev/null

# --- Get storage class ---
SC=$(oc get pv "$PV" -o jsonpath='{.spec.storageClassName}')
echo "🔍 StorageClass: $SC"

# --- Get PVC size ---
PVC_SIZE=$(oc -n "$SRC_NS" get pvc "$PVC_NAME" -o jsonpath='{.spec.resources.requests.storage}')
echo "🔍 Size: $PVC_SIZE"

# --- Get accessModes ---
ACCESS_MODES=$(oc -n "$SRC_NS" get pvc "$PVC_NAME" -o jsonpath='{.spec.accessModes[*]}')
echo "🔍 Access modes: $ACCESS_MODES"

# --- Delete the PVC (data preserved because PV is Retain) ---
echo "🗑  Deleting PVC '$PVC_NAME' from '$SRC_NS'..."
oc -n "$SRC_NS" delete pvc "$PVC_NAME" --ignore-not-found >/dev/null

# --- Remove claimRef from PV ---
echo "🔧 Removing claimRef from PV '$PV'..."
oc patch pv "$PV" --type json -p '[{"op": "remove", "path": "/spec/claimRef"}]' >/dev/null

# --- Create new PVC in destination namespace ---
NEW_PVC_MANIFEST=$(mktemp)

cat <<EOF > "$NEW_PVC_MANIFEST"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${PVC_NAME}
  namespace: ${DEST_NS}
spec:
  accessModes:
$(for m in $ACCESS_MODES; do echo "  - $m"; done)
  resources:
    requests:
      storage: ${PVC_SIZE}
  storageClassName: ${SC}
  volumeName: ${PV}
EOF

echo "---"
cat $NEW_PVC_MANIFEST
echo "---"
echo "📄 Creating PVC in namespace '$DEST_NS'..."
oc apply -f "$NEW_PVC_MANIFEST" >/dev/null

echo ""
echo "✅ PVC successfully moved!"
echo "   PVC: $PVC_NAME"
echo "   PV:  $PV"
echo "   From: $SRC_NS"
echo "   To:   $DEST_NS"
echo ""
echo "🎉 Completed successfully."


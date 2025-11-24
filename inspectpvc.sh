#!/bin/bash

# ============================================================
# inspectpvc.sh
#
# Usage:
#   ./inspectpvc.sh <PVC_NAME> [-n <namespace>] [--namespace=<ns>]
#
# If no namespace is provided, uses the current oc namespace
# (i.e., no -n flag on oc commands).
# ============================================================

set -e

# --- Default: no namespace specified ---
NAMESPACE=""
NS_FLAG=""

# --- Parse arguments ---
for arg in "$@"; do
  case $arg in
    -n)
      shift
      NAMESPACE="$1"
      shift
      ;;
    --namespace=*)
      NAMESPACE="${arg#*=}"
      shift
      ;;
    *)
      if [ -z "$PVC" ]; then
        PVC="$arg"
      else
        echo "❌ Unknown argument: $arg"
        echo "Usage: $0 <PVC_NAME> [-n <namespace>] [--namespace=<ns>]"
        exit 1
      fi
      ;;
  esac
done

# --- Ensure PVC name is provided ---
if [ -z "$PVC" ]; then
  echo "Usage: $0 <PVC_NAME> [-n <namespace>] [--namespace=<ns>]"
  exit 1
fi

# --- Configure namespace flag ---
if [ -n "$NAMESPACE" ]; then
  NS_FLAG="-n $NAMESPACE"
  echo "🔎 Inspecting PVC: $PVC in namespace: $NAMESPACE"
else
  echo "🔎 Inspecting PVC: $PVC in *current* namespace"
fi
echo ""

# --- Pod name ---
POD="inspect-$PVC"

# --- Start inspection pod ---
oc $NS_FLAG run "$POD" \
  --image=registry.access.redhat.com/ubi9/ubi \
  --restart=Never \
  --overrides='
{
  "apiVersion": "v1",
  "spec": {
    "volumes": [
      { "name": "backup", "persistentVolumeClaim": { "claimName": "'"$PVC"'" } }
    ],
    "containers": [
      {
        "name": "inspect",
        "image": "registry.access.redhat.com/ubi9/ubi",
        "command": ["sleep", "30"],
        "volumeMounts": [ { "name": "backup", "mountPath": "/backups" } ]
      }
    ]
  }
}' >/dev/null

echo "⏳ Waiting for pod to start..."
oc $NS_FLAG wait pod/"$POD" --for=condition=Ready --timeout=20s >/dev/null || {
  echo "❌ Pod failed to become Ready"
  exit 1
}

echo ""
echo "📂 Contents of /backups:"
oc $NS_FLAG exec "$POD" -- ls -l /backups 2>/dev/null || echo "⚠️ Unable to list /backups"
echo ""

# --- Async cleanup ---
echo "🧹 Cleaning up pod $POD (async)..."
oc $NS_FLAG delete pod "$POD" --ignore-not-found >/dev/null &

echo "✔ Done."


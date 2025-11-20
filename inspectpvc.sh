#!/bin/bash

# Ensure a PVC name was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <PVC_NAME>"
  exit 1
fi

PVC="$1"
NAMESPACE="aap"
POD="inspect-$PVC"

echo "🔎 Inspecting PVC: $PVC in namespace: $NAMESPACE"
echo ""

# Run a one-shot pod mounting the PVC
oc -n "$NAMESPACE" run "$POD" \
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
oc -n "$NAMESPACE" wait pod/"$POD" --for=condition=Ready --timeout=20s >/dev/null

echo ""
echo "📂 Contents of /backups on PVC $PVC:"
oc -n "$NAMESPACE" exec "$POD" -- ls -l /backups 2>/dev/null
echo ""

echo "🧹 Cleaning up pod $POD..."
oc -n "$NAMESPACE" delete pod "$POD" --ignore-not-found >/dev/null

echo "✔ Done."

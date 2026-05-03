#!/bin/bash
# =============================================================================
# cleanup_env.sh
# --------------
# Removes all Google Cloud resources created by the "Launch My Kebap" project
# to avoid ongoing charges after the demo.
#
# Deletes:
#   - BigQuery dataset `mcp_kebap` (and all its tables)
#   - Cloud Storage bucket used for CSV staging
#   - The restricted Maps Platform API key
#
# Usage:
#   cd launchmykebap/cleanup
#   bash cleanup_env.sh
# =============================================================================

set -e

PROJECT_ID=$(gcloud config get-value project)
DATASET_NAME="mcp_kebap"
BUCKET_NAME="gs://mcp-kebap-data-$PROJECT_ID"
KEY_DISPLAY_NAME="kebap-agent-maps-key"

echo "================================================================"
echo "  Launch My Kebap – Cleanup"
echo "  Project : $PROJECT_ID"
echo "================================================================"
echo "  WARNING: This will permanently delete:"
echo "    - BigQuery dataset: $DATASET_NAME"
echo "    - Storage bucket  : $BUCKET_NAME"
echo "    - Maps API key    : $KEY_DISPLAY_NAME"
echo ""
read -p "  Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "  Cleanup cancelled."
    exit 0
fi

# ── Delete BigQuery dataset (including all tables) ────────────────────────────
echo "[1/3] Deleting BigQuery dataset '$DATASET_NAME'..."
if bq show "$PROJECT_ID:$DATASET_NAME" >/dev/null 2>&1; then
    bq rm -r -f "$PROJECT_ID:$DATASET_NAME"
    echo "      Dataset deleted."
else
    echo "      Dataset not found — skipping."
fi

# ── Delete Cloud Storage bucket ───────────────────────────────────────────────
echo "[2/3] Deleting Cloud Storage bucket '$BUCKET_NAME'..."
if gcloud storage buckets describe "$BUCKET_NAME" >/dev/null 2>&1; then
    gcloud storage rm -r "$BUCKET_NAME"
    echo "      Bucket deleted."
else
    echo "      Bucket not found — skipping."
fi

# ── Delete Maps API key ───────────────────────────────────────────────────────
echo "[3/3] Deleting Maps API key '$KEY_DISPLAY_NAME'..."
KEY_UID=$(gcloud services api-keys list \
    --filter="displayName=$KEY_DISPLAY_NAME" \
    --format="value(uid)" \
    --project="$PROJECT_ID" | head -1)

if [ -n "$KEY_UID" ]; then
    gcloud services api-keys delete "$KEY_UID" --project="$PROJECT_ID" --quiet
    echo "      API key deleted."
else
    echo "      API key not found — skipping."
fi

echo "================================================================"
echo "  Cleanup complete. All project resources have been removed."
echo "================================================================"

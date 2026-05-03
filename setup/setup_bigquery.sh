#!/bin/bash
# =============================================================================
# setup_bigquery.sh
# -----------------
# Provisions the BigQuery infrastructure for the "Launch My Kebap" project.
#
# This script automates the following steps:
#   1. Creates a Cloud Storage bucket for staging CSV data files.
#   2. Uploads all CSV data files from the ../data/ directory to the bucket.
#   3. Creates the BigQuery dataset `mcp_kebap` in the specified region.
#   4. Creates and populates four tables:
#        - demographics         (district population, income, foot traffic index)
#        - foot_traffic         (time-of-day scores per district)
#        - restaurant_prices    (competitor menu prices across Gaziantep)
#        - sales_history_weekly (weekly revenue & covers for sample restaurants)
#
# Prerequisites:
#   - gcloud CLI authenticated: gcloud auth application-default login
#   - Active Google Cloud project: gcloud config set project [YOUR_PROJECT_ID]
#   - BigQuery API and Cloud Storage API enabled on the project
#
# Usage:
#   bash setup_bigquery.sh [optional-bucket-name]
# =============================================================================

set -e  # Exit immediately on any error

PROJECT_ID=$(gcloud config get-value project)
DATASET_NAME="mcp_kebap"
LOCATION="EU"        # EU region is closer to Turkey than US

# Auto-generate bucket name from project id if none provided
if [ -z "$1" ]; then
    BUCKET_NAME="gs://mcp-kebap-data-$PROJECT_ID"
    echo "No bucket name provided. Using default: $BUCKET_NAME"
else
    BUCKET_NAME=$1
fi

echo "================================================================"
echo "  Launch My Kebap – BigQuery Setup"
echo "  Project : $PROJECT_ID"
echo "  Dataset : $DATASET_NAME"
echo "  Bucket  : $BUCKET_NAME"
echo "  Location: $LOCATION"
echo "================================================================"

# ── Step 1: Create Cloud Storage bucket (if it does not already exist) ──────
echo "[1/6] Checking Cloud Storage bucket..."
if gcloud storage buckets describe "$BUCKET_NAME" >/dev/null 2>&1; then
    echo "      Bucket already exists — skipping creation."
else
    echo "      Creating bucket $BUCKET_NAME in location $LOCATION..."
    gcloud storage buckets create "$BUCKET_NAME" --location="$LOCATION"
fi

# ── Step 2: Upload CSV data files ────────────────────────────────────────────
echo "[2/6] Uploading CSV data files to $BUCKET_NAME..."
gcloud storage cp ../data/*.csv "$BUCKET_NAME"

# ── Step 3: Create BigQuery dataset ─────────────────────────────────────────
echo "[3/6] Creating BigQuery dataset '$DATASET_NAME'..."
if bq show "$PROJECT_ID:$DATASET_NAME" >/dev/null 2>&1; then
    echo "      Dataset already exists — skipping creation."
else
    bq mk --location="$LOCATION" --dataset \
        --description "Gaziantep restaurant market intelligence data for the Launch My Kebap agent." \
        "$PROJECT_ID:$DATASET_NAME"
    echo "      Dataset created."
fi

# ── Step 4: Create & load demographics table ─────────────────────────────────
echo "[4/6] Setting up table: demographics..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.demographics\` (
    district_code             STRING  OPTIONS(description='Unique district code for Gaziantep (27xx)'),
    city                      STRING  OPTIONS(description='City name — always Gaziantep for this dataset'),
    neighborhood              STRING  OPTIONS(description='Common neighborhood or district name'),
    median_household_income_tl FLOAT64 OPTIONS(description='Median annual household income in Turkish Lira'),
    total_population          INT64   OPTIONS(description='Total residential population of the district'),
    median_age                FLOAT64 OPTIONS(description='Median age of district residents'),
    university_degree_pct     FLOAT64 OPTIONS(description='Percentage of adults with a university degree'),
    foot_traffic_index        FLOAT64 OPTIONS(description='Composite foot-traffic index (0–100) based on commercial density and mobility data')
)
OPTIONS(
    description='District-level demographic and foot-traffic summary data for Gaziantep, Turkey.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.demographics" "$BUCKET_NAME/demographics.csv"
echo "      demographics table ready."

# ── Step 5: Create & load foot_traffic table ─────────────────────────────────
echo "[5/6] Setting up table: foot_traffic..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.foot_traffic\` (
    district_code     STRING  OPTIONS(description='District code matching the demographics table'),
    time_of_day       STRING  OPTIONS(description='Time segment: sabah (morning), ogle (lunch), aksam (evening)'),
    foot_traffic_score FLOAT64 OPTIONS(description='Foot traffic score for this district and time slot (0–100)')
)
OPTIONS(
    description='Hourly foot-traffic scores per Gaziantep district, split by morning / lunch / evening.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --replace \
    "$PROJECT_ID:$DATASET_NAME.foot_traffic" "$BUCKET_NAME/foot_traffic.csv"
echo "      foot_traffic table ready."

# ── Step 6: Create & load restaurant_prices table ────────────────────────────
echo "[6/8] Setting up table: restaurant_prices..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.restaurant_prices\` (
    restaurant_name STRING  OPTIONS(description='Name of the competitor restaurant'),
    menu_item       STRING  OPTIONS(description='Menu item name, e.g. Beyti Kebap, Lahmacun, Katmer'),
    price_tl        FLOAT64 OPTIONS(description='Menu item price in Turkish Lira'),
    district        STRING  OPTIONS(description='Gaziantep district where the restaurant operates'),
    cuisine_type    STRING  OPTIONS(description='Cuisine category — all are Gaziantep Mutfağı in this dataset'),
    is_premium      BOOL    OPTIONS(description='True if the restaurant targets the premium/upscale segment')
)
OPTIONS(
    description='Competitor restaurant pricing data for common Gaziantep menu items across city districts.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --replace \
    "$PROJECT_ID:$DATASET_NAME.restaurant_prices" "$BUCKET_NAME/restaurant_prices.csv"
echo "      restaurant_prices table ready."

# ── Step 7: Create & load sales_history_weekly table ─────────────────────────
echo "[7/8] Setting up table: sales_history_weekly..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.sales_history_weekly\` (
    week_start_date   DATE    OPTIONS(description='Monday of the sales week (ISO date)'),
    restaurant_location STRING OPTIONS(description='Gaziantep district of the restaurant'),
    menu_item         STRING  OPTIONS(description='Menu item sold that week'),
    covers_served     INT64   OPTIONS(description='Number of individual portions sold during the week'),
    total_revenue_tl  FLOAT64 OPTIONS(description='Total revenue in Turkish Lira for this item that week')
)
OPTIONS(
    description='Weekly sales performance data for representative Gaziantep restaurants, by district and menu item.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --replace \
    "$PROJECT_ID:$DATASET_NAME.sales_history_weekly" "$BUCKET_NAME/sales_history_weekly.csv"
echo "      sales_history_weekly table ready."

echo "================================================================"
echo "  Setup Complete!"
echo "  BigQuery dataset: $PROJECT_ID:$DATASET_NAME"
echo "  Tables: demographics, foot_traffic, restaurant_prices,"
echo "          sales_history_weekly"
echo "================================================================"

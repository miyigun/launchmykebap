# 🥩 Launch My Kebap – Gaziantep Restaurant Market Intelligence Agent

> **"Gaziantep'te kebap restoranı açmak için en iyi lokasyon neresi?"**
>
> An AI-powered market intelligence agent that answers this question by combining
> enterprise data in BigQuery with real-world geospatial context from Google Maps —
> all orchestrated through the **Model Context Protocol (MCP)** and Google's
> **Agent Development Kit (ADK)**.

---

## Project Overview

This project is a location-intelligence agent for entrepreneurs wanting to launch
a kebap or Gaziantep-cuisine restaurant in **Gaziantep, Turkey** — one of the
world's great culinary cities and a UNESCO Creative City of Gastronomy.

It is structurally identical to Google's `launchmybakery` demo (ADK + MCP +
BigQuery + Maps) but adapted for the local Gaziantep market and the kebap
restaurant sector, as outlined in the course assignment (`Ödev.docx`).

### What the agent can do

| Business Question | Data Source |
|---|---|
| Which district has the highest lunch foot traffic? | BigQuery `foot_traffic` |
| What is the average price for Beyti Kebap in İncilipınar? | BigQuery `restaurant_prices` |
| How many premium competitors are within 500 m of a target address? | Google Maps MCP |
| What weekly revenue can a 40-seat restaurant expect in Şehitkamil? | BigQuery `sales_history_weekly` |
| Is there parking near the shortlisted location? | Google Maps MCP |

---

## Architecture

```
User (Turkish or English)
       │
       ▼
  ADK LlmAgent  ──  Gemini 3.1 Pro
       │
  ┌────┴──────────────┐
  ▼                   ▼
BigQuery MCP       Google Maps MCP
(Google-hosted)    (Google-hosted)
  │                   │
  ▼                   ▼
mcp_kebap dataset  Maps Platform APIs
  ├─ demographics    ├─ places_search_text
  ├─ foot_traffic    ├─ place_details
  ├─ restaurant_prices├─ routes_compute
  └─ sales_history_weekly└─ geocode
```

**Key architectural principle:** Reasoning happens in the agent (Gemini).
Execution happens in BigQuery and Maps. MCP sits cleanly in between — no
custom API wrappers needed.

---

## Project Structure

```
launchmykebap/
├── data/                          # Pre-generated CSV files for BigQuery
│   ├── demographics.csv           # District population, income, foot-traffic index
│   ├── foot_traffic.csv           # Time-of-day scores (morning/lunch/evening)
│   ├── restaurant_prices.csv      # Competitor menu prices across Gaziantep
│   └── sales_history_weekly.csv   # Weekly revenue & covers for sample restaurants
│
├── adk_agent/                     # ADK Agent Application
│   └── mcp_kebap_app/
│       ├── __init__.py            # Package marker
│       ├── agent.py               # Root LlmAgent definition and system prompt
│       └── tools.py               # MCP toolset initializers (Maps + BigQuery)
│
├── setup/
│   ├── setup_env.sh               # Enables APIs, creates Maps key, writes .env
│   └── setup_bigquery.sh          # Creates dataset, tables, loads CSV data
│
├── cleanup/
│   └── cleanup_env.sh             # Deletes all cloud resources
│
├── requirements.txt               # Python dependencies
└── README.md                      # This file
```

---

## Dataset Description

### `demographics`
District-level demographic summary for 25 Gaziantep neighbourhoods.

| Column | Type | Description |
|---|---|---|
| `district_code` | STRING | Unique district code (27xx) |
| `city` | STRING | Always "Gaziantep" |
| `neighborhood` | STRING | District name |
| `median_household_income_tl` | FLOAT64 | Median annual household income (₺) |
| `total_population` | INT64 | Residential population |
| `median_age` | FLOAT64 | Median resident age |
| `university_degree_pct` | FLOAT64 | % adults with university degree |
| `foot_traffic_index` | FLOAT64 | Composite foot-traffic index (0–100) |

### `foot_traffic`
Time-of-day foot traffic granularity per district.

| Column | Type | Description |
|---|---|---|
| `district_code` | STRING | Joins to `demographics` |
| `time_of_day` | STRING | `sabah` / `ogle` / `aksam` |
| `foot_traffic_score` | FLOAT64 | Score 0–100 for this slot |

### `restaurant_prices`
Competitor pricing for key Gaziantep menu items.

| Column | Type | Description |
|---|---|---|
| `restaurant_name` | STRING | Competitor name |
| `menu_item` | STRING | Beyti Kebap, Fıstıklı Kebap, Ali Nazik, Lahmacun, Katmer |
| `price_tl` | FLOAT64 | Price in Turkish Lira |
| `district` | STRING | Restaurant district |
| `cuisine_type` | STRING | Always "Gaziantep Mutfağı" |
| `is_premium` | BOOL | Premium/upscale positioning flag |

### `sales_history_weekly`
Weekly performance data for representative restaurants.

| Column | Type | Description |
|---|---|---|
| `week_start_date` | DATE | Monday of the sales week |
| `restaurant_location` | STRING | District of the restaurant |
| `menu_item` | STRING | Menu item category |
| `covers_served` | INT64 | Portions sold that week |
| `total_revenue_tl` | FLOAT64 | Revenue in Turkish Lira |

---

## Quick Start

### Prerequisites
- Google Cloud project with billing enabled
- `gcloud` CLI installed and authenticated
- Python 3.11+ with `pip`

### 1. Clone and Navigate
```bash
git clone https://github.com/<your-org>/launchmykebap.git
cd launchmykebap
```

### 2. Authenticate
```bash
gcloud config set project [YOUR_PROJECT_ID]
gcloud auth application-default login
```

### 3. Set Up Environment
```bash
cd setup
chmod +x setup_env.sh
./setup_env.sh
```

### 4. Load Data into BigQuery
```bash
chmod +x setup_bigquery.sh
./setup_bigquery.sh
cd ..
```

### 5. Install Python Dependencies
```bash
cd adk_agent
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r ../requirements.txt
```

### 6. Run the Agent
```bash
# Web UI (recommended)
adk web mcp_kebap_app

# Or CLI mode
adk run mcp_kebap_app
```

---

## Example Queries

Try these prompts in the ADK web UI:

**Turkish:**
```
Gaziantep'te öğle saatlerinde en yoğun nüfus trafiğine sahip ilçe hangisi?
Oraya 500 metre yakınında kaç premium kebap restoranı var?
```

```
Şehitkamil Merkez'de Beyti Kebap için rakip fiyat ortalaması nedir?
Premium bir konumlandırma için ne kadar fiyat önerirsin?
```

```
İncilipınar'da 40 kişilik bir restoran için haftalık gelir tahmini nedir?
```

**English:**
```
Which Gaziantep district has the highest lunch foot traffic and the fewest
premium competitors within 500 metres?
```

```
Compare average Beyti Kebap prices between İncilipınar and Gazikent.
Which district offers better margin potential for a new premium restaurant?
```

---

## Extending the Project

Following the course roadmap (`Ödev.docx`), this project can be extended to:

1. **Streamlit Deployment** – wrap the agent in a Streamlit app for a polished UI
   and deploy to Google Cloud Run or Streamlit Community Cloud.

2. **Medium Article** – document the architecture, data design decisions, and
   sample agent conversations for publication.

3. **LinkedIn Post** – share the project with attribution to the training programme.

4. **Additional Data Sources** – enrich with TÜİK (Turkish Statistical Institute)
   open data, Gaziantep municipality datasets, or Google Places reviews.

---

## Cleanup

To remove all cloud resources and avoid ongoing charges:
```bash
cd cleanup
chmod +x cleanup_env.sh
./cleanup_env.sh
```

---

## License
Apache 2.0 — see `LICENSE` for details.

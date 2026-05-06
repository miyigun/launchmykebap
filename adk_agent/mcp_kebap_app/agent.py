"""
agent.py
--------
Defines the root ADK (Agent Development Kit) agent for the
"Launch My Kebap" – Gaziantep Restaurant Market Intelligence project.

The agent is powered by Gemini and equipped with two MCP toolsets:
  - BigQuery MCP  : Queries structured market data (demographics, competitor
                    pricing, sales history, foot traffic) from the
                    `mcp_kebap` BigQuery dataset.
  - Google Maps MCP: Performs real-world location analysis — finding existing
                     kebap/restaurant competitors, calculating walking/driving
                     distances, and returning interactive map links.

Together these capabilities allow the agent to answer business questions such as:
  "Which Gaziantep district has the highest lunch foot traffic and fewest
   premium kebap competitors within 500 metres?"
  "What is the average price for Beyti Kebap in İncilipınar, and how does it
   compare to premium restaurants in Gazikent?"
  "Predict weekly revenue for a new 40-seat restaurant in Şehitkamil Merkez
   based on comparable venues."

Architecture:
  User ──▶ ADK LlmAgent (Gemini)
                 │
         ┌───────┴────────┐
         ▼                ▼
    BigQuery MCP       Maps MCP
    (structured data)  (geospatial)
         │                │
    mcp_kebap dataset   Google Maps Platform
"""

import os
import dotenv
from mcp_kebap_app import tools
from google.adk.agents import LlmAgent

# Load environment variables from the .env file created by setup_env.sh
dotenv.load_dotenv()

# Hardcoded Gemini API Key (Bypasses Vertex AI and .env)
os.environ["GEMINI_API_KEY"] = "AIzaSyDJzVITF9uRpA9YF-6ZA2mZdQzpF0oHV8E"

# Google Cloud project ID used to run BigQuery jobs (must match the dataset location)
PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT", "project_not_set")

# ---------------------------------------------------------------------------
# Initialize MCP Toolsets
# ---------------------------------------------------------------------------
# Maps toolset: location intelligence, competitor search, routing
maps_toolset = tools.get_maps_mcp_toolset()

# BigQuery toolset: market data queries against the mcp_kebap dataset
bigquery_toolset = tools.get_bigquery_mcp_toolset()

# ---------------------------------------------------------------------------
# Root Agent Definition
# ---------------------------------------------------------------------------
root_agent = LlmAgent(
    # Model: Gemini 3.1 Pro provides strong reasoning for multi-step market analysis
    model="gemini-3.1-pro-preview",

    # Unique agent identifier (used by ADK runtime for logging and routing)
    name="kebap_market_intelligence_agent",

    # System instruction: defines the agent's role, data sources, and behaviour
    instruction=f"""
        Sen Gaziantep'te yeni bir kebap/yöresel restoran açmak isteyen girişimcilere
        yardım eden bir pazar analizi uzmanısın. İngilizce veya Türkçe sorulara yanıt verebilirsin.

        You are a market intelligence assistant helping entrepreneurs evaluate locations
        for launching a new kebap or Gaziantep-cuisine restaurant in Gaziantep, Turkey.

        Answer user questions by strategically combining insights from two data sources:

        1. **BigQuery Toolset** – Access the `mcp_kebap` dataset in project {PROJECT_ID}.
           Available tables:
           - `demographics`        : District population, median income, education levels
                                     and an overall foot_traffic_index per district.
           - `foot_traffic`        : Granular foot-traffic scores split by time of day
                                     (sabah/morning, ogle/lunch, aksam/evening).
           - `restaurant_prices`   : Competitor menu prices (Beyti Kebap, Fıstıklı Kebap,
                                     Ali Nazik, Lahmacun, Katmer) per district.
                                     The `is_premium` flag indicates upscale positioning.
           - `sales_history_weekly`: Historical weekly covers served and revenue (TL) for
                                     representative restaurants across key districts.
           Do NOT query any dataset other than `mcp_kebap`.
           Always run query jobs under project id: {PROJECT_ID}.

        2. **Maps Toolset** – Use for real-world geospatial analysis:
           - Search for existing kebap restaurants and competitors near a target district.
           - Retrieve ratings, opening hours, and addresses of specific venues.
           - Calculate walking/driving distances between candidate locations.
           - Include a hyperlink to an interactive Google Maps view in responses
             whenever a location is discussed.

        ## Analysis Framework
        When asked to evaluate a potential restaurant location, follow this reasoning chain:

        **Step 1 – Macro Discovery**
        Query `foot_traffic` and `demographics` to identify districts with:
          - High lunch (öğle) foot traffic scores (> 65)
          - Population density that supports restaurant volume
          - Median income aligned with the target price segment

        **Step 2 – Competitive Landscape**
        Query `restaurant_prices` to understand competitor density and pricing.
        Use Maps to search for actual kebap restaurants in short-listed districts and
        assess how saturated the market is within a 500 m radius.

        **Step 3 – Pricing Strategy**
        Compare competitor prices for key menu items (Beyti Kebap, Fıstıklı Kebap).
        Recommend a price point that balances competitiveness and margin.
        Flag whether a premium (is_premium=True) or value positioning is appropriate.

        **Step 4 – Revenue Forecast**
        Query `sales_history_weekly` to find comparable venues in similar districts.
        Extrapolate weekly revenue estimates for a new venue of the specified seat count.

        **Step 5 – Location Validation**
        Use Maps to confirm the shortlisted street or area:
          - Verify nearby landmarks (mosques, bazaars, shopping centres, universities)
            that drive foot traffic.
          - Check parking or transit accessibility.
          - Provide an interactive map link for the recommended location.

        ## Output Style
        - Respond in the same language the user uses (Turkish or English).
        - Always include concrete numbers from BigQuery queries (do not guess).
        - Include a Google Maps link whenever discussing a specific location.
        - End each analysis with a concise "Öneri / Recommendation" summary box.
    """,

    # Equip the agent with both toolsets
    tools=[maps_toolset, bigquery_toolset],
)

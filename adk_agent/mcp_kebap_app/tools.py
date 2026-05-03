"""
tools.py
--------
Initializes and returns MCP (Model Context Protocol) toolsets for the
Gaziantep Kebap Market Intelligence Agent.

Two toolsets are configured:
  1. Google Maps MCP  – real-world location search, competitor discovery,
                        distance/route calculations, and place details.
  2. Google BigQuery MCP – structured data access for demographics, foot
                            traffic, restaurant pricing, and weekly sales.

Both toolsets use Streamable HTTP connections to Google's hosted MCP servers,
which means no custom API wrappers are needed. The ADK agent discovers and
calls the tools automatically at inference time.
"""

import os
import dotenv
import google.auth
import google.auth.transport.requests
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StreamableHTTPConnectionParams

# ---------------------------------------------------------------------------
# Remote MCP server endpoints (Google-managed, zero-ops)
# ---------------------------------------------------------------------------
MAPS_MCP_URL = "https://mapstools.googleapis.com/mcp"
BIGQUERY_MCP_URL = "https://bigquery.googleapis.com/mcp"


def get_maps_mcp_toolset() -> MCPToolset:
    """
    Builds and returns an MCPToolset connected to the Google Maps MCP server.

    Authentication is performed via a restricted API key loaded from the
    environment variable MAPS_API_KEY (set by setup_env.sh).

    The toolset provides tools such as:
      - places_search_text  : Find restaurants/competitors by keyword & location
      - place_details        : Get full details (rating, hours, address) for a place
      - routes_compute       : Calculate travel distances and ETAs
      - geocode              : Convert addresses to coordinates

    Returns:
        MCPToolset configured for the Maps MCP endpoint.
    """
    dotenv.load_dotenv()
    maps_api_key = os.getenv("MAPS_API_KEY", "no_api_key_found")

    toolset = MCPToolset(
        connection_params=StreamableHTTPConnectionParams(
            url=MAPS_MCP_URL,
            headers={"X-Goog-Api-Key": maps_api_key},
            timeout=30.0,           # Connection timeout in seconds
            sse_read_timeout=300.0  # Max time to wait for streaming responses
        )
    )
    print("[tools] Maps MCP Toolset initialized via Streamable HTTP.")
    return toolset


def get_bigquery_mcp_toolset() -> MCPToolset:
    """
    Builds and returns an MCPToolset connected to the Google BigQuery MCP server.

    Authentication uses Application Default Credentials (ADC) with the
    BigQuery OAuth scope, so the calling identity must have at least
    roles/bigquery.dataViewer and roles/bigquery.jobUser on the project.

    The toolset exposes tools such as:
      - list_datasets        : Enumerate available BigQuery datasets
      - list_tables          : List tables within a dataset
      - get_table_info       : Inspect schema and metadata for a table
      - execute_sql          : Run a SQL query and retrieve results

    The agent uses these tools to query the `mcp_kebap` dataset which contains:
      - demographics         : District-level population and income data for Gaziantep
      - foot_traffic         : Time-of-day foot traffic scores per district
      - restaurant_prices    : Competitor menu prices across Gaziantep districts
      - sales_history_weekly : Historical weekly revenue and covers for sample restaurants

    Returns:
        MCPToolset configured for the BigQuery MCP endpoint.
    """
    # Obtain fresh Application Default Credentials scoped to BigQuery
    credentials, project_id = google.auth.default(
        scopes=["https://www.googleapis.com/auth/bigquery"]
    )
    # Refresh the token so it is valid for the current session
    credentials.refresh(google.auth.transport.requests.Request())
    oauth_token = credentials.token

    headers_with_oauth = {
        "Authorization": f"Bearer {oauth_token}",
        "x-goog-user-project": project_id,  # Billing project for BigQuery jobs
    }

    toolset = MCPToolset(
        connection_params=StreamableHTTPConnectionParams(
            url=BIGQUERY_MCP_URL,
            headers=headers_with_oauth,
            timeout=30.0,
            sse_read_timeout=300.0
        )
    )
    print("[tools] BigQuery MCP Toolset initialized via Streamable HTTP.")
    return toolset

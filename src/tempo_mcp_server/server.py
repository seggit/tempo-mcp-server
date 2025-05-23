#!/usr/bin/env python3
"""
Tempo MCP Server

A Model Context Protocol server that provides integration with Tempo Cloud API
for worklog management, time tracking, and productivity analytics.
"""

import asyncio
import logging
import os
import sys
from datetime import datetime, date, timedelta
from typing import Any, Dict, List, Optional, Union
from urllib.parse import urljoin

import httpx
from dotenv import load_dotenv
from pydantic import BaseModel, Field, ValidationError

import mcp.server.stdio
import mcp.types as types
from mcp.server import NotificationOptions, Server
from mcp.server.models import InitializationOptions

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.DEBUG if os.getenv("TEMPO_DEBUG") else logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("tempo-mcp-server")

# Configuration
TEMPO_API_TOKEN = os.getenv("TEMPO_API_TOKEN")
TEMPO_BASE_URL = os.getenv("TEMPO_BASE_URL", "https://api.tempo.io/4")
RATE_LIMIT_DELAY = 0.2  # 5 requests per second = 0.2 seconds between requests

if not TEMPO_API_TOKEN:
    logger.error("TEMPO_API_TOKEN environment variable is required")
    sys.exit(1)


# Pydantic Models for data validation
class TempoWorklog(BaseModel):
    """Represents a Tempo worklog entry"""
    tempoWorklogId: Optional[int] = None
    issue: Dict[str, Any]
    timeSpentSeconds: int
    billableSeconds: Optional[int] = None
    startDate: str
    startTime: Optional[str] = None
    description: str
    createdAt: Optional[str] = None
    updatedAt: Optional[str] = None
    author: Dict[str, Any]
    attributes: Optional[Dict[str, Any]] = None


class TempoAccount(BaseModel):
    """Represents a Tempo account"""
    self: str
    key: str
    name: str
    status: str
    global_: Optional[bool] = Field(None, alias="global")
    


class TempoWorkAttribute(BaseModel):
    """Represents a Tempo work attribute"""
    key: str
    name: str
    type: str
    required: bool
    values: Optional[List[str]] = None


class TempoApiClient:
    """HTTP client for Tempo Cloud API v4.0"""
    
    def __init__(self, api_token: str, base_url: str = TEMPO_BASE_URL):
        self.api_token = api_token
        self.base_url = base_url
        self.session = httpx.AsyncClient(
            headers={
                "Authorization": f"Bearer {api_token}",
                "Content-Type": "application/json",
                "Accept": "application/json"
            },
            timeout=30.0
        )
        self.last_request_time = 0.0
        
    async def _make_request(
        self, 
        method: str, 
        endpoint: str, 
        params: Optional[Dict] = None,
        json_data: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """Make rate-limited HTTP request to Tempo API"""
        
        # Respect rate limiting (5 requests per second)
        current_time = asyncio.get_event_loop().time()
        time_since_last = current_time - self.last_request_time
        if time_since_last < RATE_LIMIT_DELAY:
            await asyncio.sleep(RATE_LIMIT_DELAY - time_since_last)
        
        url = urljoin(self.base_url + "/", endpoint.lstrip("/"))
        
        try:
            logger.debug(f"Making {method} request to {url} with params: {params}")
            
            if method.upper() == "GET":
                response = await self.session.get(url, params=params)
            elif method.upper() == "POST":
                response = await self.session.post(url, params=params, json=json_data)
            elif method.upper() == "PUT":
                response = await self.session.put(url, params=params, json=json_data)
            elif method.upper() == "DELETE":
                response = await self.session.delete(url, params=params)
            else:
                raise ValueError(f"Unsupported HTTP method: {method}")
            
            self.last_request_time = asyncio.get_event_loop().time()
            
            response.raise_for_status()
            return response.json() if response.content else {}
            
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error {e.response.status_code}: {e.response.text}")
            error_detail = f"HTTP {e.response.status_code}: {e.response.text}"
            if e.response.status_code == 401:
                error_detail = "Authentication failed. Please check your API token."
            elif e.response.status_code == 403:
                error_detail = "Access forbidden. Check your API token permissions."
            elif e.response.status_code == 429:
                error_detail = "Rate limit exceeded. Please try again later."
            raise Exception(error_detail)
        except Exception as e:
            logger.error(f"Request failed: {e}")
            raise Exception(f"API request failed: {str(e)}")
    
    async def get_worklogs(
        self,
        from_date: Optional[str] = None,
        to_date: Optional[str] = None,
        project_id: Optional[int] = None,
        issue_id: Optional[int] = None,
        account_id: Optional[str] = None,
        limit: int = 50,
        offset: int = 0
    ) -> Dict[str, Any]:
        """Get worklogs with optional filters"""
        params = {"limit": limit, "offset": offset}
        
        if from_date:
            params["from"] = from_date
        if to_date:
            params["to"] = to_date
        if project_id:
            params["project"] = project_id
        if issue_id:
            params["issue"] = issue_id
        if account_id:
            params["accountId"] = account_id
            
        return await self._make_request("GET", "worklogs", params=params)
    
    async def create_worklog(
        self,
        issue_id: int,
        time_spent_seconds: int,
        start_date: str,
        description: str,
        start_time: Optional[str] = None,
        billable_seconds: Optional[int] = None,
        attributes: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Create a new worklog"""
        data = {
            "issueId": issue_id,
            "timeSpentSeconds": time_spent_seconds,
            "startDate": start_date,
            "description": description
        }
        
        if start_time:
            data["startTime"] = start_time
        if billable_seconds is not None:
            data["billableSeconds"] = billable_seconds
        if attributes:
            data["attributes"] = attributes
            
        return await self._make_request("POST", "worklogs", json_data=data)
    
    async def update_worklog(
        self,
        worklog_id: int,
        time_spent_seconds: Optional[int] = None,
        description: Optional[str] = None,
        start_date: Optional[str] = None,
        start_time: Optional[str] = None,
        billable_seconds: Optional[int] = None
    ) -> Dict[str, Any]:
        """Update an existing worklog"""
        data = {}
        
        if time_spent_seconds is not None:
            data["timeSpentSeconds"] = time_spent_seconds
        if description is not None:
            data["description"] = description
        if start_date is not None:
            data["startDate"] = start_date
        if start_time is not None:
            data["startTime"] = start_time
        if billable_seconds is not None:
            data["billableSeconds"] = billable_seconds
            
        return await self._make_request("PUT", f"worklogs/{worklog_id}", json_data=data)
    
    async def delete_worklog(self, worklog_id: int) -> Dict[str, Any]:
        """Delete a worklog"""
        return await self._make_request("DELETE", f"worklogs/{worklog_id}")
    
    async def get_accounts(self) -> Dict[str, Any]:
        """Get all available accounts"""
        return await self._make_request("GET", "accounts")
    
    async def get_work_attributes(self) -> Dict[str, Any]:
        """Get all work attributes"""
        return await self._make_request("GET", "work-attributes")
    
    async def close(self):
        """Close the HTTP client"""
        await self.session.aclose()


# Global client instance
tempo_client: Optional[TempoApiClient] = None


def format_duration(seconds: int) -> str:
    """Format seconds into human-readable duration"""
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    if hours > 0:
        return f"{hours}h {minutes}m"
    else:
        return f"{minutes}m"


def parse_duration(duration_str: str) -> int:
    """Parse duration string (e.g., '2h 30m', '1.5h', '90m') into seconds"""
    duration_str = duration_str.lower().strip()
    
    # Handle decimal hours (e.g., '1.5h')
    if 'h' in duration_str and 'm' not in duration_str:
        try:
            hours = float(duration_str.replace('h', '').strip())
            return int(hours * 3600)
        except ValueError:
            pass
    
    # Handle combined format (e.g., '2h 30m')
    total_seconds = 0
    parts = duration_str.replace(',', ' ').split()
    
    for part in parts:
        if 'h' in part:
            hours = float(part.replace('h', ''))
            total_seconds += int(hours * 3600)
        elif 'm' in part:
            minutes = float(part.replace('m', ''))
            total_seconds += int(minutes * 60)
        elif part.isdigit():
            # Assume minutes if no unit specified
            total_seconds += int(part) * 60
    
    return total_seconds if total_seconds > 0 else 3600  # Default to 1 hour


# Create the MCP server
server = Server("tempo-mcp-server")


@server.list_tools()
async def handle_list_tools() -> List[types.Tool]:
    """List all available tools for Tempo operations"""
    return [
        types.Tool(
            name="get_worklogs",
            description="Retrieve worklogs by date range, project, issue, or user",
            inputSchema={
                "type": "object",
                "properties": {
                    "from_date": {
                        "type": "string",
                        "description": "Start date (YYYY-MM-DD format)"
                    },
                    "to_date": {
                        "type": "string", 
                        "description": "End date (YYYY-MM-DD format)"
                    },
                    "project_id": {
                        "type": "integer",
                        "description": "Jira project ID to filter by"
                    },
                    "issue_id": {
                        "type": "integer",
                        "description": "Jira issue ID to filter by"
                    },
                    "account_id": {
                        "type": "string",
                        "description": "User account ID to filter by"
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of results (default: 50, max: 1000)",
                        "default": 50
                    }
                }
            }
        ),
        types.Tool(
            name="create_worklog",
            description="Create a new worklog entry",
            inputSchema={
                "type": "object",
                "properties": {
                    "issue_id": {
                        "type": "integer",
                        "description": "Jira issue ID",
                        "required": True
                    },
                    "time_spent": {
                        "type": "string",
                        "description": "Time spent (e.g., '2h 30m', '1.5h', '90m')",
                        "required": True
                    },
                    "description": {
                        "type": "string",
                        "description": "Work description",
                        "required": True
                    },
                    "start_date": {
                        "type": "string",
                        "description": "Work date (YYYY-MM-DD format, defaults to today)"
                    },
                    "start_time": {
                        "type": "string",
                        "description": "Start time (HH:MM format)"
                    },
                    "billable": {
                        "type": "boolean",
                        "description": "Whether the time is billable (defaults to same as time_spent)"
                    }
                },
                "required": ["issue_id", "time_spent", "description"]
            }
        ),
        types.Tool(
            name="update_worklog",
            description="Update an existing worklog",
            inputSchema={
                "type": "object",
                "properties": {
                    "worklog_id": {
                        "type": "integer",
                        "description": "Tempo worklog ID",
                        "required": True
                    },
                    "time_spent": {
                        "type": "string",
                        "description": "New time spent (e.g., '2h 30m')"
                    },
                    "description": {
                        "type": "string",
                        "description": "New work description"
                    },
                    "start_date": {
                        "type": "string",
                        "description": "New work date (YYYY-MM-DD format)"
                    },
                    "start_time": {
                        "type": "string",
                        "description": "New start time (HH:MM format)"
                    }
                },
                "required": ["worklog_id"]
            }
        ),
        types.Tool(
            name="delete_worklog",
            description="Delete a worklog entry",
            inputSchema={
                "type": "object",
                "properties": {
                    "worklog_id": {
                        "type": "integer",
                        "description": "Tempo worklog ID to delete",
                        "required": True
                    }
                },
                "required": ["worklog_id"]
            }
        ),
        types.Tool(
            name="get_accounts",
            description="List all available Tempo accounts",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        types.Tool(
            name="get_work_attributes",
            description="List all work attributes and their possible values",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        types.Tool(
            name="get_today_summary",
            description="Get a summary of today's time tracking",
            inputSchema={
                "type": "object",
                "properties": {
                    "account_id": {
                        "type": "string",
                        "description": "User account ID (optional, defaults to current user)"
                    }
                }
            }
        )
    ]


@server.call_tool()
async def handle_call_tool(name: str, arguments: Dict[str, Any]) -> List[types.TextContent]:
    """Handle tool calls for Tempo operations"""
    global tempo_client
    
    if not tempo_client:
        tempo_client = TempoApiClient(TEMPO_API_TOKEN, TEMPO_BASE_URL)
    
    try:
        if name == "get_worklogs":
            result = await tempo_client.get_worklogs(
                from_date=arguments.get("from_date"),
                to_date=arguments.get("to_date"),
                project_id=arguments.get("project_id"),
                issue_id=arguments.get("issue_id"),
                account_id=arguments.get("account_id"),
                limit=arguments.get("limit", 50)
            )
            
            # Format the response
            worklogs = result.get("results", [])
            if not worklogs:
                return [types.TextContent(type="text", text="No worklogs found for the specified criteria.")]
            
            response = f"Found {len(worklogs)} worklog(s):\n\n"
            total_seconds = 0
            
            for worklog in worklogs:
                time_spent = format_duration(worklog["timeSpentSeconds"])
                total_seconds += worklog["timeSpentSeconds"]
                
                issue_key = worklog["issue"].get("key", "Unknown")
                author_name = worklog["author"].get("displayName", "Unknown")
                
                response += f"• **{issue_key}** - {time_spent}\n"
                response += f"  📝 {worklog['description']}\n"
                response += f"  👤 {author_name} on {worklog['startDate']}\n"
                if worklog.get("startTime"):
                    response += f"  🕐 Started at {worklog['startTime']}\n"
                response += "\n"
            
            total_time = format_duration(total_seconds)
            response += f"**Total time logged: {total_time}**"
            
            return [types.TextContent(type="text", text=response)]
        
        elif name == "create_worklog":
            # Parse time spent
            time_spent_seconds = parse_duration(arguments["time_spent"])
            billable_seconds = time_spent_seconds if arguments.get("billable", True) else 0
            
            # Default to today if no start date provided
            start_date = arguments.get("start_date", date.today().isoformat())
            
            result = await tempo_client.create_worklog(
                issue_id=arguments["issue_id"],
                time_spent_seconds=time_spent_seconds,
                start_date=start_date,
                description=arguments["description"],
                start_time=arguments.get("start_time"),
                billable_seconds=billable_seconds
            )
            
            time_formatted = format_duration(time_spent_seconds)
            response = f"✅ **Worklog created successfully!**\n\n"
            response += f"📋 **Issue:** {result.get('issue', {}).get('key', 'Unknown')}\n"
            response += f"⏱️ **Time logged:** {time_formatted}\n"
            response += f"📝 **Description:** {arguments['description']}\n"
            response += f"📅 **Date:** {start_date}\n"
            if arguments.get("start_time"):
                response += f"🕐 **Start time:** {arguments['start_time']}\n"
            response += f"🆔 **Worklog ID:** {result.get('tempoWorklogId')}"
            
            return [types.TextContent(type="text", text=response)]
        
        elif name == "update_worklog":
            worklog_id = arguments["worklog_id"]
            
            # Parse time spent if provided
            time_spent_seconds = None
            if arguments.get("time_spent"):
                time_spent_seconds = parse_duration(arguments["time_spent"])
            
            result = await tempo_client.update_worklog(
                worklog_id=worklog_id,
                time_spent_seconds=time_spent_seconds,
                description=arguments.get("description"),
                start_date=arguments.get("start_date"),
                start_time=arguments.get("start_time")
            )
            
            response = f"✅ **Worklog {worklog_id} updated successfully!**\n\n"
            if time_spent_seconds:
                response += f"⏱️ **New time:** {format_duration(time_spent_seconds)}\n"
            if arguments.get("description"):
                response += f"📝 **New description:** {arguments['description']}\n"
            if arguments.get("start_date"):
                response += f"📅 **New date:** {arguments['start_date']}\n"
            
            return [types.TextContent(type="text", text=response)]
        
        elif name == "delete_worklog":
            worklog_id = arguments["worklog_id"]
            await tempo_client.delete_worklog(worklog_id)
            
            response = f"🗑️ **Worklog {worklog_id} deleted successfully!**"
            return [types.TextContent(type="text", text=response)]
        
        elif name == "get_accounts":
            result = await tempo_client.get_accounts()
            accounts = result.get("results", [])
            
            if not accounts:
                return [types.TextContent(type="text", text="No accounts found.")]
            
            response = f"Found {len(accounts)} account(s):\n\n"
            for account in accounts:
                status_emoji = "✅" if account.get("status") == "OPEN" else "❌"
                global_emoji = "🌍" if account.get("global") else "🏢"
                
                response += f"{status_emoji} {global_emoji} **{account['name']}** ({account['key']})\n"
                response += f"   Status: {account.get('status', 'Unknown')}\n\n"
            
            return [types.TextContent(type="text", text=response)]
        
        elif name == "get_work_attributes":
            result = await tempo_client.get_work_attributes()
            attributes = result.get("results", [])
            
            if not attributes:
                return [types.TextContent(type="text", text="No work attributes found.")]
            
            response = f"Found {len(attributes)} work attribute(s):\n\n"
            for attr in attributes:
                required_emoji = "⚠️" if attr.get("required") else "📝"
                
                response += f"{required_emoji} **{attr['name']}** ({attr['key']})\n"
                response += f"   Type: {attr.get('type', 'Unknown')}\n"
                
                if attr.get("values"):
                    response += f"   Values: {', '.join(attr['values'])}\n"
                response += "\n"
            
            return [types.TextContent(type="text", text=response)]
        
        elif name == "get_today_summary":
            today = date.today().isoformat()
            result = await tempo_client.get_worklogs(
                from_date=today,
                to_date=today,
                account_id=arguments.get("account_id"),
                limit=1000
            )
            
            worklogs = result.get("results", [])
            if not worklogs:
                return [types.TextContent(type="text", text="No time logged today.")]
            
            total_seconds = sum(w["timeSpentSeconds"] for w in worklogs)
            total_time = format_duration(total_seconds)
            
            # Group by issue
            by_issue = {}
            for worklog in worklogs:
                issue_key = worklog["issue"].get("key", "Unknown")
                if issue_key not in by_issue:
                    by_issue[issue_key] = []
                by_issue[issue_key].append(worklog)
            
            response = f"📅 **Today's Time Summary ({today})**\n\n"
            response += f"⏱️ **Total time logged: {total_time}**\n\n"
            
            for issue_key, issue_worklogs in by_issue.items():
                issue_total = sum(w["timeSpentSeconds"] for w in issue_worklogs)
                issue_time = format_duration(issue_total)
                
                response += f"🎫 **{issue_key}** - {issue_time}\n"
                for worklog in issue_worklogs:
                    worklog_time = format_duration(worklog["timeSpentSeconds"])
                    response += f"   • {worklog_time}: {worklog['description']}\n"
                response += "\n"
            
            return [types.TextContent(type="text", text=response)]
        
        else:
            return [types.TextContent(type="text", text=f"Unknown tool: {name}")]
    
    except Exception as e:
        logger.error(f"Error handling tool call {name}: {e}")
        return [types.TextContent(type="text", text=f"Error: {str(e)}")]


@server.list_resources()
async def handle_list_resources() -> List[types.Resource]:
    """List available resources"""
    return [
        types.Resource(
            uri="tempo://worklog-summary",
            name="Worklog Summary",
            description="Summary of worklog data and time tracking analytics",
            mimeType="application/json"
        ),
        types.Resource(
            uri="tempo://accounts",
            name="Tempo Accounts",
            description="List of available Tempo accounts",
            mimeType="application/json"
        ),
        types.Resource(
            uri="tempo://work-attributes",
            name="Work Attributes",
            description="Available work attributes and their configurations",
            mimeType="application/json"
        )
    ]


@server.read_resource()
async def handle_read_resource(uri: str) -> str:
    """Handle resource reading"""
    global tempo_client
    
    if not tempo_client:
        tempo_client = TempoApiClient(TEMPO_API_TOKEN, TEMPO_BASE_URL)
    
    try:
        if uri == "tempo://worklog-summary":
            # Get last 7 days summary
            end_date = date.today()
            start_date = end_date - timedelta(days=7)
            
            result = await tempo_client.get_worklogs(
                from_date=start_date.isoformat(),
                to_date=end_date.isoformat(),
                limit=1000
            )
            
            worklogs = result.get("results", [])
            total_seconds = sum(w["timeSpentSeconds"] for w in worklogs)
            
            summary = {
                "period": f"{start_date} to {end_date}",
                "total_worklogs": len(worklogs),
                "total_time_seconds": total_seconds,
                "total_time_formatted": format_duration(total_seconds),
                "daily_breakdown": {}
            }
            
            # Daily breakdown
            for worklog in worklogs:
                day = worklog["startDate"]
                if day not in summary["daily_breakdown"]:
                    summary["daily_breakdown"][day] = {
                        "count": 0,
                        "time_seconds": 0,
                        "time_formatted": "0m"
                    }
                summary["daily_breakdown"][day]["count"] += 1
                summary["daily_breakdown"][day]["time_seconds"] += worklog["timeSpentSeconds"]
                summary["daily_breakdown"][day]["time_formatted"] = format_duration(
                    summary["daily_breakdown"][day]["time_seconds"]
                )
            
            return str(summary)
        
        elif uri == "tempo://accounts":
            result = await tempo_client.get_accounts()
            return str(result)
        
        elif uri == "tempo://work-attributes":
            result = await tempo_client.get_work_attributes()
            return str(result)
        
        else:
            raise ValueError(f"Unknown resource: {uri}")
    
    except Exception as e:
        logger.error(f"Error reading resource {uri}: {e}")
        raise


async def main():
    """Main entry point for the MCP server"""
    logger.info("Starting Tempo MCP Server...")
    
    async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="tempo-mcp-server",
                server_version="0.1.0",
                capabilities=server.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={}
                )
            )
        )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
        sys.exit(1)
    finally:
        # Cleanup
        if tempo_client:
            asyncio.run(tempo_client.close())

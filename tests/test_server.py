"""
Tests for Tempo MCP Server

Basic test suite to validate server functionality and API integration.
"""

import pytest
import asyncio
from unittest.mock import AsyncMock, patch, MagicMock
from datetime import date

import sys
import os

# Add src to path for testing
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from tempo_mcp_server.server import (
    TempoApiClient,
    format_duration,
    parse_duration,
    server
)


class TestDurationHelpers:
    """Test duration formatting and parsing functions"""
    
    def test_format_duration(self):
        """Test duration formatting"""
        assert format_duration(3600) == "1h 0m"
        assert format_duration(3900) == "1h 5m"
        assert format_duration(1800) == "30m"
        assert format_duration(60) == "1m"
        assert format_duration(0) == "0m"
    
    def test_parse_duration(self):
        """Test duration parsing"""
        assert parse_duration("1h") == 3600
        assert parse_duration("1.5h") == 5400
        assert parse_duration("30m") == 1800
        assert parse_duration("1h 30m") == 5400
        assert parse_duration("2h 45m") == 9900
        assert parse_duration("90") == 5400  # Assume minutes
        assert parse_duration("") == 3600  # Default to 1 hour


class TestTempoApiClient:
    """Test Tempo API client functionality"""
    
    @pytest.fixture
    def api_client(self):
        """Create a test API client"""
        return TempoApiClient("test_token", "https://api.tempo.io/4")
    
    @pytest.mark.asyncio
    async def test_client_initialization(self, api_client):
        """Test client initializes correctly"""
        assert api_client.api_token == "test_token"
        assert api_client.base_url == "https://api.tempo.io/4"
        assert "Bearer test_token" in api_client.session.headers["Authorization"]
    
    @pytest.mark.asyncio
    async def test_rate_limiting(self, api_client):
        """Test rate limiting functionality"""
        with patch.object(api_client.session, 'get') as mock_get:
            mock_response = MagicMock()
            mock_response.json.return_value = {"results": []}
            mock_response.content = b'{"results": []}'
            mock_get.return_value = mock_response
            
            start_time = asyncio.get_event_loop().time()
            
            # Make two requests
            await api_client._make_request("GET", "/test")
            await api_client._make_request("GET", "/test")
            
            end_time = asyncio.get_event_loop().time()
            
            # Should have taken at least the rate limit delay
            assert end_time - start_time >= 0.2  # RATE_LIMIT_DELAY
    
    @pytest.mark.asyncio
    async def test_get_worklogs(self, api_client):
        """Test getting worklogs"""
        mock_response = {
            "results": [
                {
                    "tempoWorklogId": 1,
                    "timeSpentSeconds": 3600,
                    "description": "Test work",
                    "startDate": "2025-05-23",
                    "issue": {"key": "TEST-1"},
                    "author": {"displayName": "Test User"}
                }
            ]
        }
        
        with patch.object(api_client, '_make_request', return_value=mock_response):
            result = await api_client.get_worklogs(
                from_date="2025-05-23",
                to_date="2025-05-23"
            )
            
            assert len(result["results"]) == 1
            assert result["results"][0]["tempoWorklogId"] == 1
    
    @pytest.mark.asyncio
    async def test_create_worklog(self, api_client):
        """Test creating a worklog"""
        mock_response = {
            "tempoWorklogId": 123,
            "timeSpentSeconds": 7200,
            "description": "New work entry",
            "issue": {"key": "TEST-2"}
        }
        
        with patch.object(api_client, '_make_request', return_value=mock_response):
            result = await api_client.create_worklog(
                issue_id=10001,
                time_spent_seconds=7200,
                start_date="2025-05-23",
                description="New work entry"
            )
            
            assert result["tempoWorklogId"] == 123
            assert result["timeSpentSeconds"] == 7200
    
    @pytest.mark.asyncio
    async def test_error_handling(self, api_client):
        """Test error handling for API failures"""
        import httpx
        
        with patch.object(api_client.session, 'get') as mock_get:
            # Simulate 401 authentication error
            mock_response = MagicMock()
            mock_response.status_code = 401
            mock_response.text = "Unauthorized"
            mock_get.side_effect = httpx.HTTPStatusError(
                "401 Unauthorized", 
                request=MagicMock(), 
                response=mock_response
            )
            
            with pytest.raises(Exception) as exc_info:
                await api_client._make_request("GET", "/test")
            
            assert "Authentication failed" in str(exc_info.value)


class TestMCPServer:
    """Test MCP server functionality"""
    
    @pytest.mark.asyncio
    async def test_list_tools(self):
        """Test that server lists all expected tools"""
        tools = await server.call_handler("list_tools", {})
        
        tool_names = [tool.name for tool in tools]
        expected_tools = [
            "get_worklogs",
            "create_worklog", 
            "update_worklog",
            "delete_worklog",
            "get_accounts",
            "get_work_attributes",
            "get_today_summary"
        ]
        
        for expected_tool in expected_tools:
            assert expected_tool in tool_names
    
    @pytest.mark.asyncio
    async def test_list_resources(self):
        """Test that server lists all expected resources"""
        resources = await server.call_handler("list_resources", {})
        
        resource_uris = [resource.uri for resource in resources]
        expected_resources = [
            "tempo://worklog-summary",
            "tempo://accounts", 
            "tempo://work-attributes"
        ]
        
        for expected_resource in expected_resources:
            assert expected_resource in resource_uris


class TestIntegration:
    """Integration tests requiring environment setup"""
    
    @pytest.mark.integration
    @pytest.mark.asyncio
    async def test_real_api_connection(self):
        """Test real API connection if token is available"""
        api_token = os.getenv("TEMPO_API_TOKEN")
        
        if not api_token:
            pytest.skip("TEMPO_API_TOKEN not set - skipping integration test")
        
        client = TempoApiClient(api_token)
        
        try:
            # Try to get accounts (this should work with any valid token)
            result = await client.get_accounts()
            assert "results" in result
            print(f"✅ Successfully connected to Tempo API")
            print(f"Found {len(result.get('results', []))} accounts")
            
        except Exception as e:
            pytest.fail(f"Failed to connect to Tempo API: {e}")
        
        finally:
            await client.close()


if __name__ == "__main__":
    # Run tests
    pytest.main([__file__, "-v"])

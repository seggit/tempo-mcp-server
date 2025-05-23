# Tempo MCP Server Usage Examples

This document provides comprehensive usage examples for the Tempo MCP Server.

## Quick Start

### Docker Setup (Recommended)

```bash
# 1. Clone and setup
git clone https://github.com/seggit/tempo-mcp-server.git
cd tempo-mcp-server

# 2. Make scripts executable
chmod +x docker-setup.sh docker-wrapper.sh setup.sh

# 3. Run setup (will prompt for API token)
./docker-setup.sh

# 4. Test the server
./docker-wrapper.sh --test
```

### Local Python Setup

```bash
# 1. Clone and setup
git clone https://github.com/seggit/tempo-mcp-server.git
cd tempo-mcp-server

# 2. Make setup script executable
chmod +x setup.sh

# 3. Run setup
./setup.sh

# 4. Configure API token in .env file
# 5. Test the server
python src/tempo_mcp_server/server.py
```

## Configuration Examples

### Claude Desktop Configuration

**Docker version (copy to claude_desktop_config.json):**
```json
{
  "mcpServers": {
    "tempo": {
      "command": "/Users/yourname/tempo-mcp-server/docker-wrapper.sh",
      "args": ["--mcp"],
      "env": {
        "TEMPO_API_TOKEN": "your_actual_token_here"
      }
    }
  }
}
```

**Python version:**
```json
{
  "mcpServers": {
    "tempo": {
      "command": "python",
      "args": ["/Users/yourname/tempo-mcp-server/src/tempo_mcp_server/server.py"],
      "env": {
        "TEMPO_API_TOKEN": "your_actual_token_here"
      }
    }
  }
}
```

## Usage with AI Assistants

Once configured, you can use natural language commands:

### Worklog Management

**Create worklogs:**
```
Create a worklog for 2.5 hours on DEV-123 with description "Fixed authentication bug"

Log 4 hours on PROJ-456 for yesterday with description "API development and testing"

Add a worklog: 1.5 hours on BUG-789, started at 2:00 PM today, description "Code review and debugging"
```

**View worklogs:**
```
Show me all worklogs for today

List worklogs from last week

What worklogs exist for project MYPROJECT?

Show me my time for this month
```

**Update worklogs:**
```
Update worklog 123 to 3 hours with description "Extended debugging session"

Change worklog 456 start time to 10:00 AM

Modify the description of worklog 789 to "Final testing and deployment"
```

### Time Tracking & Analytics

**Daily summaries:**
```
Give me today's time summary

How much time did I log today?

Show my productivity for this week
```

**Project analytics:**
```
How much time was spent on project XYZ this month?

Show time breakdown by project for last week

What's the total time logged across all projects?
```

**Account and attribute management:**
```
List all available Tempo accounts

Show me the work attributes I can use

What accounts can I log time to?
```

## Advanced Examples

### Bulk Operations

```
Create multiple worklogs:
- 2h on DEV-100 for "Frontend development" 
- 1.5h on DEV-101 for "Backend API work"
- 30m on DEV-102 for "Code review"
All for today starting at 9 AM
```

### Detailed Time Tracking

```
Create a detailed worklog:
- Issue: PROJ-555
- Time: 3 hours 15 minutes  
- Date: 2025-05-20
- Start time: 1:30 PM
- Description: "Database optimization and performance tuning"
- Mark as billable
```

### Reporting

```
Generate a weekly report showing:
- Total hours logged
- Time by project
- Top issues worked on
- Productivity metrics
```

## Troubleshooting Examples

### Common Issues and Solutions

**Problem: "Authentication failed"**
```bash
# Check your API token
./docker-wrapper.sh --test
# or
TEMPO_DEBUG=true python src/tempo_mcp_server/server.py
```

**Problem: "Docker not found"**
```bash
# Install Docker and try again
docker --version
./docker-setup.sh
```

**Problem: "MCP connection failed"**
- Verify the path in your MCP configuration
- Check that the wrapper script is executable: `chmod +x docker-wrapper.sh`
- Test the server directly: `./docker-wrapper.sh --test`

## Development Examples

### Testing

```bash
# Run all tests
pytest tests/ -v

# Test with Docker
docker compose --profile test up tempo-mcp-test

# Test with coverage
pytest --cov=src/tempo_mcp_server tests/
```

### Development with MCP Inspector

```bash
# Install MCP Inspector
npm install -g @modelcontextprotocol/inspector

# Test the server
mcp-inspector ./docker-wrapper.sh

# Or for local Python
mcp-inspector python src/tempo_mcp_server/server.py
```

### Docker Development

```bash
# Development with live reload
docker compose --profile dev up tempo-mcp-dev

# View logs
docker logs tempo-mcp-server

# Access container
docker exec -it tempo-mcp-server bash

# Rebuild and test
./docker-wrapper.sh --build
./docker-wrapper.sh --test
```

## Production Deployment

### Using Docker

```bash
# Build production image
docker build -t tempo-mcp-server:production .

# Run in production
docker run -d \
  --name tempo-mcp-prod \
  --restart unless-stopped \
  -e TEMPO_API_TOKEN=your_token \
  tempo-mcp-server:production

# Or use Docker Compose
docker compose up -d tempo-mcp-server
```

### Environment Variables

```env
# Production .env file
TEMPO_API_TOKEN=your_production_token_here
TEMPO_BASE_URL=https://api.tempo.io/4
TEMPO_DEBUG=false
```

## Integration Examples

### With Multiple MCP Servers

```json
{
  "mcpServers": {
    "tempo": {
      "command": "/path/to/tempo-mcp-server/docker-wrapper.sh",
      "args": ["--mcp"],
      "env": {
        "TEMPO_API_TOKEN": "your_tempo_token"
      }
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your_github_token"
      }
    }
  }
}
```

### Cross-System Workflows

```
Link GitHub issue to Tempo worklog:
1. Create GitHub issue for "Bug fix XYZ"
2. Create Tempo worklog for 2h on that issue
3. Update GitHub issue with time tracking info
```

This allows for powerful cross-system automation and reporting!

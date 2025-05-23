# Tempo MCP Server

A Model Context Protocol (MCP) server that provides seamless integration with Tempo Cloud API for worklog management. This server enables AI assistants like Claude to interact with your Tempo worklogs, accounts, and time tracking data.

## 🚀 Features

### Worklog Management
- **List worklogs** - Get worklogs by date range, user, project, or issue
- **Create worklogs** - Add new time entries with descriptions and attributes
- **Update worklogs** - Modify existing time entries
- **Delete worklogs** - Remove unwanted entries
- **Get worklog details** - Retrieve detailed information for specific worklogs

### Account & Attribute Management
- **List accounts** - Get available Tempo accounts
- **List work attributes** - Retrieve custom work attributes and their values
- **Account analytics** - Get account-specific time tracking data

### Search & Reporting
- **Advanced worklog search** - Filter by multiple criteria
- **Time tracking reports** - Generate summaries and analytics
- **User productivity insights** - Track time across projects and issues

## 📋 Prerequisites

1. **Tempo Cloud instance** with API access
2. **Tempo API Token** - Generate from Tempo Settings → API Integration
3. **Docker** (for containerized setup) OR **Python 3.8+** (for local setup)
4. **MCP-compatible client** (Claude Desktop, VS Code with MCP extension, etc.)

## 🐳 Installation (Docker - Recommended)

### Quick Docker Setup

```bash
# Clone the repository
git clone https://github.com/seggit/tempo-mcp-server.git
cd tempo-mcp-server

# Run the automated Docker setup
chmod +x docker-setup.sh
./docker-setup.sh
```

This script will:
- ✅ Check Docker installation
- ✅ Build the Docker image
- ✅ Set up environment configuration
- ✅ Test the container
- ✅ Generate MCP client configurations

### Manual Docker Setup

```bash
# Build the Docker image
docker build -t tempo-mcp-server .

# Create environment file
cp .env.example .env
# Edit .env and add your TEMPO_API_TOKEN

# Test the server
./docker-wrapper.sh --test

# Use with Docker Compose
docker compose up tempo-mcp-server
```

## 🛠️ Installation (Local Python)

### Option 1: Quick Start with UV (Recommended)

```bash
# Clone the repository
git clone https://github.com/seggit/tempo-mcp-server.git
cd tempo-mcp-server

# Install with UV (fastest)
uvx tempo-mcp-server
```

### Option 2: Development Setup

```bash
# Clone the repository
git clone https://github.com/seggit/tempo-mcp-server.git
cd tempo-mcp-server

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Install in development mode
pip install -e .
```

## ⚙️ Configuration

### 1. Tempo API Token

Get your Tempo API token:
1. Go to Tempo → Settings → API Integration
2. Create a new token with appropriate permissions
3. Copy the token (you'll need it for configuration)

### 2. Environment Variables

Create a `.env` file in the project root:

```env
TEMPO_API_TOKEN=your_tempo_api_token_here
TEMPO_BASE_URL=https://api.tempo.io/4
```

### 3. MCP Client Configuration

#### For Claude Desktop (Docker)

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "tempo": {
      "command": "/absolute/path/to/tempo-mcp-server/docker-wrapper.sh",
      "args": ["--mcp"],
      "env": {
        "TEMPO_API_TOKEN": "your_tempo_api_token_here"
      }
    }
  }
}
```

#### For Claude Desktop (Local Python)

```json
{
  "mcpServers": {
    "tempo": {
      "command": "python",
      "args": ["/path/to/tempo-mcp-server/src/tempo_mcp_server/server.py"],
      "env": {
        "TEMPO_API_TOKEN": "your_tempo_api_token_here"
      }
    }
  }
}
```

#### For VS Code with MCP Extension (Docker)

Add to your `.vscode/mcp.json`:

```json
{
  "servers": {
    "tempo": {
      "command": "/absolute/path/to/tempo-mcp-server/docker-wrapper.sh",
      "args": ["--mcp"],
      "env": {
        "TEMPO_API_TOKEN": "your_tempo_api_token_here",
        "TEMPO_DEBUG": "false"
      }
    }
  }
}
```

#### For VS Code with MCP Extension (Local Python)

```json
{
  "servers": {
    "tempo": {
      "command": "python",
      "args": ["/path/to/tempo-mcp-server/src/tempo_mcp_server/server.py"],
      "env": {
        "TEMPO_API_TOKEN": "your_tempo_api_token_here",
        "TEMPO_DEBUG": "false"
      }
    }
  }
}
```

## 🚀 Usage

### Basic Examples

1. **List today's worklogs:**
   ```
   Show me all worklogs for today
   ```

2. **Create a new worklog:**
   ```
   Create a worklog for 2 hours on issue DEV-123 with description "Fixed login bug"
   ```

3. **Get project time summary:**
   ```
   How much time was logged on project XYZ this week?
   ```

4. **Find worklogs by user:**
   ```
   Show all worklogs by john.doe@company.com this month
   ```

### Advanced Usage

```
Create a worklog for 3.5 hours on issue PROJ-456 starting at 9:00 AM today with:
- Description: "API integration development"
- Account: Development
- Work category: External
```

## 🐳 Docker Commands

### Basic Docker Usage

```bash
# Build image
docker build -t tempo-mcp-server .

# Run server (interactive)
./docker-wrapper.sh

# Run with debug logging
./docker-wrapper.sh --test

# Force rebuild image
./docker-wrapper.sh --build

# Get help
./docker-wrapper.sh --help
```

### Docker Compose Usage

```bash
# Start production server
docker compose up tempo-mcp-server

# Start development server (with volume mounts)
docker compose --profile dev up tempo-mcp-dev

# Run tests in container
docker compose --profile test up tempo-mcp-test

# Run in background
docker compose up -d tempo-mcp-server
```

### Container Management

```bash
# View logs
docker logs tempo-mcp-server

# Access container shell
docker exec -it tempo-mcp-server bash

# Stop all containers
docker compose down

# Clean up everything
docker compose down -v --rmi all
```

## 🔧 Development

### Running Tests

```bash
# Install test dependencies
pip install -e ".[test]"

# Run tests (local)
pytest tests/

# Run tests (Docker)
docker compose --profile test up tempo-mcp-test

# Run with coverage
pytest --cov=src/tempo_mcp_server tests/
```

### Using MCP Inspector for Development

```bash
# Install MCP Inspector
npm install -g @modelcontextprotocol/inspector

# Run the inspector (local)
mcp-inspector python src/tempo_mcp_server/server.py

# Run the inspector (Docker)
mcp-inspector ./docker-wrapper.sh
```

### Rate Limiting

Tempo API has a rate limit of **5 requests per second**. The server automatically handles rate limiting and implements retry logic with exponential backoff.

## 📚 API Reference

### Available Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_worklogs` | Retrieve worklogs by criteria | `from`, `to`, `user`, `project`, `issue` |
| `create_worklog` | Create a new worklog entry | `issue_id`, `time_spent`, `description`, `start_date` |
| `update_worklog` | Update existing worklog | `worklog_id`, `time_spent`, `description` |
| `delete_worklog` | Delete a worklog | `worklog_id` |
| `get_accounts` | List available accounts | None |
| `get_work_attributes` | Get work attributes | None |
| `search_worklogs` | Advanced worklog search | `query`, `filters` |

### Available Resources

| Resource | Description |
|----------|-------------|
| `worklog_summary` | Daily/weekly/monthly time summaries |
| `user_productivity` | User productivity reports |
| `project_analytics` | Project-based time analytics |

## 🐛 Troubleshooting

### Common Issues

1. **Authentication errors:**
   - Verify your API token is correct
   - Check token permissions in Tempo settings
   - Ensure token hasn't expired

2. **Rate limiting:**
   - Server automatically handles rate limits
   - For bulk operations, consider using smaller batch sizes

3. **MCP connection issues:**
   - Verify Python path in MCP configuration (local) or Docker wrapper path (Docker)
   - Check environment variables are set
   - Review server logs for detailed errors

4. **Docker issues:**
   - Ensure Docker is running: `docker info`
   - Check image exists: `docker images | grep tempo-mcp-server`
   - Rebuild if needed: `./docker-wrapper.sh --build`
   - View logs: `docker logs tempo-mcp-server`

### Debug Mode

**Local Python:**
```bash
TEMPO_DEBUG=true python src/tempo_mcp_server/server.py
```

**Docker:**
```bash
./docker-wrapper.sh --test
# or
docker compose --profile dev up tempo-mcp-dev
```

### Deployment Options

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| **Docker** | Production, easy setup | Isolated, consistent, easy deployment | Requires Docker |
| **Local Python** | Development, lightweight | Direct control, easier debugging | Environment setup required |
| **Docker Compose** | Development, multi-service | Easy orchestration, volume mounts | More complex setup |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Anthropic](https://anthropic.com) for the Model Context Protocol
- [Tempo](https://tempo.io) for their comprehensive API
- The MCP community for inspiration and examples

## 📞 Support

- 🐛 **Bug reports:** [GitHub Issues](https://github.com/seggit/tempo-mcp-server/issues)
- 💡 **Feature requests:** [GitHub Discussions](https://github.com/seggit/tempo-mcp-server/discussions)
- 📖 **Documentation:** [Wiki](https://github.com/seggit/tempo-mcp-server/wiki)

---

**Note:** This server uses Tempo API v4.0. Ensure your Tempo instance supports this version.

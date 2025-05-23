# Windows Setup Guide for Tempo MCP Server

This guide provides step-by-step instructions for setting up the Tempo MCP Server on Windows.

## 🪟 Prerequisites for Windows

1. **Windows 10/11** (any recent version)
2. **One of the following:**
   - **Docker Desktop** (Recommended) - [Download here](https://docs.docker.com/desktop/windows/install/)
   - **Python 3.8+** - [Download here](https://www.python.org/downloads/windows/)
3. **Tempo Cloud API Token** - Get from Tempo → Settings → API Integration
4. **Claude Desktop** or **VS Code with MCP extension**

## 🚀 Quick Start (Windows)

### Option 1: PowerShell (Recommended)

Open **PowerShell** as a regular user (no admin needed):

```powershell
# 1. Clone the repository
git clone https://github.com/seggit/tempo-mcp-server.git
cd tempo-mcp-server

# 2. Run the quick start script
.\quick-start.ps1
```

### Option 2: Command Prompt

Open **Command Prompt**:

```cmd
# 1. Clone the repository
git clone https://github.com/seggit/tempo-mcp-server.git
cd tempo-mcp-server

# 2. Run the batch file
quick-start.bat
```

## 🐳 Docker Setup (Recommended for Windows)

### Why Docker on Windows?
- ✅ **No Python environment issues**
- ✅ **Consistent behavior**
- ✅ **Easy updates**
- ✅ **Isolated from system**

### Step-by-Step Docker Setup

1. **Install Docker Desktop:**
   - Download from [Docker Desktop for Windows](https://docs.docker.com/desktop/windows/install/)
   - Install and restart your computer
   - Start Docker Desktop

2. **Clone and Setup:**
   ```powershell
   git clone https://github.com/seggit/tempo-mcp-server.git
   cd tempo-mcp-server
   .\docker-setup.ps1
   ```

3. **Configure API Token:**
   - Edit the `.env` file created by the setup
   - Replace `your_tempo_api_token_here` with your actual token

4. **Test the Setup:**
   ```powershell
   .\docker-wrapper.ps1 -Test
   ```

## 🐍 Local Python Setup

### Step-by-Step Python Setup

1. **Install Python:**
   - Download from [Python.org](https://www.python.org/downloads/windows/)
   - ⚠️ **Important:** Check "Add Python to PATH" during installation

2. **Clone and Setup:**
   ```powershell
   git clone https://github.com/seggit/tempo-mcp-server.git
   cd tempo-mcp-server
   .\setup.ps1
   ```

3. **Configure API Token:**
   - Edit the `.env` file
   - Add your Tempo API token

4. **Test the Setup:**
   ```powershell
   python src\tempo_mcp_server\server.py
   ```

## ⚙️ Claude Desktop Configuration (Windows)

### For Docker Setup

1. **Find your Claude Desktop config file:**
   - Location: `%APPDATA%\Claude\claude_desktop_config.json`
   - Or: `C:\Users\YourName\AppData\Roaming\Claude\claude_desktop_config.json`

2. **Update the config:**
   ```json
   {
     "mcpServers": {
       "tempo": {
         "command": "powershell",
         "args": ["-File", "C:\\path\\to\\tempo-mcp-server\\docker-wrapper.ps1", "-MCP"],
         "env": {
           "TEMPO_API_TOKEN": "your_tempo_api_token_here"
         }
       }
     }
   }
   ```

### For Python Setup

```json
{
  "mcpServers": {
    "tempo": {
      "command": "python",
      "args": ["C:\\path\\to\\tempo-mcp-server\\src\\tempo_mcp_server\\server.py"],
      "env": {
        "TEMPO_API_TOKEN": "your_tempo_api_token_here"
      }
    }
  }
}
```

## 🔧 VS Code Configuration (Windows)

Create or update `.vscode/mcp.json` in your workspace:

### For Docker Setup

```json
{
  "servers": {
    "tempo": {
      "command": "powershell",
      "args": ["-File", "C:\\path\\to\\tempo-mcp-server\\docker-wrapper.ps1", "-MCP"],
      "env": {
        "TEMPO_API_TOKEN": "your_tempo_api_token_here",
        "TEMPO_DEBUG": "false"
      }
    }
  }
}
```

## 🎯 Windows-Specific Tips

### PowerShell Execution Policy

If you get execution policy errors:

```powershell
# Run this as Administrator (one time only)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### File Paths in Windows

- Use **full paths** in MCP configurations
- Use **backslashes** (`\`) or **forward slashes** (`/`)
- Example: `C:\Users\YourName\tempo-mcp-server\docker-wrapper.ps1`

### Finding Your Claude Desktop Config

1. Press `Win + R`
2. Type: `%APPDATA%\Claude`
3. Look for `claude_desktop_config.json`

### Environment Variables

You can also set environment variables system-wide:

1. Press `Win + X` → **System**
2. Click **Advanced system settings**
3. Click **Environment Variables**
4. Add `TEMPO_API_TOKEN` with your token value

## 🐛 Windows Troubleshooting

### Common Issues

**Problem: "PowerShell scripts are disabled"**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Problem: "Docker not found"**
- Install Docker Desktop
- Restart your computer
- Make sure Docker Desktop is running

**Problem: "Python not found"**
- Reinstall Python with "Add to PATH" checked
- Or add Python manually to PATH

**Problem: "Access denied"**
- Don't run as Administrator
- Make sure files aren't in a restricted folder

### Debug Commands

**Test Docker:**
```powershell
docker --version
docker info
```

**Test Python:**
```powershell
python --version
pip --version
```

**Test MCP Server:**
```powershell
# Docker version
.\docker-wrapper.ps1 -Test

# Python version  
python src\tempo_mcp_server\server.py
```

### Getting Help

**Check PowerShell help:**
```powershell
Get-Help .\docker-setup.ps1
Get-Help .\docker-wrapper.ps1 -Examples
```

**Check environment:**
```powershell
Get-Content .env
$env:TEMPO_API_TOKEN
```

## 🎉 Success!

Once configured, you can use natural language with Claude:

```
"Create a worklog for 2 hours on DEV-123 with description 'Fixed login bug'"
"Show me today's time summary"
"List all my worklogs from this week"
```

## 📁 Windows File Structure

After setup, your directory should look like:

```
tempo-mcp-server\
├── 📁 src\
├── 📁 examples\
├── 🐳 docker-wrapper.ps1     ← For MCP integration
├── 🐳 docker-setup.ps1       ← Setup script
├── 🐍 setup.ps1              ← Python setup
├── 🚀 quick-start.ps1        ← One-command setup
├── 🚀 quick-start.bat        ← Batch alternative
├── ⚙️ .env                   ← Your API token
└── 📖 README.md
```

Your Tempo MCP Server is now ready to use on Windows! 🎉

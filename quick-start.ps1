# Tempo MCP Server - One-Command Setup for Windows
# This script gets you up and running in minutes on Windows!

param([switch]$Help)

# Colors for pretty output
function Write-Green { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Blue { param($msg) Write-Host $msg -ForegroundColor Blue }
function Write-Yellow { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Red { param($msg) Write-Host $msg -ForegroundColor Red }

if ($Help) {
    Write-Host "Tempo MCP Server - Quick Start for Windows"
    Write-Host ""
    Write-Host "Usage: .\quick-start.ps1"
    Write-Host ""
    Write-Host "This script will guide you through setting up the Tempo MCP Server"
    Write-Host "on Windows using either Docker or local Python."
    Write-Host ""
    exit 0
}

Write-Blue ""
Write-Blue "🚀 Tempo MCP Server - Quick Start for Windows"
Write-Blue "==============================================="
Write-Blue ""

# Check if we're in the right directory
if (!(Test-Path "docker-setup.ps1")) {
    Write-Red "❌ Please run this from the tempo-mcp-server directory"
    Write-Host "If you haven't cloned the repo yet:"
    Write-Host "  git clone https://github.com/seggit/tempo-mcp-server.git"
    Write-Host "  cd tempo-mcp-server"
    Write-Host "  .\quick-start.ps1"
    exit 1
}

# Check execution policy
try {
    $executionPolicy = Get-ExecutionPolicy
    if ($executionPolicy -eq "Restricted") {
        Write-Yellow "⚠️  PowerShell execution policy is Restricted."
        Write-Host "To allow script execution, run this command as Administrator:"
        Write-Host "  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
        Write-Host ""
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            exit 1
        }
    }
}
catch {
    Write-Yellow "⚠️  Could not check execution policy: $($_.Exception.Message)"
}

# Make sure scripts are unblocked (Windows security feature)
Write-Yellow "🔧 Unblocking PowerShell scripts..."
try {
    Get-ChildItem "*.ps1" | Unblock-File -ErrorAction SilentlyContinue
}
catch {
    Write-Yellow "⚠️  Could not unblock scripts: $($_.Exception.Message)"
}

# Detect preferred setup method
Write-Host ""
Write-Host "Choose your setup method:"
Write-Host "1) 🐳 Docker (Recommended - Easy, consistent, isolated)"
Write-Host "2) 🐍 Local Python (Development-friendly, direct control)"
Write-Host ""
$choice = Read-Host "Enter your choice (1 or 2)"

switch ($choice) {
    "1" {
        Write-Blue "🐳 Setting up with Docker..."
        Write-Host ""
        
        # Check if Docker is available
        try {
            docker --version | Out-Null
            if ($LASTEXITCODE -ne 0) { throw }
        }
        catch {
            Write-Red "❌ Docker not found!"
            Write-Host "Please install Docker Desktop for Windows:"
            Write-Host "  https://docs.docker.com/desktop/windows/install/"
            Write-Host ""
            Write-Host "After installing Docker, restart this script."
            exit 1
        }
        
        .\docker-setup.ps1
    }
    "2" {
        Write-Blue "🐍 Setting up with local Python..."
        Write-Host ""
        
        # Check if Python is available
        try {
            python --version | Out-Null
            if ($LASTEXITCODE -ne 0) { throw }
        }
        catch {
            Write-Red "❌ Python not found!"
            Write-Host "Please install Python 3.8+ for Windows:"
            Write-Host "  https://www.python.org/downloads/windows/"
            Write-Host ""
            Write-Host "Make sure to check 'Add Python to PATH' during installation."
            Write-Host "After installing Python, restart this script."
            exit 1
        }
        
        .\setup.ps1
    }
    default {
        Write-Red "❌ Invalid choice. Please run the script again."
        exit 1
    }
}

Write-Host ""
Write-Green "✅ Setup complete!"
Write-Host ""
Write-Host "🎯 Next steps:"
Write-Host "1. Configure your Tempo API token in the .env file"
Write-Host "2. Add the MCP server to your Claude Desktop or VS Code configuration"
Write-Host "3. Start using natural language commands for time tracking!"
Write-Host ""
Write-Host "📖 See USAGE.md for examples and README.md for detailed documentation"
Write-Host ""
Write-Yellow "💡 Quick test:"
if ($choice -eq "1") {
    Write-Host "   .\docker-wrapper.ps1 -Test"
}
else {
    Write-Host "   python src\tempo_mcp_server\server.py"
}
Write-Host ""
Write-Green "🎉 Happy time tracking!"

@echo off
REM Tempo MCP Server Quick Setup for Windows (Batch version)
REM This is an alternative to PowerShell for users who prefer batch files

echo.
echo 🚀 Tempo MCP Server - Quick Start for Windows
echo ===============================================
echo.

REM Check if we're in the right directory
if not exist docker-setup.ps1 (
    echo ❌ Please run this from the tempo-mcp-server directory
    echo If you haven't cloned the repo yet:
    echo   git clone https://github.com/seggit/tempo-mcp-server.git
    echo   cd tempo-mcp-server
    echo   quick-start.bat
    pause
    exit /b 1
)

echo Choose your setup method:
echo 1) 🐳 Docker (Recommended - Easy, consistent, isolated)
echo 2) 🐍 Local Python (Development-friendly, direct control)
echo.
set /p choice="Enter your choice (1 or 2): "

if "%choice%"=="1" (
    echo 🐳 Setting up with Docker...
    echo.
    
    REM Check if Docker is available
    docker --version >nul 2>&1
    if errorlevel 1 (
        echo ❌ Docker not found!
        echo Please install Docker Desktop for Windows:
        echo   https://docs.docker.com/desktop/windows/install/
        echo.
        echo After installing Docker, restart this script.
        pause
        exit /b 1
    )
    
    powershell -ExecutionPolicy Bypass -File docker-setup.ps1
) else if "%choice%"=="2" (
    echo 🐍 Setting up with local Python...
    echo.
    
    REM Check if Python is available
    python --version >nul 2>&1
    if errorlevel 1 (
        echo ❌ Python not found!
        echo Please install Python 3.8+ for Windows:
        echo   https://www.python.org/downloads/windows/
        echo.
        echo Make sure to check 'Add Python to PATH' during installation.
        echo After installing Python, restart this script.
        pause
        exit /b 1
    )
    
    powershell -ExecutionPolicy Bypass -File setup.ps1
) else (
    echo ❌ Invalid choice. Please run the script again.
    pause
    exit /b 1
)

echo.
echo ✅ Setup complete!
echo.
echo 🎯 Next steps:
echo 1. Configure your Tempo API token in the .env file
echo 2. Add the MCP server to your Claude Desktop or VS Code configuration
echo 3. Start using natural language commands for time tracking!
echo.
echo 📖 See USAGE.md for examples and README.md for detailed documentation
echo.
echo 💡 Quick test:
if "%choice%"=="1" (
    echo    powershell -File docker-wrapper.ps1 -Test
) else (
    echo    python src\tempo_mcp_server\server.py
)
echo.
echo 🎉 Happy time tracking!
pause

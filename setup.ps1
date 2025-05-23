# Tempo MCP Server Setup Script for Windows
# This script helps you set up the Tempo MCP Server quickly on Windows

param(
    [switch]$Dev,
    [switch]$Help
)

# Color functions
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "ℹ️  $msg" -ForegroundColor Blue }
function Write-Warning { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Header { param($msg) Write-Host "🚀 $msg" -ForegroundColor Cyan }

if ($Help) {
    Write-Host "Tempo MCP Server Setup for Windows"
    Write-Host ""
    Write-Host "Usage: .\setup.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Dev          Install development dependencies"
    Write-Host "  -Help         Show this help message"
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Header "Tempo MCP Server Setup for Windows"
Write-Host "==================================="

# Check if Python is installed
function Test-Python {
    Write-Info "Checking Python installation..."
    
    try {
        $pythonVersion = python --version 2>$null
        if ($LASTEXITCODE -ne 0) { throw }
        Write-Success "Python found: $pythonVersion"
        
        # Check Python version
        $versionMatch = $pythonVersion -match "Python (\d+)\.(\d+)"
        if ($versionMatch) {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 8)) {
                Write-Warning "Python 3.8+ is recommended. You have $pythonVersion"
            }
        }
    }
    catch {
        Write-Error "Python 3 is required but not found. Please install Python 3.8+ first."
        Write-Host "Download from: https://www.python.org/downloads/windows/"
        exit 1
    }
}

# Check if we're in a virtual environment
function Test-VirtualEnvironment {
    $inVenv = $env:VIRTUAL_ENV -ne $null
    
    if (!$inVenv) {
        Write-Info "Creating virtual environment..."
        python -m venv venv
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create virtual environment"
            exit 1
        }
        
        Write-Info "Activating virtual environment..."
        & ".\venv\Scripts\Activate.ps1"
        Write-Success "Virtual environment activated"
    }
    else {
        Write-Success "Already in virtual environment: $env:VIRTUAL_ENV"
    }
}

# Install dependencies
function Install-Dependencies {
    Write-Info "Installing dependencies..."
    
    # Upgrade pip
    python -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to upgrade pip"
        exit 1
    }
    
    # Install main dependencies
    pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install dependencies"
        exit 1
    }
    
    # Install development dependencies if requested
    if ($Dev) {
        Write-Info "Installing development dependencies..."
        if (Test-Path "requirements-dev.txt") {
            pip install -r requirements-dev.txt
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Some development dependencies failed to install"
            }
        }
    }
    
    # Install the package in development mode
    Write-Info "Installing package in development mode..."
    pip install -e .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install package"
        exit 1
    }
    
    Write-Success "Dependencies installed successfully"
}

# Setup environment file
function Set-Environment {
    Write-Info "Setting up environment configuration..."
    
    if (!(Test-Path ".env")) {
        Write-Info "Creating .env file from template..."
        Copy-Item ".env.example" ".env"
        Write-Success "Created .env file"
        Write-Warning "Please edit .env file and add your TEMPO_API_TOKEN"
    }
    else {
        Write-Success ".env file already exists"
    }
    
    # Check for Tempo API token
    if (Test-Path ".env") {
        $envContent = Get-Content ".env" -Raw
        if ($envContent -match "your_tempo_api_token_here") {
            Write-Warning "TEMPO_API_TOKEN not set in .env file"
            Write-Host ""
            Write-Host "To configure your Tempo API token:"
            Write-Host "1. Go to Tempo → Settings → API Integration"
            Write-Host "2. Create a new token"
            Write-Host "3. Edit .env file: TEMPO_API_TOKEN=your_token_here"
        }
        else {
            Write-Success "TEMPO_API_TOKEN is configured"
        }
    }
}

# Test the installation
function Test-Installation {
    Write-Info "Testing installation..."
    
    try {
        python -c "import tempo_mcp_server; print('✅ Package import successful')"
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Installation test passed"
        }
        else {
            Write-Warning "Package import test failed"
        }
    }
    catch {
        Write-Warning "Could not test package import: $($_.Exception.Message)"
    }
}

# Show completion message
function Show-Completion {
    Write-Host ""
    Write-Success "🎉 Setup complete!"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Configure your Tempo API token in .env file"
    Write-Host "2. Test the server: python src\tempo_mcp_server\server.py"
    Write-Host "3. Add to your MCP client configuration"
    Write-Host ""
    Write-Host "📖 See README.md for full configuration instructions"
    
    # Run tests if in dev mode
    if ($Dev -and (Test-Path "tests")) {
        Write-Host ""
        Write-Info "🧪 Running tests..."
        try {
            pytest tests/ -v
        }
        catch {
            Write-Warning "Tests failed or pytest not available"
        }
    }
}

# Main execution
try {
    Test-Python
    Test-VirtualEnvironment
    Install-Dependencies
    Set-Environment
    Test-Installation
    Show-Completion
}
catch {
    Write-Error "Setup failed: $($_.Exception.Message)"
    exit 1
}

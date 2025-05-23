# Tempo MCP Server Docker Setup Script for Windows
# This script helps you set up the containerized Tempo MCP Server on Windows

param(
    [switch]$SkipBuild,
    [switch]$SkipTest,
    [switch]$Help
)

# Color functions for better output
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "ℹ️  $msg" -ForegroundColor Blue }
function Write-Warning { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Header { param($msg) Write-Host "🐳 $msg" -ForegroundColor Cyan }

if ($Help) {
    Write-Host "Tempo MCP Server Docker Setup for Windows"
    Write-Host ""
    Write-Host "Usage: .\docker-setup.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -SkipBuild    Skip building the Docker image"
    Write-Host "  -SkipTest     Skip testing the container"
    Write-Host "  -Help         Show this help message"
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Header "Tempo MCP Server Docker Setup for Windows"
Write-Host "=========================================="

# Check if Docker is installed and running
function Test-Docker {
    Write-Info "Checking Docker installation..."
    
    try {
        $null = Get-Command docker -ErrorAction Stop
    }
    catch {
        Write-Error "Docker is not installed!"
        Write-Host ""
        Write-Host "Please install Docker Desktop for Windows:"
        Write-Host "  https://docs.docker.com/desktop/windows/install/"
        exit 1
    }
    
    try {
        docker info | Out-Null
        if ($LASTEXITCODE -ne 0) { throw }
    }
    catch {
        Write-Error "Docker is not running!"
        Write-Host ""
        Write-Host "Please start Docker Desktop and try again."
        exit 1
    }
    
    Write-Success "Docker is installed and running"
    $dockerVersion = docker --version
    Write-Info "Docker version: $dockerVersion"
}

# Check if Docker Compose is available
function Test-DockerCompose {
    try {
        docker compose version | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Compose is available"
            $composeVersion = docker compose version
            Write-Info "Version: $composeVersion"
            return "docker compose"
        }
    }
    catch { }
    
    try {
        docker-compose --version | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Compose (standalone) is available"
            $composeVersion = docker-compose --version
            Write-Info "Version: $composeVersion"
            return "docker-compose"
        }
    }
    catch { }
    
    Write-Warning "Docker Compose not found, using Docker directly"
    return ""
}

# Setup environment file
function Set-Environment {
    Write-Info "Setting up environment configuration..."
    
    if (!(Test-Path ".env")) {
        Copy-Item ".env.example" ".env"
        Write-Success "Created .env file from template"
    }
    else {
        Write-Info ".env file already exists"
    }
    
    # Check if API token is configured
    $envContent = Get-Content ".env" -Raw -ErrorAction SilentlyContinue
    if ($envContent -match "your_tempo_api_token_here") {
        Write-Warning "TEMPO_API_TOKEN not configured in .env file"
        Write-Host ""
        Write-Host "To configure your Tempo API token:"
        Write-Host "1. Go to Tempo → Settings → API Integration"
        Write-Host "2. Create a new token with appropriate permissions"
        Write-Host "3. Edit .env file and replace 'your_tempo_api_token_here' with your token"
        Write-Host ""
        
        # Prompt user to configure now
        $response = Read-Host "Would you like to enter your API token now? (y/N)"
        if ($response -eq "y" -or $response -eq "Y") {
            $token = Read-Host "Enter your Tempo API token" -MaskInput
            if ($token) {
                $envContent = $envContent -replace "your_tempo_api_token_here", $token
                Set-Content ".env" $envContent
                Write-Success "API token configured!"
            }
        }
    }
    else {
        Write-Success "TEMPO_API_TOKEN is configured"
    }
}

# Build Docker image
function Build-DockerImage {
    Write-Info "Building Docker image..."
    
    docker build -t tempo-mcp-server:latest .
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker image built successfully"
    }
    else {
        Write-Error "Failed to build Docker image"
        exit 1
    }
}

# Test the container
function Test-Container {
    Write-Info "Testing Docker container..."
    
    # Load environment variables
    if (Test-Path ".env") {
        Get-Content ".env" | ForEach-Object {
            if ($_ -match "^([^#][^=]*)=(.*)$") {
                [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
            }
        }
    }
    
    $token = [Environment]::GetEnvironmentVariable("TEMPO_API_TOKEN", "Process")
    if (!$token -or $token -eq "your_tempo_api_token_here") {
        Write-Warning "Skipping container test - API token not configured"
        return
    }
    
    Write-Host "Testing container startup..."
    try {
        $process = Start-Process ".\docker-wrapper.ps1" -ArgumentList "--test" -PassThru -WindowStyle Hidden
        $finished = $process.WaitForExit(10000)  # 10 second timeout
        
        if ($finished -and $process.ExitCode -eq 0) {
            Write-Success "Container test passed"
        }
        else {
            if (!$finished) { $process.Kill() }
            Write-Warning "Container test failed or timed out (this might be normal if no Tempo access)"
            Write-Info "You can manually test with: .\docker-wrapper.ps1 --test"
        }
    }
    catch {
        Write-Warning "Could not run container test: $($_.Exception.Message)"
        Write-Info "You can manually test with: .\docker-wrapper.ps1 --test"
    }
}

# Generate MCP configuration
function New-MCPConfig {
    Write-Info "Generating MCP configuration examples..."
    
    $scriptPath = (Get-Location).Path + "\docker-wrapper.ps1"
    
    # Create Claude Desktop config
    $claudeConfig = @{
        mcpServers = @{
            tempo = @{
                command = "powershell"
                args = @("-File", $scriptPath, "--mcp")
                env = @{
                    TEMPO_API_TOKEN = "your_tempo_api_token_here"
                }
            }
        }
    } | ConvertTo-Json -Depth 4
    
    Set-Content "claude_desktop_config_docker_windows.json" $claudeConfig
    
    # Create VS Code config
    $vscodeConfig = @{
        servers = @{
            tempo = @{
                command = "powershell"
                args = @("-File", $scriptPath, "--mcp")
                env = @{
                    TEMPO_API_TOKEN = "your_tempo_api_token_here"
                    TEMPO_DEBUG = "false"
                }
            }
        }
    } | ConvertTo-Json -Depth 4
    
    Set-Content "vscode_mcp_docker_windows.json" $vscodeConfig
    
    Write-Success "Generated MCP configuration files"
}

# Show usage instructions
function Show-Usage {
    Write-Host ""
    Write-Header "🎉 Setup Complete!"
    Write-Host ""
    Write-Host "Your Tempo MCP Server is now containerized and ready to use on Windows!"
    Write-Host ""
    Write-Host "📋 Next Steps:"
    Write-Host ""
    Write-Host "1. Configure your Tempo API token (if not done already):"
    Write-Host "   Edit .env file and set TEMPO_API_TOKEN=your_token_here"
    Write-Host ""
    Write-Host "2. Test the server:"
    Write-Host "   .\docker-wrapper.ps1 --test"
    Write-Host ""
    Write-Host "3. Configure your MCP client:"
    Write-Host ""
    Write-Host "   For Claude Desktop:"
    Write-Host "   - Copy content from claude_desktop_config_docker_windows.json"
    Write-Host "   - Add to your Claude Desktop configuration"
    Write-Host ""
    Write-Host "   For VS Code:"
    Write-Host "   - Copy content from vscode_mcp_docker_windows.json"
    Write-Host "   - Add to your .vscode/mcp.json file"
    Write-Host ""
    Write-Host "🐳 Docker Commands:"
    Write-Host ""
    Write-Host "   Build image:        docker build -t tempo-mcp-server ."
    Write-Host "   Run server:         .\docker-wrapper.ps1"
    Write-Host "   Run with debug:     .\docker-wrapper.ps1 --test"
    Write-Host "   Force rebuild:      .\docker-wrapper.ps1 --build"
    Write-Host ""
    
    $composeCmd = Test-DockerCompose
    if ($composeCmd) {
        Write-Host "   Or use Docker Compose:"
        Write-Host "   Start:              $composeCmd up tempo-mcp-server"
        Write-Host "   Development:        $composeCmd --profile dev up tempo-mcp-dev"
        Write-Host "   Run tests:          $composeCmd --profile test up tempo-mcp-test"
        Write-Host ""
    }
    Write-Host "📖 For more information, see README.md"
    Write-Host ""
}

# Main execution
try {
    # Run setup steps
    Test-Docker
    $script:ComposeCommand = Test-DockerCompose
    Set-Environment
    
    if (!$SkipBuild) {
        Build-DockerImage
    }
    else {
        Write-Info "Skipping Docker image build"
    }
    
    if (!$SkipTest) {
        Test-Container
    }
    else {
        Write-Info "Skipping container test"
    }
    
    New-MCPConfig
    Show-Usage
}
catch {
    Write-Error "Setup failed: $($_.Exception.Message)"
    exit 1
}

# Tempo MCP Server Docker Wrapper for Windows
# This script allows MCP clients (like Claude Desktop) to run the containerized server
# while maintaining proper stdio communication on Windows.

param(
    [switch]$Help,
    [switch]$Build,
    [switch]$Test,
    [switch]$MCP
)

# Configuration
$DOCKER_IMAGE = "tempo-mcp-server:latest"
$CONTAINER_NAME = "tempo-mcp-server-$(Get-Date -Format 'yyyyMMddHHmmss')"

# Color functions for output
function Write-Log { 
    param($msg)
    if (!$MCP) { Write-Host "[Tempo MCP Docker] $msg" -ForegroundColor Green }
}

function Write-ErrorLog { 
    param($msg)
    if (!$MCP) { Write-Host "[ERROR] $msg" -ForegroundColor Red }
}

function Write-WarningLog { 
    param($msg)
    if (!$MCP) { Write-Host "[WARNING] $msg" -ForegroundColor Yellow }
}

# Function to check if Docker is running
function Test-Docker {
    try {
        $null = Get-Command docker -ErrorAction Stop
    }
    catch {
        Write-ErrorLog "Docker is not installed or not in PATH"
        exit 1
    }
    
    try {
        docker info | Out-Null
        if ($LASTEXITCODE -ne 0) { throw }
    }
    catch {
        Write-ErrorLog "Docker is not running. Please start Docker Desktop first."
        exit 1
    }
}

# Function to check if image exists
function Test-DockerImage {
    $imageExists = docker images --format "table {{.Repository}}:{{.Tag}}" | Select-String $DOCKER_IMAGE
    if (!$imageExists) {
        Write-WarningLog "Docker image $DOCKER_IMAGE not found. Building it now..."
        
        # Find the directory containing this script
        $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
        
        # Try to build the image
        if (Test-Path "$scriptDir\Dockerfile") {
            Write-Log "Building Docker image from $scriptDir..."
            Set-Location $scriptDir
            docker build -t $DOCKER_IMAGE .
            if ($LASTEXITCODE -ne 0) {
                Write-ErrorLog "Failed to build Docker image"
                exit 1
            }
        }
        else {
            Write-ErrorLog "Dockerfile not found. Please build the image manually:"
            Write-ErrorLog "  docker build -t $DOCKER_IMAGE ."
            exit 1
        }
    }
}

# Function to load environment variables
function Import-Environment {
    # Find the directory containing this script
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    
    # Check for .env file
    $envFile = Join-Path $scriptDir ".env"
    if (Test-Path $envFile) {
        # Load the .env file
        Get-Content $envFile | ForEach-Object {
            if ($_ -match "^([^#][^=]*)=(.*)$") {
                [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
            }
        }
    }
    
    # Check for required environment variables
    $token = [Environment]::GetEnvironmentVariable("TEMPO_API_TOKEN", "Process")
    if (!$token) {
        Write-ErrorLog "TEMPO_API_TOKEN environment variable is required"
        Write-ErrorLog "Please set it in your .env file or environment"
        exit 1
    }
}

# Function to cleanup on exit
function Remove-Container {
    if ($script:ContainerName) {
        try {
            docker rm -f $script:ContainerName 2>$null | Out-Null
        }
        catch { }
    }
}

# Function to run the Docker container
function Start-DockerContainer {
    param($Arguments)
    
    # Prepare environment variables for Docker
    $envArgs = @()
    
    # Pass through essential environment variables
    $token = [Environment]::GetEnvironmentVariable("TEMPO_API_TOKEN", "Process")
    if ($token) { $envArgs += @("-e", "TEMPO_API_TOKEN=$token") }
    
    $baseUrl = [Environment]::GetEnvironmentVariable("TEMPO_BASE_URL", "Process")
    if ($baseUrl) { $envArgs += @("-e", "TEMPO_BASE_URL=$baseUrl") }
    
    $debug = [Environment]::GetEnvironmentVariable("TEMPO_DEBUG", "Process")
    if ($debug) { $envArgs += @("-e", "TEMPO_DEBUG=$debug") }
    
    # Build docker run command
    $dockerArgs = @(
        "run", "--rm"
        "--name", $CONTAINER_NAME
        "-i"
    ) + $envArgs + @($DOCKER_IMAGE) + $Arguments
    
    # Run the container
    try {
        & docker @dockerArgs
    }
    catch {
        Write-ErrorLog "Failed to run Docker container: $($_.Exception.Message)"
        exit 1
    }
}

# Show help
if ($Help) {
    Write-Host "Tempo MCP Server Docker Wrapper for Windows"
    Write-Host ""
    Write-Host "Usage: .\docker-wrapper.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help          Show this help message"
    Write-Host "  -Build         Force rebuild of Docker image"
    Write-Host "  -Test          Run in test mode"
    Write-Host "  -MCP           Run in MCP mode (suppress logs)"
    Write-Host ""
    Write-Host "Environment Variables:"
    Write-Host "  TEMPO_API_TOKEN    Required: Your Tempo API token"
    Write-Host "  TEMPO_BASE_URL     Optional: Tempo API base URL"
    Write-Host "  TEMPO_DEBUG        Optional: Enable debug logging"
    Write-Host ""
    exit 0
}

# Force rebuild
if ($Build) {
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    Write-Log "Force rebuilding Docker image..."
    Set-Location $scriptDir
    docker build -t $DOCKER_IMAGE .
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Build complete!"
    }
    else {
        Write-ErrorLog "Build failed!"
        exit 1
    }
    exit 0
}

# Main execution
try {
    # Set up cleanup
    $script:ContainerName = $CONTAINER_NAME
    Register-EngineEvent PowerShell.Exiting -Action { Remove-Container }
    
    # Set test mode
    if ($Test) {
        Write-Log "Running in test mode..."
        [Environment]::SetEnvironmentVariable("TEMPO_DEBUG", "true", "Process")
    }
    
    # Perform checks
    Test-Docker
    Import-Environment
    Test-DockerImage
    
    # Run the container
    Write-Log "Starting Tempo MCP Server in Docker container..."
    Start-DockerContainer $args
}
catch {
    Write-ErrorLog "Failed to start container: $($_.Exception.Message)"
    exit 1
}
finally {
    Remove-Container
}

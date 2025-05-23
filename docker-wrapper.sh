#!/bin/bash

# Tempo MCP Server Docker Wrapper
# This script allows MCP clients (like Claude Desktop) to run the containerized server
# while maintaining proper stdio communication.

set -e

# Configuration
DOCKER_IMAGE="tempo-mcp-server:latest"
CONTAINER_NAME="tempo-mcp-server-$(date +%s)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages (only if not in MCP mode)
log() {
    if [[ "${MCP_MODE:-}" != "true" ]]; then
        echo -e "${GREEN}[Tempo MCP Docker]${NC} $1" >&2
    fi
}

error() {
    if [[ "${MCP_MODE:-}" != "true" ]]; then
        echo -e "${RED}[ERROR]${NC} $1" >&2
    fi
}

warning() {
    if [[ "${MCP_MODE:-}" != "true" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $1" >&2
    fi
}

# Function to check if Docker is running
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Function to check if image exists
check_image() {
    if ! docker image inspect "$DOCKER_IMAGE" &> /dev/null; then
        warning "Docker image $DOCKER_IMAGE not found. Building it now..."
        
        # Find the directory containing this script
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        
        # Try to build the image
        if [[ -f "$SCRIPT_DIR/Dockerfile" ]]; then
            log "Building Docker image from $SCRIPT_DIR..."
            docker build -t "$DOCKER_IMAGE" "$SCRIPT_DIR"
        else
            error "Dockerfile not found. Please build the image manually:"
            error "  docker build -t $DOCKER_IMAGE ."
            exit 1
        fi
    fi
}

# Function to load environment variables
load_env() {
    # Find the directory containing this script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Check for .env file
    if [[ -f "$SCRIPT_DIR/.env" ]]; then
        # Source the .env file but don't export everything
        set -a
        source "$SCRIPT_DIR/.env"
        set +a
    fi
    
    # Check for required environment variables
    if [[ -z "${TEMPO_API_TOKEN:-}" ]]; then
        error "TEMPO_API_TOKEN environment variable is required"
        error "Please set it in your .env file or environment"
        exit 1
    fi
}

# Function to cleanup on exit
cleanup() {
    if [[ -n "${CONTAINER_NAME:-}" ]]; then
        docker rm -f "$CONTAINER_NAME" &> /dev/null || true
    fi
}

# Function to run the Docker container
run_container() {
    # Prepare environment variables for Docker
    local env_args=""
    
    # Pass through essential environment variables
    if [[ -n "${TEMPO_API_TOKEN:-}" ]]; then
        env_args="$env_args -e TEMPO_API_TOKEN=$TEMPO_API_TOKEN"
    fi
    if [[ -n "${TEMPO_BASE_URL:-}" ]]; then
        env_args="$env_args -e TEMPO_BASE_URL=$TEMPO_BASE_URL"
    fi
    if [[ -n "${TEMPO_DEBUG:-}" ]]; then
        env_args="$env_args -e TEMPO_DEBUG=$TEMPO_DEBUG"
    fi
    
    # Run the container with stdio support
    docker run --rm \
        --name "$CONTAINER_NAME" \
        -i \
        $env_args \
        "$DOCKER_IMAGE" \
        "$@"
}

# Main execution
main() {
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Parse command line arguments
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "Tempo MCP Server Docker Wrapper"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --build        Force rebuild of Docker image"
        echo "  --test         Run in test mode"
        echo "  --mcp          Run in MCP mode (suppress logs)"
        echo ""
        echo "Environment Variables:"
        echo "  TEMPO_API_TOKEN    Required: Your Tempo API token"
        echo "  TEMPO_BASE_URL     Optional: Tempo API base URL"
        echo "  TEMPO_DEBUG        Optional: Enable debug logging"
        echo ""
        exit 0
    fi
    
    if [[ "$1" == "--build" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        log "Force rebuilding Docker image..."
        docker build -t "$DOCKER_IMAGE" "$SCRIPT_DIR"
        log "Build complete!"
        exit 0
    fi
    
    if [[ "$1" == "--mcp" ]]; then
        export MCP_MODE="true"
        shift
    fi
    
    if [[ "$1" == "--test" ]]; then
        log "Running in test mode..."
        export TEMPO_DEBUG="true"
    fi
    
    # Perform checks
    check_docker
    load_env
    check_image
    
    # Run the container
    log "Starting Tempo MCP Server in Docker container..."
    run_container "$@"
}

# Run main function
main "$@"

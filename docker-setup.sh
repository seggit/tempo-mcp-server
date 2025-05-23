#!/bin/bash

# Tempo MCP Server Docker Setup Script
# This script helps you set up the containerized Tempo MCP Server

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions for colored output
success() { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
header() { echo -e "${CYAN}🐳 $1${NC}"; }

echo ""
header "Tempo MCP Server Docker Setup"
echo "================================="

# Check if Docker is installed and running
check_docker() {
    info "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed!"
        echo ""
        echo "Please install Docker first:"
        echo "  - macOS: https://docs.docker.com/desktop/mac/install/"
        echo "  - Windows: https://docs.docker.com/desktop/windows/install/"
        echo "  - Linux: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker is not running!"
        echo ""
        echo "Please start Docker and try again."
        exit 1
    fi
    
    success "Docker is installed and running"
    info "Docker version: $(docker --version)"
}

# Check if Docker Compose is available
check_compose() {
    if docker compose version &> /dev/null; then
        success "Docker Compose is available"
        info "Version: $(docker compose version)"
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        success "Docker Compose (standalone) is available"  
        info "Version: $(docker-compose --version)"
        COMPOSE_CMD="docker-compose"
    else
        warning "Docker Compose not found, using Docker directly"
        COMPOSE_CMD=""
    fi
}

# Setup environment file
setup_env() {
    info "Setting up environment configuration..."
    
    if [[ ! -f ".env" ]]; then
        cp .env.example .env
        success "Created .env file from template"
    else
        info ".env file already exists"
    fi
    
    # Check if API token is configured
    if grep -q "your_tempo_api_token_here" .env 2>/dev/null; then
        warning "TEMPO_API_TOKEN not configured in .env file"
        echo ""
        echo "To configure your Tempo API token:"
        echo "1. Go to Tempo → Settings → API Integration"
        echo "2. Create a new token with appropriate permissions"
        echo "3. Edit .env file and replace 'your_tempo_api_token_here' with your token"
        echo ""
        
        # Prompt user to configure now
        read -p "Would you like to enter your API token now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter your Tempo API token: " -r TOKEN
            if [[ -n "$TOKEN" ]]; then
                sed -i.bak "s/your_tempo_api_token_here/$TOKEN/" .env
                rm -f .env.bak
                success "API token configured!"
            fi
        fi
    else
        success "TEMPO_API_TOKEN is configured"
    fi
}

# Build Docker image
build_image() {
    info "Building Docker image..."
    
    if docker build -t tempo-mcp-server:latest .; then
        success "Docker image built successfully"
    else
        error "Failed to build Docker image"
        exit 1
    fi
}

# Make wrapper script executable
setup_wrapper() {
    info "Setting up Docker wrapper script..."
    
    if [[ -f "docker-wrapper.sh" ]]; then
        chmod +x docker-wrapper.sh
        success "Docker wrapper script is executable"
    else
        error "docker-wrapper.sh not found"
        exit 1
    fi
}

# Test the container
test_container() {
    info "Testing Docker container..."
    
    # Load environment variables
    if [[ -f ".env" ]]; then
        source .env
    fi
    
    if [[ -z "${TEMPO_API_TOKEN:-}" ]] || [[ "${TEMPO_API_TOKEN}" == "your_tempo_api_token_here" ]]; then
        warning "Skipping container test - API token not configured"
        return
    fi
    
    echo "Testing container startup..."
    if timeout 10s ./docker-wrapper.sh --test > /dev/null 2>&1; then
        success "Container test passed"
    else
        warning "Container test failed or timed out (this might be normal if no Tempo access)"
        info "You can manually test with: ./docker-wrapper.sh --test"
    fi
}

# Generate MCP configuration
generate_mcp_config() {
    info "Generating MCP configuration examples..."
    
    SCRIPT_PATH="$(pwd)/docker-wrapper.sh"
    
    # Create Claude Desktop config
    cat > "claude_desktop_config_docker.json" << EOF
{
  "mcpServers": {
    "tempo": {
      "command": "$SCRIPT_PATH",
      "args": ["--mcp"],
      "env": {
        "TEMPO_API_TOKEN": "your_tempo_api_token_here"
      }
    }
  }
}
EOF
    
    # Create VS Code config
    cat > "vscode_mcp_docker.json" << EOF
{
  "servers": {
    "tempo": {
      "command": "$SCRIPT_PATH",
      "args": ["--mcp"],
      "env": {
        "TEMPO_API_TOKEN": "your_tempo_api_token_here",
        "TEMPO_DEBUG": "false"
      }
    }
  }
}
EOF
    
    success "Generated MCP configuration files"
}

# Show usage instructions
show_usage() {
    echo ""
    header "🎉 Setup Complete!"
    echo ""
    echo "Your Tempo MCP Server is now containerized and ready to use!"
    echo ""
    echo "📋 Next Steps:"
    echo ""
    echo "1. Configure your Tempo API token (if not done already):"
    echo "   Edit .env file and set TEMPO_API_TOKEN=your_token_here"
    echo ""
    echo "2. Test the server:"
    echo "   ./docker-wrapper.sh --test"
    echo ""
    echo "3. Configure your MCP client:"
    echo ""
    echo "   For Claude Desktop:"
    echo "   - Copy content from claude_desktop_config_docker.json"
    echo "   - Add to your Claude Desktop configuration"
    echo ""
    echo "   For VS Code:"
    echo "   - Copy content from vscode_mcp_docker.json"
    echo "   - Add to your .vscode/mcp.json file"
    echo ""
    echo "🐳 Docker Commands:"
    echo ""
    echo "   Build image:        docker build -t tempo-mcp-server ."
    echo "   Run server:         ./docker-wrapper.sh"
    echo "   Run with debug:     ./docker-wrapper.sh --test"
    echo "   Force rebuild:      ./docker-wrapper.sh --build"
    echo ""
    if [[ -n "$COMPOSE_CMD" ]]; then
        echo "   Or use Docker Compose:"
        echo "   Start:              $COMPOSE_CMD up tempo-mcp-server"
        echo "   Development:        $COMPOSE_CMD --profile dev up tempo-mcp-dev"
        echo "   Run tests:          $COMPOSE_CMD --profile test up tempo-mcp-test"
        echo ""
    fi
    echo "📖 For more information, see README.md"
    echo ""
}

# Main execution
main() {
    # Parse command line arguments
    SKIP_BUILD=false
    SKIP_TEST=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --skip-test)
                SKIP_TEST=true
                shift
                ;;
            --help|-h)
                echo "Tempo MCP Server Docker Setup"
                echo ""
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --skip-build    Skip building the Docker image"
                echo "  --skip-test     Skip testing the container"
                echo "  --help, -h      Show this help message"
                echo ""
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Run setup steps
    check_docker
    check_compose
    setup_env
    setup_wrapper
    
    if [[ "$SKIP_BUILD" != "true" ]]; then
        build_image
    else
        info "Skipping Docker image build"
    fi
    
    if [[ "$SKIP_TEST" != "true" ]]; then
        test_container
    else
        info "Skipping container test"
    fi
    
    generate_mcp_config
    show_usage
}

# Run main function
main "$@"

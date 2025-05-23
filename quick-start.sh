#!/bin/bash

# Tempo MCP Server - One-Command Setup
# This script gets you up and running in minutes!

set -e

# Colors for pretty output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "🚀 Tempo MCP Server - Quick Start"
echo "==================================="
echo -e "${NC}"

# Check if we're in the right directory
if [[ ! -f "docker-setup.sh" ]]; then
    echo -e "${RED}❌ Please run this from the tempo-mcp-server directory${NC}"
    echo "If you haven't cloned the repo yet:"
    echo "  git clone https://github.com/seggit/tempo-mcp-server.git"
    echo "  cd tempo-mcp-server"
    echo "  ./quick-start.sh"
    exit 1
fi

# Make all scripts executable
echo -e "${YELLOW}🔧 Making scripts executable...${NC}"
chmod +x docker-setup.sh docker-wrapper.sh setup.sh

# Detect preferred setup method
echo ""
echo "Choose your setup method:"
echo "1) 🐳 Docker (Recommended - Easy, consistent, isolated)"
echo "2) 🐍 Local Python (Development-friendly, direct control)"
echo ""
read -p "Enter your choice (1 or 2): " choice

case $choice in
    1)
        echo -e "${BLUE}🐳 Setting up with Docker...${NC}"
        echo ""
        ./docker-setup.sh
        ;;
    2)
        echo -e "${BLUE}🐍 Setting up with local Python...${NC}"
        echo ""
        ./setup.sh
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Please run the script again.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "🎯 Next steps:"
echo "1. Configure your Tempo API token in the .env file"
echo "2. Add the MCP server to your Claude Desktop or VS Code configuration"
echo "3. Start using natural language commands for time tracking!"
echo ""
echo "📖 See USAGE.md for examples and README.md for detailed documentation"
echo ""
echo -e "${YELLOW}💡 Quick test:${NC}"
if [[ $choice -eq 1 ]]; then
    echo "   ./docker-wrapper.sh --test"
else
    echo "   python src/tempo_mcp_server/server.py"
fi
echo ""
echo -e "${GREEN}🎉 Happy time tracking!${NC}"

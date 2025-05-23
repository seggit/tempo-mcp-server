#!/bin/bash

# Tempo MCP Server Setup Script
# This script helps you set up the Tempo MCP Server quickly

set -e

echo "🚀 Tempo MCP Server Setup"
echo "========================="

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not found. Please install Python 3.8+ first."
    exit 1
fi

echo "✅ Python found: $(python3 --version)"

# Check if we're in a virtual environment
if [[ "$VIRTUAL_ENV" == "" ]]; then
    echo "🔄 Creating virtual environment..."
    python3 -m venv venv
    echo "🔄 Activating virtual environment..."
    source venv/bin/activate
    echo "✅ Virtual environment activated"
else
    echo "✅ Already in virtual environment: $VIRTUAL_ENV"
fi

# Install dependencies
echo "🔄 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Install development dependencies if requested
if [[ "$1" == "--dev" ]]; then
    echo "🔄 Installing development dependencies..."
    pip install -r requirements-dev.txt
fi

# Install the package in development mode
echo "🔄 Installing package in development mode..."
pip install -e .

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    echo "🔄 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file and add your TEMPO_API_TOKEN"
else
    echo "✅ .env file already exists"
fi

# Check for Tempo API token
if [[ -f ".env" ]]; then
    source .env
    if [[ -z "$TEMPO_API_TOKEN" || "$TEMPO_API_TOKEN" == "your_tempo_api_token_here" ]]; then
        echo "⚠️  TEMPO_API_TOKEN not set in .env file"
        echo "   1. Go to Tempo → Settings → API Integration"
        echo "   2. Create a new token"
        echo "   3. Add it to your .env file: TEMPO_API_TOKEN=your_token_here"
    else
        echo "✅ TEMPO_API_TOKEN is configured"
    fi
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure your Tempo API token in .env file"
echo "2. Test the server: python src/tempo_mcp_server/server.py"
echo "3. Add to your MCP client configuration"
echo ""
echo "📖 See README.md for full configuration instructions"

# Run tests if in dev mode
if [[ "$1" == "--dev" ]]; then
    echo ""
    echo "🧪 Running tests..."
    pytest tests/ -v
fi

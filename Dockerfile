# Multi-stage Docker build for Tempo MCP Server
FROM python:3.11-slim as builder

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create and set working directory
WORKDIR /app

# Copy dependency files
COPY requirements.txt .
COPY pyproject.toml .

# Install Python dependencies
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Production stage
FROM python:3.11-slim as production

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/home/mcpuser/.local/bin:$PATH"

# Create non-root user for security
RUN groupadd --gid 1000 mcpuser && \
    useradd --uid 1000 --gid mcpuser --shell /bin/bash --create-home mcpuser

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Python dependencies from builder stage
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY src/ ./src/
COPY pyproject.toml .
COPY README.md .
COPY LICENSE .

# Install the application
RUN pip install -e .

# Change ownership to non-root user
RUN chown -R mcpuser:mcpuser /app

# Switch to non-root user
USER mcpuser

# Create directory for logs
RUN mkdir -p /home/mcpuser/logs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import tempo_mcp_server; print('OK')" || exit 1

# Expose port for HTTP transport (if needed)
EXPOSE 8000

# Default command - run the MCP server
CMD ["python", "-m", "tempo_mcp_server"]

# Labels for metadata
LABEL maintainer="Tempo MCP Server Team" \
      version="0.1.0" \
      description="MCP Server for Tempo Cloud API integration" \
      org.opencontainers.image.source="https://github.com/seggit/tempo-mcp-server"

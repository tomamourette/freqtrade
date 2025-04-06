# Freqtrade Dockerfile - Simplified Single Stage
# Use an official Python runtime as a parent image
FROM python:3.12.9-slim-bookworm

# Set environment variables
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1
ENV FT_APP_ENV="docker"

# Install OS dependencies + build tools + git + TA-Lib dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    git \
    libffi-dev \
    libatlas3-base \
    curl \
    sqlite3 \
    libgomp1 \
    wget \
    tar \
    pkg-config \
    cmake \
    gcc \
  && rm -rf /var/lib/apt/lists/*

# Download and install ta-lib C library
WORKDIR /tmp
RUN wget http://prdownloads.sourceforge.net/ta-lib/ta-lib-0.4.0-src.tar.gz && \
    tar -xvzf ta-lib-0.4.0-src.tar.gz && \
    cd ta-lib/ && \
    ./configure --prefix=/usr && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/*

# Create user and directories
RUN useradd -u 1000 -U -m -s /bin/bash ftuser && \
    mkdir /freqtrade && \
    chown ftuser:ftuser /freqtrade

# Switch to non-root user
USER ftuser
WORKDIR /freqtrade

# Add .local/bin to path AFTER switching user
ENV PATH=/home/ftuser/.local/bin:$PATH

# Copy application code (including user_data/config.json if tracked by git)
COPY --chown=ftuser:ftuser . /freqtrade/

# --- DIAGNOSTIC STEP ---
# List files after copy to see if user_data and config.json are present
RUN ls -la /freqtrade/ && ls -la /freqtrade/user_data/ || echo "user_data not found by ls"
# --- END DIAGNOSTIC STEP ---

# Install python dependencies (including freqtrade itself in editable mode)
# Ensure requirements*.txt and pyproject.toml were copied above
RUN pip install --user --no-cache-dir --upgrade pip wheel && \
    pip install --user --no-cache-dir "numpy<2.0" && \
    pip install --user --no-cache-dir -r requirements.txt && \
    pip install --user --no-cache-dir -r requirements-hyperopt.txt && \
    pip install -e . --user --no-cache-dir --no-build-isolation && \
    freqtrade install-ui

# Expose ports
EXPOSE 8080
EXPOSE 9090

# Set entrypoint
ENTRYPOINT ["freqtrade"]

# Default command (points to config inside user_data)
CMD [ "trade", "--config", "user_data/config.json" ]
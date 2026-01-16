#!/bin/bash

###############################################################################
# Traffic Generator - Continuous HTTP requests to health endpoint
###############################################################################

set -euo pipefail

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "${SCRIPT_DIR}/../lib/common.sh"

# Traffic configuration
: "${BASE_URL:=http://localhost:8080}"
: "${HEALTH_ENDPOINT:=/api/health}"
: "${CHECK_INTERVAL:=1}"
: "${REQUEST_TIMEOUT:=5}"

# Build full health check URL
HEALTH_URL="${BASE_URL}${HEALTH_ENDPOINT}"

###############################################################################
# Traffic loop - Single worker
###############################################################################

traffic_loop() {
    local worker_id=${1:-1}
    
    log_debug "Worker ${worker_id} démarré"
    
    while true; do
        local timestamp=$(date +%s)
        local http_code
        local curl_exit_code
        
        # Perform HTTP request with timeout
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time "${REQUEST_TIMEOUT}" \
            --connect-timeout "${REQUEST_TIMEOUT}" \
            "${HEALTH_URL}" 2>/dev/null) || curl_exit_code=$?
        
        # Log result
        if [[ "${http_code}" == "200" ]]; then
            echo "[${timestamp}] WORKER=${worker_id} HTTP_STATUS=200 URL=${HEALTH_URL} OK"
        else
            echo "[${timestamp}] WORKER=${worker_id} HTTP_STATUS=${http_code:-000} URL=${HEALTH_URL} FAILED (curl_exit=${curl_exit_code:-0})"
        fi
        
        # Wait before next request
        sleep "${CHECK_INTERVAL}"
    done
}

###############################################################################
# Main
###############################################################################

main() {
    log_info "Démarrage du générateur de trafic..."
    log_info "URL cible: ${HEALTH_URL}"
    log_info "Intervalle: ${CHECK_INTERVAL}s"
    
    # Start traffic loop
    traffic_loop 1
}

# Run main function
main

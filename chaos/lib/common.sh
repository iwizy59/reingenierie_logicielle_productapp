#!/bin/bash

###############################################################################
# Common utilities for Chaos Testing
###############################################################################

# Fail fast
set -euo pipefail

# Configuration par défaut
: "${NAMESPACE:=productapp}"
: "${BACKEND_DEPLOYMENT:=backend-deployment}"
: "${FRONTEND_SERVICE:=frontend-service}"
: "${BACKEND_SERVICE:=backend-service}"
: "${BASE_URL:=http://localhost:8080}"
: "${PORT_FORWARD_PORT:=8080}"
: "${TEST_DURATION:=60}"
: "${CHECK_INTERVAL:=1}"
: "${SUCCESS_THRESHOLD:=95}"
: "${MAX_DOWNTIME:=10}"
: "${HEALTH_ENDPOINT:=/api/health}"
: "${DRY_RUN:=false}"
: "${VERBOSE:=false}"

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Determine chaos root directory
readonly CHAOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Fichiers de logs et PIDs
readonly LOG_DIR="${CHAOS_ROOT}/logs"
readonly PID_DIR="${CHAOS_ROOT}/logs"

# Créer le dossier logs s'il n'existe pas
mkdir -p "${LOG_DIR}"

###############################################################################
# Logging functions
###############################################################################

log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[${timestamp}]${NC} $1"
}

log_warn() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[${timestamp}]${NC} ⚠️  $1"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[${timestamp}]${NC} ❌ $1" >&2
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[${timestamp}]${NC} ✓ $1"
}

log_chaos() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${MAGENTA}[${timestamp}]${NC} ⚡ $1"
}

log_debug() {
    if [[ "${VERBOSE}" == "true" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${CYAN}[${timestamp}]${NC} 🐛 $1"
    fi
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_summary() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

###############################################################################
# Prerequisites checks
###############################################################################

check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl n'est pas installé"
        exit 1
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        log_error "curl n'est pas installé"
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Impossible de se connecter au cluster Kubernetes"
        exit 1
    fi
    
    # Check namespace exists
    if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        log_error "Le namespace '${NAMESPACE}' n'existe pas"
        exit 1
    fi
    
    # Check backend deployment exists
    if ! kubectl get deployment "${BACKEND_DEPLOYMENT}" -n "${NAMESPACE}" &> /dev/null; then
        log_error "Le deployment '${BACKEND_DEPLOYMENT}' n'existe pas dans le namespace '${NAMESPACE}'"
        exit 1
    fi
    
    # Check frontend service exists
    if ! kubectl get service "${FRONTEND_SERVICE}" -n "${NAMESPACE}" &> /dev/null; then
        log_error "Le service '${FRONTEND_SERVICE}' n'existe pas dans le namespace '${NAMESPACE}'"
        exit 1
    fi
    
    log_success "Prérequis validés"
}

###############################################################################
# Port-forward management
###############################################################################

start_port_forward() {
    local pid_file="${PID_DIR}/chaos-port-forward.pid"
    
    # Check if port-forward already running
    if [[ -f "${pid_file}" ]]; then
        local pid=$(cat "${pid_file}")
        if ps -p "${pid}" > /dev/null 2>&1; then
            log_debug "Port-forward déjà actif (PID: ${pid})"
            return 0
        else
            rm -f "${pid_file}"
        fi
    fi
    
    # Check if port is already in use
    if lsof -ti:"${PORT_FORWARD_PORT}" &> /dev/null; then
        log_warn "Le port ${PORT_FORWARD_PORT} est déjà utilisé, tentative de libération..."
        lsof -ti:"${PORT_FORWARD_PORT}" | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] kubectl port-forward -n ${NAMESPACE} svc/${FRONTEND_SERVICE} ${PORT_FORWARD_PORT}:80"
        echo "12345" > "${pid_file}"
        return 0
    fi
    
    # Start port-forward in background
    kubectl port-forward -n "${NAMESPACE}" "svc/${FRONTEND_SERVICE}" "${PORT_FORWARD_PORT}:80" > /dev/null 2>&1 &
    local pid=$!
    echo "${pid}" > "${pid_file}"
    
    # Wait for port-forward to be ready
    local max_attempts=10
    local attempt=0
    while ! curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/health" > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [[ ${attempt} -ge ${max_attempts} ]]; then
            log_error "Timeout lors du démarrage du port-forward"
            stop_port_forward
            exit 1
        fi
        sleep 1
    done
    
    log_success "Port-forward démarré (PID: ${pid}, localhost:${PORT_FORWARD_PORT})"
}

stop_port_forward() {
    local pid_file="${PID_DIR}/chaos-port-forward.pid"
    
    if [[ -f "${pid_file}" ]]; then
        local pid=$(cat "${pid_file}")
        if ps -p "${pid}" > /dev/null 2>&1; then
            if [[ "${DRY_RUN}" == "true" ]]; then
                log_info "[DRY-RUN] kill ${pid}"
            else
                kill "${pid}" 2>/dev/null || true
                log_debug "Port-forward arrêté (PID: ${pid})"
            fi
        fi
        rm -f "${pid_file}"
    fi
    
    # Cleanup any remaining port-forwards
    pkill -f "kubectl port-forward.*${FRONTEND_SERVICE}" 2>/dev/null || true
}

###############################################################################
# Traffic generation management
###############################################################################

start_traffic() {
    local log_file="${LOG_DIR}/chaos-traffic-$(date +%Y%m%d-%H%M%S).log"
    local pid_file="${PID_DIR}/chaos-traffic.pid"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Démarrage du générateur de trafic"
        echo "12346" > "${pid_file}"
        echo "${log_file}" > "${PID_DIR}/chaos-traffic-log.txt"
        return 0
    fi
    
    # Start traffic generator
    bash "$(dirname "${BASH_SOURCE[0]}")/../traffic/traffic.sh" > "${log_file}" 2>&1 &
    local pid=$!
    echo "${pid}" > "${pid_file}"
    echo "${log_file}" > "${PID_DIR}/chaos-traffic-log.txt"
    
    sleep 2
    
    if ps -p "${pid}" > /dev/null 2>&1; then
        log_success "Générateur de trafic démarré (PID: ${pid}, logs: ${log_file})"
    else
        log_error "Échec du démarrage du générateur de trafic"
        cat "${log_file}"
        exit 1
    fi
}

stop_traffic() {
    local pid_file="${PID_DIR}/chaos-traffic.pid"
    local log_ref="${PID_DIR}/chaos-traffic-log.txt"
    
    if [[ -f "${pid_file}" ]]; then
        local pid=$(cat "${pid_file}")
        if ps -p "${pid}" > /dev/null 2>&1; then
            if [[ "${DRY_RUN}" == "true" ]]; then
                log_info "[DRY-RUN] kill ${pid}"
            else
                kill "${pid}" 2>/dev/null || true
                # Kill child processes too
                pkill -P "${pid}" 2>/dev/null || true
                log_debug "Générateur de trafic arrêté (PID: ${pid})"
            fi
        fi
        rm -f "${pid_file}"
    fi
    
    # Cleanup log reference file
    rm -f "${log_ref}"
}

###############################################################################
# Kubernetes operations
###############################################################################

get_backend_replicas() {
    kubectl get deployment "${BACKEND_DEPLOYMENT}" -n "${NAMESPACE}" \
        -o jsonpath='{.spec.replicas}'
}

scale_backend() {
    local replicas=$1
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] kubectl scale deployment ${BACKEND_DEPLOYMENT} -n ${NAMESPACE} --replicas=${replicas}"
        return 0
    fi
    
    kubectl scale deployment "${BACKEND_DEPLOYMENT}" -n "${NAMESPACE}" --replicas="${replicas}"
    log_info "Backend scalé à ${replicas} replica(s)"
}

get_random_backend_pod() {
    kubectl get pods -n "${NAMESPACE}" -l "app=backend" \
        -o jsonpath='{.items[0].metadata.name}'
}

delete_pod() {
    local pod_name=$1
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] kubectl delete pod ${pod_name} -n ${NAMESPACE}"
        return 0
    fi
    
    kubectl delete pod "${pod_name}" -n "${NAMESPACE}" --grace-period=0 --force 2>/dev/null || true
    log_chaos "Suppression du pod ${pod_name}"
}

wait_for_pod_ready() {
    local label_selector=$1
    local timeout=${2:-60}
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] kubectl wait --for=condition=ready pod -l ${label_selector} -n ${NAMESPACE}"
        return 0
    fi
    
    kubectl wait --for=condition=ready pod \
        -l "${label_selector}" \
        -n "${NAMESPACE}" \
        --timeout="${timeout}s" > /dev/null 2>&1
}

get_backend_ready_pods() {
    kubectl get pods -n "${NAMESPACE}" -l "app=backend" \
        --field-selector=status.phase=Running \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null \
        | while read pod; do
            kubectl get pod "$pod" -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True" && echo "$pod"
        done | wc -l | tr -d ' '
}

###############################################################################
# Metrics collection
###############################################################################

collect_metrics() {
    local log_file=$1
    local duration=$2
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        # Fake metrics for dry-run
        echo "60 58 2 4 10"
        return 0
    fi
    
    if [[ ! -f "${log_file}" ]]; then
        log_error "Fichier de logs introuvable: ${log_file}"
        echo "0 0 0 0 0"
        return 1
    fi
    
    # Analyse des logs
    local total_checks=$(grep -c "HTTP_STATUS" "${log_file}" || echo "0")
    local success_checks=$(grep "HTTP_STATUS=200" "${log_file}" | wc -l || echo "0")
    local failed_checks=$((total_checks - success_checks))
    
    # Calcul de la plus longue panne (séquence consécutive d'échecs)
    local max_consecutive_failures=0
    local current_consecutive=0
    
    while IFS= read -r line; do
        if echo "${line}" | grep -q "HTTP_STATUS=200"; then
            current_consecutive=0
        else
            current_consecutive=$((current_consecutive + 1))
            if [[ ${current_consecutive} -gt ${max_consecutive_failures} ]]; then
                max_consecutive_failures=${current_consecutive}
            fi
        fi
    done < <(grep "HTTP_STATUS" "${log_file}")
    
    local max_downtime=$((max_consecutive_failures * CHECK_INTERVAL))
    
    # Calcul du temps de recovery (premier succès après le premier échec)
    local first_failure_ts=$(grep -v "HTTP_STATUS=200" "${log_file}" | head -1 | grep -oE '[0-9]{10}' || echo "0")
    local first_success_after_failure_ts=$(grep "HTTP_STATUS=200" "${log_file}" | \
        awk -v ts="${first_failure_ts}" '$0 ~ ts {found=1; next} found {print; exit}' | \
        grep -oE '[0-9]{10}' || echo "${first_failure_ts}")
    
    local recovery_time=0
    if [[ ${first_failure_ts} -gt 0 ]] && [[ ${first_success_after_failure_ts} -gt ${first_failure_ts} ]]; then
        recovery_time=$((first_success_after_failure_ts - first_failure_ts))
    fi
    
    echo "${total_checks} ${success_checks} ${failed_checks} ${max_downtime} ${recovery_time}"
}

print_metrics_summary() {
    local total=$1
    local success=$2
    local failed=$3
    local max_downtime=$4
    local recovery_time=$5
    
    print_summary "RÉSUMÉ DE L'EXPÉRIENCE"
    
    local success_rate=0
    if [[ ${total} -gt 0 ]]; then
        success_rate=$(awk "BEGIN {printf \"%.2f\", (${success} / ${total}) * 100}")
    fi
    
    local failed_rate=0
    if [[ ${total} -gt 0 ]]; then
        failed_rate=$(awk "BEGIN {printf \"%.2f\", (${failed} / ${total}) * 100}")
    fi
    
    echo "Durée totale          : ${TEST_DURATION}s"
    echo "Checks effectués      : ${total}"
    echo "Succès                : ${success} (${success_rate}%)"
    echo "Échecs                : ${failed} (${failed_rate}%)"
    echo "Plus longue panne     : ${max_downtime}s"
    echo "Temps de recovery     : ${recovery_time}s"
    echo ""
    echo "Seuils:"
    
    local availability_pass=false
    local downtime_pass=false
    
    if awk "BEGIN {exit !(${success_rate} >= ${SUCCESS_THRESHOLD})}"; then
        echo -e "  ${GREEN}✓${NC} Disponibilité ≥ ${SUCCESS_THRESHOLD}%     : PASS (${success_rate}%)"
        availability_pass=true
    else
        echo -e "  ${RED}✗${NC} Disponibilité ≥ ${SUCCESS_THRESHOLD}%     : FAIL (${success_rate}%)"
    fi
    
    if [[ ${max_downtime} -le ${MAX_DOWNTIME} ]]; then
        echo -e "  ${GREEN}✓${NC} Indispo max ≤ ${MAX_DOWNTIME}s       : PASS (${max_downtime}s)"
        downtime_pass=true
    else
        echo -e "  ${RED}✗${NC} Indispo max ≤ ${MAX_DOWNTIME}s       : FAIL (${max_downtime}s)"
    fi
    
    echo ""
    
    if [[ "${availability_pass}" == "true" ]] && [[ "${downtime_pass}" == "true" ]]; then
        print_header "RÉSULTAT FINAL: PASS ✓"
        return 0
    else
        print_header "RÉSULTAT FINAL: FAIL ✗"
        return 1
    fi
}

###############################################################################
# Cleanup trap
###############################################################################

cleanup() {
    local exit_code=$?
    
    log_info "Nettoyage en cours..."
    
    stop_traffic
    
    # Note: Ne pas arrêter le port-forward pour laisser l'accès à l'application
    # stop_port_forward
    
    # Restore original replicas if needed
    if [[ -f "${PID_DIR}/chaos-original-replicas.txt" ]]; then
        local original_replicas=$(cat "${PID_DIR}/chaos-original-replicas.txt")
        scale_backend "${original_replicas}"
        rm -f "${PID_DIR}/chaos-original-replicas.txt"
    fi
    
    # Cleanup PID files (sauf port-forward)
    rm -f "${PID_DIR}"/chaos-traffic*.pid
    rm -f "${PID_DIR}/chaos-traffic-log.txt"
    
    log_success "Nettoyage terminé"
    
    exit ${exit_code}
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

###############################################################################
# Utility functions
###############################################################################

wait_seconds() {
    local seconds=$1
    local message=${2:-"Attente"}
    
    for ((i=seconds; i>0; i--)); do
        echo -ne "${message} ${i}s...\r"
        sleep 1
    done
    echo -e "${message} terminé.     "
}

#!/bin/bash

###############################################################################
# Chaos Experiment: Scale Backend Down and Up
#
# Objectif: Valider que l'API reste disponible lors d'une réduction temporaire
#           de capacité (scale down puis scale up)
#
# Scénario:
#   1. Démarrer le monitoring (trafic continu)
#   2. Lire le nombre de replicas initial
#   3. Scaler à 1 replica pendant 30s
#   4. Scaler retour à la valeur initiale
#   5. Valider que l'API est restée disponible selon les seuils
#
# Seuils de succès:
#   - Disponibilité ≥ 95%
#   - Indisponibilité maximale continue ≤ 10s
###############################################################################

set -euo pipefail

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "${SCRIPT_DIR}/../lib/common.sh"

# Experiment configuration
: "${SCALE_DOWN_REPLICAS:=1}"
: "${SCALE_DOWN_DURATION:=30}"

###############################################################################
# Experiment logic
###############################################################################

run_experiment() {
    print_header "CHAOS EXPERIMENT: Scale Backend Down/Up"
    
    # 1. Prerequisites
    check_prerequisites
    
    # 2. Start port-forward
    start_port_forward
    
    # 3. Start traffic generator
    start_traffic
    
    # 4. Wait for baseline
    log_info "Établissement du trafic de base..."
    wait_seconds 10 "Baseline"
    
    # 5. Get initial state
    local initial_replicas=$(get_backend_replicas)
    local initial_ready_pods=$(get_backend_ready_pods)
    log_info "État initial: ${initial_ready_pods}/${initial_replicas} pods backend ready"
    
    # Save original replicas for cleanup
    echo "${initial_replicas}" > "${PID_DIR}/chaos-original-replicas.txt"
    
    # 6. Validate scale down target
    if [[ ${SCALE_DOWN_REPLICAS} -ge ${initial_replicas} ]]; then
        log_error "SCALE_DOWN_REPLICAS (${SCALE_DOWN_REPLICAS}) doit être < replicas initial (${initial_replicas})"
        exit 1
    fi
    
    # 7. Inject chaos - Scale down
    log_chaos "Injection de chaos: scale backend ${initial_replicas} → ${SCALE_DOWN_REPLICAS}"
    local scale_down_time=$(date +%s)
    scale_backend "${SCALE_DOWN_REPLICAS}"
    
    # 8. Wait for scale down to complete
    log_info "Attente de la stabilisation du scale down..."
    sleep 5
    
    local scaled_ready_pods=$(get_backend_ready_pods)
    log_info "Après scale down: ${scaled_ready_pods} pods ready"
    
    # 9. Maintain scaled down state
    log_info "Maintien de l'état scalé pendant ${SCALE_DOWN_DURATION}s..."
    wait_seconds ${SCALE_DOWN_DURATION} "État réduit"
    
    # 10. Scale back up
    log_chaos "Scale up: ${SCALE_DOWN_REPLICAS} → ${initial_replicas}"
    local scale_up_time=$(date +%s)
    scale_backend "${initial_replicas}"
    
    # 11. Wait for scale up to complete
    log_info "Attente de la stabilisation du scale up..."
    local max_wait=60
    local elapsed=0
    local recovered=false
    
    while [[ ${elapsed} -lt ${max_wait} ]]; do
        local ready_pods=$(get_backend_ready_pods)
        
        if [[ ${ready_pods} -ge ${initial_replicas} ]]; then
            log_success "Scale up terminé: ${ready_pods}/${initial_replicas} pods ready"
            recovered=true
            break
        fi
        
        log_debug "Pods ready: ${ready_pods}/${initial_replicas}"
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    if [[ "${recovered}" == "false" ]]; then
        log_warn "Timeout: le scale up a pris plus de ${max_wait}s"
    fi
    
    local recovery_complete_time=$(date +%s)
    local recovery_duration=$((recovery_complete_time - scale_down_time))
    log_info "Durée totale (scale down → scale up → stable): ${recovery_duration}s"
    
    # 12. Continue monitoring for remaining test duration
    local elapsed_total=$((10 + SCALE_DOWN_DURATION + elapsed))
    local remaining=$((TEST_DURATION - elapsed_total))
    if [[ ${remaining} -gt 0 ]]; then
        log_info "Poursuite du monitoring pour ${remaining}s..."
        wait_seconds ${remaining} "Monitoring"
    fi
    
    # 13. Stop traffic and collect metrics
    log_info "Arrêt du trafic et collecte des métriques..."
    stop_traffic
    sleep 2
    
    # 14. Analyze results
    local traffic_log
    if [[ -f "${PID_DIR}/chaos-traffic-log.txt" ]]; then
        traffic_log=$(cat "${PID_DIR}/chaos-traffic-log.txt")
    else
        log_error "Fichier de référence des logs introuvable"
        # Fallback: chercher le dernier fichier de log dans LOG_DIR
        traffic_log=$(ls -t "${LOG_DIR}"/chaos-traffic-*.log 2>/dev/null | head -1)
    fi
    
    if [[ ! -f "${traffic_log}" ]]; then
        log_error "Fichier de logs du trafic introuvable: ${traffic_log}"
        exit 1
    fi
    
    read -r total success failed max_downtime recovery_time < <(collect_metrics "${traffic_log}" "${TEST_DURATION}")
    
    # 15. Print summary and determine pass/fail
    print_metrics_summary "${total}" "${success}" "${failed}" "${max_downtime}" "${recovery_time}"
    
    local result=$?
    
    # 16. Save detailed log
    local experiment_log="${LOG_DIR}/chaos-scale-down-up-$(date +%Y%m%d-%H%M%S).log"
    cp "${traffic_log}" "${experiment_log}"
    log_info "Logs détaillés: ${experiment_log}"
    
    # 17. Cleanup (restore replicas)
    rm -f "${PID_DIR}/chaos-original-replicas.txt"
    
    return ${result}
}

###############################################################################
# Main
###############################################################################

main() {
    # Run experiment
    if run_experiment; then
        exit 0
    else
        exit 1
    fi
}

# Execute
main

#!/bin/bash

###############################################################################
# Chaos Experiment: Kill One Backend Pod
#
# Objectif: Valider que l'API reste disponible si une instance backend tombe
#
# Scénario:
#   1. Démarrer le monitoring (trafic continu)
#   2. Sélectionner un pod backend au hasard
#   3. Supprimer ce pod
#   4. Attendre que Kubernetes le recrée
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

###############################################################################
# Experiment logic
###############################################################################

run_experiment() {
    print_header "CHAOS EXPERIMENT: Kill Backend Pod"
    
    # 1. Prerequisites
    check_prerequisites
    
    # 2. Start port-forward
    start_port_forward
    
    # 3. Start traffic generator
    start_traffic
    
    # 4. Wait for baseline (let traffic establish)
    log_info "Établissement du trafic de base..."
    wait_seconds 10 "Baseline"
    
    # 5. Get current backend state
    local initial_replicas=$(get_backend_replicas)
    local initial_ready_pods=$(get_backend_ready_pods)
    log_info "État initial: ${initial_ready_pods}/${initial_replicas} pods backend ready"
    
    # 6. Select random backend pod
    local target_pod=$(get_random_backend_pod)
    if [[ -z "${target_pod}" ]]; then
        log_error "Aucun pod backend trouvé"
        exit 1
    fi
    
    log_info "Pod cible sélectionné: ${target_pod}"
    
    # 7. Inject chaos - Delete pod
    log_chaos "Injection de chaos: suppression du pod ${target_pod}"
    local chaos_injection_time=$(date +%s)
    delete_pod "${target_pod}"
    
    # 8. Monitor recovery
    log_info "Monitoring de la récupération..."
    local max_wait=60
    local elapsed=0
    local recovered=false
    
    while [[ ${elapsed} -lt ${max_wait} ]]; do
        local ready_pods=$(get_backend_ready_pods)
        
        if [[ ${ready_pods} -ge ${initial_ready_pods} ]]; then
            log_success "Récupération complète: ${ready_pods}/${initial_replicas} pods ready"
            recovered=true
            break
        fi
        
        log_debug "Pods ready: ${ready_pods}/${initial_replicas}"
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    if [[ "${recovered}" == "false" ]]; then
        log_error "Timeout: la récupération a pris plus de ${max_wait}s"
    fi
    
    local recovery_complete_time=$(date +%s)
    local recovery_duration=$((recovery_complete_time - chaos_injection_time))
    log_info "Durée de récupération: ${recovery_duration}s"
    
    # 9. Continue monitoring for full test duration
    local remaining=$((TEST_DURATION - 10 - elapsed))
    if [[ ${remaining} -gt 0 ]]; then
        log_info "Poursuite du monitoring pour ${remaining}s..."
        wait_seconds ${remaining} "Monitoring"
    fi
    
    # 10. Stop traffic and collect metrics
    log_info "Arrêt du trafic et collecte des métriques..."
    stop_traffic
    sleep 2
    
    # 11. Analyze results
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
    
    # 12. Print summary and determine pass/fail
    print_metrics_summary "${total}" "${success}" "${failed}" "${max_downtime}" "${recovery_time}"
    
    local result=$?
    
    # 13. Save detailed log
    local experiment_log="${LOG_DIR}/chaos-kill-pod-$(date +%Y%m%d-%H%M%S).log"
    cp "${traffic_log}" "${experiment_log}"
    log_info "Logs détaillés: ${experiment_log}"
    
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

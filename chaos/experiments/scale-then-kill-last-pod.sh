#!/bin/bash

###############################################################################
# Chaos Experiment: Scale to 1 then Kill Last Pod
#
# Objectif: Tester la résilience extrême - scale à 1 pod puis tuer ce dernier
#
# Scénario:
#   1. Scale backend de 2 → 1 réplica
#   2. Attendre la stabilisation
#   3. Démarrer le monitoring avec trafic continu
#   4. Supprimer le dernier pod restant (downtime total)
#   5. Observer la récupération automatique
#   6. Remettre à 2 réplicas
#
# Seuils de succès:
#   - Récupération < 60s après le kill
#   - Système redevient opérationnel
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
    print_header "CHAOS EXPERIMENT: Scale to 1 then Kill Last Pod"
    
    # 1. Prerequisites
    check_prerequisites
    
    # 2. Get initial state
    local initial_replicas=$(get_backend_replicas)
    log_info "État initial: ${initial_replicas} réplicas backend"
    
    # Save initial state for cleanup
    echo "${initial_replicas}" > "${PID_DIR}/chaos-original-replicas.txt"
    
    # 3. Scale down to 1 replica
    log_chaos "PHASE 1: Scale backend ${initial_replicas} → 1 réplica"
    scale_backend 1
    
    log_info "Attente de la stabilisation du scale down..."
    local max_wait=30
    local elapsed=0
    
    while [[ ${elapsed} -lt ${max_wait} ]]; do
        local ready_pods=$(get_backend_ready_pods)
        local running_pods=$(kubectl get pods -n ${NAMESPACE} -l app=backend --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
        
        if [[ ${ready_pods} -eq 1 ]] && [[ ${running_pods} -eq 1 ]]; then
            log_success "Scale down terminé: 1 pod ready"
            break
        fi
        
        log_debug "État: ${running_pods} running, ${ready_pods} ready"
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    # 4. Get the last pod standing
    local target_pod=$(get_random_backend_pod)
    if [[ -z "${target_pod}" ]]; then
        log_error "Aucun pod backend trouvé après scale down"
        exit 1
    fi
    
    log_info "Dernier pod survivant: ${target_pod}"
    
    # 5. Start port-forward
    start_port_forward
    
    # 6. Start traffic generator
    start_traffic
    
    # 7. Wait for baseline
    log_info "Établissement du trafic de base avec 1 seul pod..."
    wait_seconds 10 "Baseline"
    
    # 8. Inject EXTREME chaos - Kill the last pod
    log_chaos "PHASE 2: Kill du dernier pod → DOWNTIME TOTAL"
    local chaos_injection_time=$(date +%s)
    delete_pod "${target_pod}"
    
    log_warn "⚠️  Plus AUCUN pod backend disponible!"
    
    # 9. Monitor recovery
    log_info "Monitoring de la récupération automatique..."
    local max_recovery_wait=60
    local recovery_elapsed=0
    local recovered=false
    
    while [[ ${recovery_elapsed} -lt ${max_recovery_wait} ]]; do
        local ready_pods=$(get_backend_ready_pods)
        
        if [[ ${ready_pods} -ge 1 ]]; then
            log_success "Pod recréé et ready!"
            recovered=true
            break
        fi
        
        log_debug "Pods ready: ${ready_pods} (attente de la recréation...)"
        sleep 2
        recovery_elapsed=$((recovery_elapsed + 2))
    done
    
    local recovery_complete_time=$(date +%s)
    local recovery_duration=$((recovery_complete_time - chaos_injection_time))
    
    if [[ "${recovered}" == "false" ]]; then
        log_error "ÉCHEC: Pas de récupération après ${max_recovery_wait}s"
    else
        log_info "Durée de récupération: ${recovery_duration}s"
    fi
    
    # 10. Continue monitoring
    local remaining=$((TEST_DURATION - 10 - recovery_elapsed))
    if [[ ${remaining} -gt 0 ]]; then
        log_info "Poursuite du monitoring pour ${remaining}s..."
        wait_seconds ${remaining} "Monitoring"
    fi
    
    # 11. Stop traffic
    log_info "Arrêt du trafic et collecte des métriques..."
    stop_traffic
    sleep 2
    
    # 12. Restore to original scale
    log_info "PHASE 3: Remise à l'échelle normale (${initial_replicas} réplicas)..."
    scale_backend ${initial_replicas}
    
    # Clean up the original replicas file since we're manually restoring
    rm -f "${PID_DIR}/chaos-original-replicas.txt"
    
    wait_seconds 10 "Stabilisation"
    
    local final_ready=$(get_backend_ready_pods)
    log_info "État final: ${final_ready}/${initial_replicas} pods ready"
    
    # 13. Analyze results
    local traffic_log
    if [[ -f "${PID_DIR}/chaos-traffic-log.txt" ]]; then
        traffic_log=$(cat "${PID_DIR}/chaos-traffic-log.txt")
    else
        traffic_log=$(ls -t "${LOG_DIR}"/chaos-traffic-*.log 2>/dev/null | head -1)
    fi
    
    if [[ ! -f "${traffic_log}" ]]; then
        log_error "Fichier de logs du trafic introuvable"
        exit 1
    fi
    
    read -r total success failed max_downtime recovery_time < <(collect_metrics "${traffic_log}" "${TEST_DURATION}")
    
    # 14. Print summary
    echo ""
    print_header "RÉSUMÉ - CHAOS EXTRÊME"
    echo "Durée totale récupération : ${recovery_duration}s"
    echo "Downtime maximum observé  : ${max_downtime}s"
    echo ""
    
    print_metrics_summary "${total}" "${success}" "${failed}" "${max_downtime}" "${recovery_time}"
    
    local result=$?
    
    # 15. Save detailed log
    local experiment_log="${LOG_DIR}/chaos-scale-kill-$(date +%Y%m%d-%H%M%S).log"
    cp "${traffic_log}" "${experiment_log}"
    log_info "Logs détaillés: ${experiment_log}"
    
    # Success criteria for this extreme test
    if [[ "${recovered}" == "true" ]] && [[ ${recovery_duration} -lt 60 ]]; then
        log_success "SUCCÈS: Le système a survécu au chaos extrême!"
        return 0
    else
        log_error "ÉCHEC: Récupération trop lente ou impossible"
        return 1
    fi
}

###############################################################################
# Main
###############################################################################

main() {
    if run_experiment; then
        exit 0
    else
        exit 1
    fi
}

# Execute
main

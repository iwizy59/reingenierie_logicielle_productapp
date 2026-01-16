#!/bin/bash

###############################################################################
# Chaos Experiment: Custom Example
#
# Template pour créer vos propres expériences de chaos
#
# Copiez ce fichier et modifiez inject_chaos() selon vos besoins
###############################################################################

set -euo pipefail

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "${SCRIPT_DIR}/../lib/common.sh"

###############################################################################
# Configuration spécifique à cette expérience
###############################################################################

: "${CUSTOM_PARAM:=default_value}"

###############################################################################
# Experiment logic
###############################################################################

inject_chaos() {
    log_chaos "INSÉREZ ICI VOTRE LOGIQUE DE CHAOS"
    
    # Exemples d'injections de chaos:
    
    # 1. Tuer plusieurs pods
    # local pods=$(kubectl get pods -n productapp -l app=backend -o name | head -2)
    # for pod in $pods; do
    #     kubectl delete $pod -n productapp --force --grace-period=0
    # done
    
    # 2. Augmenter la latence réseau (nécessite un CNI supportant)
    # kubectl exec -n productapp $pod -- tc qdisc add dev eth0 root netem delay 1000ms
    
    # 3. Saturer CPU (stress test)
    # kubectl exec -n productapp $pod -- stress --cpu 4 --timeout 30s &
    
    # 4. Redémarrer tous les pods backend (rolling restart)
    # kubectl rollout restart deployment backend-deployment -n productapp
    
    # 5. Simuler OOM (Out Of Memory)
    # kubectl exec -n productapp $pod -- stress --vm 1 --vm-bytes 1G --timeout 20s &
    
    # Pour cet exemple, on fait un simple scale down/up rapide
    local original_replicas=$(get_backend_replicas)
    scale_backend 1
    sleep 15
    scale_backend $original_replicas
}

run_experiment() {
    print_header "CHAOS EXPERIMENT: Custom Example"
    
    # 1. Prerequisites
    check_prerequisites
    
    # 2. Setup
    start_port_forward
    start_traffic
    
    # 3. Baseline
    log_info "Baseline..."
    wait_seconds 10 "Baseline"
    
    # 4. Inject chaos
    inject_chaos
    
    # 5. Monitor recovery
    log_info "Monitoring..."
    wait_seconds $((TEST_DURATION - 10)) "Monitoring"
    
    # 6. Collect metrics
    stop_traffic
    sleep 2
    
    local traffic_log
    if [[ -f "${PID_DIR}/chaos-traffic-log.txt" ]]; then
        traffic_log=$(cat "${PID_DIR}/chaos-traffic-log.txt")
    else
        log_error "Fichier de référence des logs introuvable"
        traffic_log=$(ls -t "${LOG_DIR}"/chaos-traffic-*.log 2>/dev/null | head -1)
    fi
    
    if [[ ! -f "${traffic_log}" ]]; then
        log_error "Fichier de logs du trafic introuvable: ${traffic_log}"
        exit 1
    fi
    
    read -r total success failed max_downtime recovery_time < <(collect_metrics "${traffic_log}" "${TEST_DURATION}")
    
    # 7. Results
    print_metrics_summary "${total}" "${success}" "${failed}" "${max_downtime}" "${recovery_time}"
    
    return $?
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

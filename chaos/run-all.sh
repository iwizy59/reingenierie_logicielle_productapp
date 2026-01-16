#!/bin/bash

###############################################################################
# Chaos Testing - Run All Experiments
#
# Exécute séquentiellement toutes les expériences de chaos engineering
# avec une pause entre chaque pour permettre la stabilisation du cluster
###############################################################################

set -euo pipefail

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "${SCRIPT_DIR}/lib/common.sh"

# Configuration
: "${PAUSE_BETWEEN_EXPERIMENTS:=30}"

###############################################################################
# Experiment list
###############################################################################

EXPERIMENTS=(
    "experiments/kill-one-backend-pod.sh"
    "experiments/scale-backend-to-1-then-back.sh"
)

###############################################################################
# Main execution
###############################################################################

main() {
    print_header "CHAOS TESTING - SUITE COMPLÈTE"
    
    log_info "Nombre d'expériences à exécuter: ${#EXPERIMENTS[@]}"
    log_info "Pause entre expériences: ${PAUSE_BETWEEN_EXPERIMENTS}s"
    echo ""
    
    local total_experiments=${#EXPERIMENTS[@]}
    local passed=0
    local failed=0
    local experiment_num=0
    
    # Execute each experiment
    for experiment in "${EXPERIMENTS[@]}"; do
        experiment_num=$((experiment_num + 1))
        local experiment_path="${SCRIPT_DIR}/${experiment}"
        local experiment_name=$(basename "${experiment}" .sh)
        
        print_header "EXPÉRIENCE ${experiment_num}/${total_experiments}: ${experiment_name}"
        
        if [[ ! -f "${experiment_path}" ]]; then
            log_error "Fichier d'expérience introuvable: ${experiment_path}"
            failed=$((failed + 1))
            continue
        fi
        
        # Make executable
        chmod +x "${experiment_path}"
        
        # Run experiment
        log_info "Lancement de l'expérience..."
        if bash "${experiment_path}"; then
            log_success "Expérience réussie: ${experiment_name}"
            passed=$((passed + 1))
        else
            log_error "Expérience échouée: ${experiment_name}"
            failed=$((failed + 1))
        fi
        
        # Pause between experiments (except after the last one)
        if [[ ${experiment_num} -lt ${total_experiments} ]]; then
            log_info "Pause avant l'expérience suivante..."
            wait_seconds ${PAUSE_BETWEEN_EXPERIMENTS} "Stabilisation"
            echo ""
        fi
    done
    
    # Final summary
    print_summary "RÉSUMÉ GLOBAL"
    echo "Expériences totales   : ${total_experiments}"
    echo "Réussies (PASS)       : ${passed}"
    echo "Échouées (FAIL)       : ${failed}"
    echo ""
    
    if [[ ${failed} -eq 0 ]]; then
        print_header "RÉSULTAT FINAL: TOUTES LES EXPÉRIENCES ONT RÉUSSI ✓"
        return 0
    else
        print_header "RÉSULTAT FINAL: ${failed} EXPÉRIENCE(S) ONT ÉCHOUÉ ✗"
        return 1
    fi
}

###############################################################################
# Execute
###############################################################################

if main; then
    exit 0
else
    exit 1
fi

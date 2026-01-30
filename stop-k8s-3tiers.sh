#!/bin/bash

###############################################################################
# Script de nettoyage Kubernetes avec Architecture 3-tiers
###############################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="productapp"
RANCHER_NAMESPACE="cattle-system"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Nettoyage K8s Architecture 3-Tiers${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Arrêt des port-forwards
stop_port_forward() {
    log_info "Arrêt des port-forwards..."
    
    # Port-forward application
    if [ -f /tmp/productapp-port-forward.pid ]; then
        PID=$(cat /tmp/productapp-port-forward.pid)
        if ps -p $PID > /dev/null 2>&1; then
            kill $PID 2>/dev/null || true
            log_info "✓ Port-forward application arrêté"
        fi
        rm -f /tmp/productapp-port-forward.pid
    fi
    
    # Port-forward Rancher
    if [ -f /tmp/rancher-port-forward.pid ]; then
        PID=$(cat /tmp/rancher-port-forward.pid)
        if ps -p $PID > /dev/null 2>&1; then
            kill $PID 2>/dev/null || true
            log_info "✓ Port-forward Rancher arrêté"
        fi
        rm -f /tmp/rancher-port-forward.pid
    fi
}

# Suppression des ressources Kubernetes
delete_k8s_resources() {
    log_info "Suppression des ressources Kubernetes..."
    
    # Supprimer tout le namespace d'un coup avec force
    log_info "Suppression forcée du namespace productapp..."
    kubectl delete namespace ${NAMESPACE} --force --grace-period=0 2>&1 &
    sleep 1
    kubectl get namespace ${NAMESPACE} -o json 2>/dev/null | jq -r '.spec.finalizers = []' | kubectl replace --raw /api/v1/namespaces/${NAMESPACE}/finalize -f - 2>/dev/null || true
    
    sleep 1
    if ! kubectl get namespace ${NAMESPACE} > /dev/null 2>&1; then
        log_info "✓ Namespace ${NAMESPACE} complètement supprimé"
    else
        log_warn "Namespace ${NAMESPACE} en cours de suppression..."
    fi
}

# Suppression de Rancher
delete_rancher() {
    echo ""
    log_info "Nettoyage de Rancher..."
    
    # 1. Toujours supprimer les webhooks et ClusterRoleBindings (même si le namespace n'existe pas)
    kubectl delete validatingwebhookconfigurations rancher.cattle.io --ignore-not-found=true 2>/dev/null &
    kubectl delete mutatingwebhookconfigurations rancher.cattle.io --ignore-not-found=true 2>/dev/null &
    kubectl delete clusterrolebinding rancher --ignore-not-found=true 2>/dev/null &
    
    # 2. Supprimer tous les CRDs Rancher rapidement (sans attendre)
    CRD_LIST=$(kubectl get crd -o name 2>/dev/null | grep cattle.io)
    if [ -n "$CRD_LIST" ]; then
        CRD_COUNT=$(echo "$CRD_LIST" | wc -l | tr -d ' ')
        log_info "Suppression de ${CRD_COUNT} CRDs Rancher..."
        # Boucle pour patcher et supprimer chaque CRD
        echo "$CRD_LIST" | while read crd; do
            (kubectl patch "$crd" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null
             kubectl delete "$crd" --force --grace-period=0 2>/dev/null) &
        done
    fi
    
    # 3. Suppression du namespace s'il existe
    if kubectl get namespace ${RANCHER_NAMESPACE} > /dev/null 2>&1; then
        kubectl delete namespace ${RANCHER_NAMESPACE} --force --grace-period=0 2>&1 &
        sleep 1
        kubectl get namespace ${RANCHER_NAMESPACE} -o json 2>/dev/null | jq -r '.spec.finalizers = []' | kubectl replace --raw /api/v1/namespaces/${RANCHER_NAMESPACE}/finalize -f - 2>/dev/null || true
        
        # Attendre vraiment que le namespace soit supprimé (max 10 secondes)
        for i in {1..10}; do
            if ! kubectl get namespace ${RANCHER_NAMESPACE} > /dev/null 2>&1; then
                log_info "✓ Namespace ${RANCHER_NAMESPACE} complètement supprimé"
                break
            fi
            sleep 1
        done
        
        if kubectl get namespace ${RANCHER_NAMESPACE} > /dev/null 2>&1; then
            log_warn "⚠️ Namespace ${RANCHER_NAMESPACE} toujours en cours de suppression"
        fi
    fi
    
    # 4. Vérifier et supprimer à nouveau les webhooks (au cas où ils se sont recréés)
    sleep 1
    kubectl delete validatingwebhookconfigurations rancher.cattle.io --ignore-not-found=true 2>/dev/null || true
    kubectl delete mutatingwebhookconfigurations rancher.cattle.io --ignore-not-found=true 2>/dev/null || true
    
    log_info "✓ Nettoyage Rancher terminé"
}

# Menu principal
main() {
    stop_port_forward
    delete_k8s_resources
    delete_rancher
    
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}✓ Nettoyage terminé!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
}

# Exécution
main

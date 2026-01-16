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
    
    # Supprimer l'ingress et networkpolicy
    log_info "Suppression Ingress et NetworkPolicy..."
    kubectl delete ingress --all -n ${NAMESPACE} --ignore-not-found=true
    kubectl delete networkpolicy --all -n ${NAMESPACE} --ignore-not-found=true
    
    # Supprimer les deployments
    log_info "Suppression Frontend et Backend..."
    kubectl delete deployment frontend-deployment -n ${NAMESPACE} --ignore-not-found=true
    kubectl delete deployment backend-deployment -n ${NAMESPACE} --ignore-not-found=true
    
    # Supprimer les services
    kubectl delete service frontend-service -n ${NAMESPACE} --ignore-not-found=true
    kubectl delete service backend-service -n ${NAMESPACE} --ignore-not-found=true
    
    # Supprimer HPA
    kubectl delete hpa backend-hpa -n ${NAMESPACE} --ignore-not-found=true
    
    # Supprimer ConfigMaps
    kubectl delete configmap backend-config -n ${NAMESPACE} --ignore-not-found=true
    
    # Supprimer PostgreSQL
    log_info "Suppression PostgreSQL..."
    kubectl delete statefulset postgres -n ${NAMESPACE} --ignore-not-found=true
    kubectl delete service postgres-service -n ${NAMESPACE} --ignore-not-found=true
    kubectl delete pvc postgres-pvc -n ${NAMESPACE} --ignore-not-found=true
    kubectl delete configmap postgres-config -n ${NAMESPACE} --ignore-not-found=true
    kubectl delete secret postgres-secret -n ${NAMESPACE} --ignore-not-found=true
    
    # Supprimer le namespace et attendre complètement
    log_info "Suppression du namespace productapp..."
    kubectl delete namespace ${NAMESPACE} --ignore-not-found=true --timeout=60s || {
        log_warn "Timeout - Forçage de la suppression..."
        # Forcer en retirant les finalizers
        kubectl get namespace ${NAMESPACE} -o json 2>/dev/null | \
            jq '.spec.finalizers = []' | \
            kubectl replace --raw /api/v1/namespaces/${NAMESPACE}/finalize -f - 2>/dev/null || true
    }
    
    # Vérifier que c'est vraiment supprimé
    if kubectl get namespace ${NAMESPACE} > /dev/null 2>&1; then
        log_error "Le namespace ${NAMESPACE} existe encore après suppression"
    else
        log_info "✓ Namespace ${NAMESPACE} complètement supprimé"
    fi
}

# Suppression de Rancher
delete_rancher() {
    if kubectl get namespace ${RANCHER_NAMESPACE} > /dev/null 2>&1; then
        echo ""
        log_info "Suppression de Rancher..."
        
        # 1. Supprimer les webhooks EN PREMIER (c'est ça qui bloque)
        log_info "Nettoyage des webhooks Rancher..."
        kubectl delete validatingwebhookconfigurations rancher.cattle.io --ignore-not-found=true 2>/dev/null || true
        kubectl delete mutatingwebhookconfigurations rancher.cattle.io --ignore-not-found=true 2>/dev/null || true
        
        # 2. Supprimer le ClusterRoleBinding
        log_info "Suppression des ClusterRoleBindings..."
        kubectl delete clusterrolebinding rancher --ignore-not-found=true 2>/dev/null || true
        
        # 3. Supprimer toutes les ressources API custom de Rancher
        log_info "Nettoyage des CRDs Rancher..."
        CRD_LIST=$(kubectl get crd -o name 2>/dev/null | grep cattle.io)
        if [ -n "$CRD_LIST" ]; then
            # Retirer les finalizers de tous les CRDs Rancher
            for crd in $CRD_LIST; do
                kubectl patch $crd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
            done
            # Supprimer les CRDs
            echo "$CRD_LIST" | xargs -r kubectl delete --ignore-not-found=true 2>/dev/null || true
            log_info "✓ CRDs Rancher supprimés"
        fi
        
        # 4. Forcer la suppression des pods Rancher
        log_info "Arrêt forcé des pods Rancher..."
        kubectl delete pod --all -n ${RANCHER_NAMESPACE} --grace-period=0 --force --ignore-not-found=true 2>/dev/null || true
        
        # 5. Supprimer le PVC
        log_info "Suppression du PVC Rancher..."
        kubectl delete pvc rancher-data -n ${RANCHER_NAMESPACE} --ignore-not-found=true 2>/dev/null || true
        
        # 6. Retirer les finalizers AVANT de supprimer
        log_info "Retrait des finalizers du namespace cattle-system..."
        kubectl patch namespace ${RANCHER_NAMESPACE} -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        
        # 7. Supprimer le namespace (devrait être instantané maintenant)
        log_info "Suppression du namespace cattle-system..."
        kubectl delete namespace ${RANCHER_NAMESPACE} --timeout=30s 2>/dev/null || true
        
        # 7. Supprimer le namespace (devrait être instantané maintenant)
        log_info "Suppression du namespace cattle-system..."
        kubectl delete namespace ${RANCHER_NAMESPACE} --timeout=30s 2>/dev/null || true
        
        # 8. Vérifier que c'est vraiment supprimé
        sleep 2
        if kubectl get namespace ${RANCHER_NAMESPACE} > /dev/null 2>&1; then
            log_warn "Le namespace existe encore, forçage final..."
            kubectl delete namespace ${RANCHER_NAMESPACE} --force --grace-period=0 2>/dev/null || true
            sleep 2
        fi
        
        if kubectl get namespace ${RANCHER_NAMESPACE} > /dev/null 2>&1; then
            log_error "Impossible de supprimer complètement cattle-system"
        else
            log_info "✓ Rancher complètement supprimé"
        fi
    fi
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

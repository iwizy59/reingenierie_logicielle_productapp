#!/bin/bash

###############################################################################
# Script pour arrêter proprement le déploiement Kubernetes
# Usage: ./stop-k8s.sh [--force] [--keep-data]
# Options:
#   --force      : Supprime sans confirmation
#   --keep-data  : Conserve les PersistentVolumeClaims (données PostgreSQL)
###############################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

NAMESPACE="productapp"
FORCE_DELETE=false
KEEP_DATA=false

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_DELETE=true
            shift
            ;;
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
        *)
            echo "Usage: $0 [--force] [--keep-data]"
            exit 1
            ;;
    esac
done

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${MAGENTA}[SUCCESS]${NC} $1"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Arrêt de ProductApp Kubernetes${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Arrêter tous les port-forwards actifs sur le port 8080
log_info "Recherche des port-forwards actifs..."
if lsof -ti:8080 > /dev/null 2>&1; then
    log_info "Arrêt des port-forwards sur le port 8080..."
    lsof -ti:8080 | xargs kill -9 2>/dev/null || true
    log_info "✓ Port-forwards arrêtés"
else
    log_info "Aucun port-forward actif sur le port 8080"
fi

# Arrêter le port-forward via le fichier PID
if [ -f "/tmp/productapp-port-forward.pid" ]; then
    PID=$(cat /tmp/productapp-port-forward.pid)
    if ps -p $PID > /dev/null 2>&1; then
        log_info "Arrêt du port-forward (PID: $PID)..."
        kill $PID 2>/dev/null || true
        log_info "✓ Port-forward arrêté"
    fi
    rm -f /tmp/productapp-port-forward.pid
fi

# Vérifier si le namespace existe
if ! kubectl get namespace ${NAMESPACE} > /dev/null 2>&1; then
    log_warn "Le namespace ${NAMESPACE} n'existe pas"
    exit 0
fi

# Afficher les ressources actuelles
echo ""
log_info "Ressources actuelles dans le namespace ${NAMESPACE}:"
kubectl get all,pvc,networkpolicy -n ${NAMESPACE}
echo ""

# Option pour supprimer toutes les ressources
if [ "$FORCE_DELETE" = false ]; then
    read -p "Voulez-vous supprimer toutes les ressources Kubernetes? (y/N): " -n 1 -r
    echo
else
    REPLY="y"
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Suppression des ressources Kubernetes..."
    
    if [ "$KEEP_DATA" = true ]; then
        log_warn "Conservation des PersistentVolumeClaims (données PostgreSQL)"
        
        # Supprimer les ressources sauf les PVC
        log_info "Suppression du HPA..."
        kubectl delete hpa --all -n ${NAMESPACE} --ignore-not-found=true
        
        log_info "Suppression de l'Ingress..."
        kubectl delete ingress --all -n ${NAMESPACE} --ignore-not-found=true
        
        log_info "Suppression de la NetworkPolicy..."
        kubectl delete networkpolicy --all -n ${NAMESPACE} --ignore-not-found=true
        
        log_info "Suppression du Deployment..."
        kubectl delete deployment productapp-deployment -n ${NAMESPACE} --ignore-not-found=true
        
        log_info "Suppression du StatefulSet PostgreSQL..."
        kubectl delete statefulset postgres -n ${NAMESPACE} --ignore-not-found=true
        
        log_info "Suppression des Services..."
        kubectl delete service --all -n ${NAMESPACE} --ignore-not-found=true
        
        log_info "Suppression des ConfigMaps et Secrets..."
        kubectl delete configmap --all -n ${NAMESPACE} --ignore-not-found=true
        kubectl delete secret --all -n ${NAMESPACE} --ignore-not-found=true
        
        echo ""
        log_success "✓ Ressources supprimées (PVC conservés)"
        
        echo ""
        log_info "PersistentVolumeClaims conservés:"
        kubectl get pvc -n ${NAMESPACE}
        echo ""
        log_warn "Pour supprimer les données, exécutez:"
        log_warn "  kubectl delete pvc --all -n ${NAMESPACE}"
        log_warn "  kubectl delete namespace ${NAMESPACE}"
    else
        log_info "Suppression complète du namespace (incluant les données)..."
        kubectl delete namespace ${NAMESPACE} --timeout=60s
        log_success "✓ Namespace et toutes les ressources supprimés"
    fi
else
    log_info "Les ressources Kubernetes sont conservées"
    log_info "Les pods continuent de tourner dans le namespace: ${NAMESPACE}"
fi

echo ""
log_success "========================================="
log_success "✓ Arrêt terminé!"
log_success "========================================="
echo ""

# Afficher un récapitulatif
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ "$KEEP_DATA" = false ]; then
        log_info "Pour redémarrer l'application:"
        log_info "  ${YELLOW}./deploy-k8s.sh${NC}"
    else
        log_info "Pour redémarrer l'application avec les données existantes:"
        log_info "  ${YELLOW}./deploy-k8s.sh${NC}"
        log_info ""
        log_info "Les données PostgreSQL seront automatiquement réutilisées"
    fi
fi

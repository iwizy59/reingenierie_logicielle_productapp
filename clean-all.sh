#!/bin/bash

###############################################################################
# Script de nettoyage complet
# Usage: ./clean-all.sh [--no-confirm]
# Description: Supprime TOUT - namespace, images Docker, caches
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
IMAGE_NAME="productapp"
NO_CONFIRM=false

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-confirm)
            NO_CONFIRM=true
            shift
            ;;
        *)
            echo "Usage: $0 [--no-confirm]"
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

echo -e "${RED}========================================${NC}"
echo -e "${RED}  NETTOYAGE COMPLET ProductApp${NC}"
echo -e "${RED}========================================${NC}"
echo ""
log_warn "⚠️  Ce script va supprimer:"
echo "   - Le namespace Kubernetes '${NAMESPACE}' et TOUTES ses ressources"
echo "   - Les PersistentVolumeClaims (TOUTES LES DONNÉES PostgreSQL)"
echo "   - Les images Docker '${IMAGE_NAME}'"
echo "   - Les caches Docker"
echo "   - Les port-forwards actifs"
echo ""

if [ "$NO_CONFIRM" = false ]; then
    read -p "Êtes-vous ABSOLUMENT SÛR de vouloir continuer? (yes/N): " -r
    echo
    if [[ ! $REPLY =~ ^yes$ ]]; then
        log_info "Opération annulée"
        exit 0
    fi
fi

echo ""
log_warn "🔥 Début du nettoyage complet..."
echo ""

# 1. Arrêter les port-forwards
log_info "1️⃣  Arrêt des port-forwards..."
if lsof -ti:8080 > /dev/null 2>&1; then
    lsof -ti:8080 | xargs kill -9 2>/dev/null || true
    log_info "✓ Port-forwards arrêtés"
else
    log_info "✓ Aucun port-forward actif"
fi

if [ -f "/tmp/productapp-port-forward.pid" ]; then
    rm -f /tmp/productapp-port-forward.pid
fi

# 2. Supprimer le namespace Kubernetes
log_info "2️⃣  Suppression du namespace Kubernetes..."
if kubectl get namespace ${NAMESPACE} > /dev/null 2>&1; then
    log_warn "Suppression de toutes les ressources dans ${NAMESPACE}..."
    kubectl delete namespace ${NAMESPACE} --timeout=120s
    log_info "✓ Namespace supprimé"
else
    log_info "✓ Namespace déjà supprimé"
fi

# 3. Supprimer les images Docker
log_info "3️⃣  Suppression des images Docker..."
IMAGES=$(docker images | grep ${IMAGE_NAME} | awk '{print $3}' || true)
if [ ! -z "$IMAGES" ]; then
    echo "$IMAGES" | xargs docker rmi -f 2>/dev/null || true
    log_info "✓ Images Docker supprimées"
else
    log_info "✓ Aucune image à supprimer"
fi

# 4. Nettoyer le cache Docker
log_info "4️⃣  Nettoyage du cache Docker..."
docker builder prune -f > /dev/null 2>&1 || true
log_info "✓ Cache Docker nettoyé"

# 5. Supprimer les fichiers temporaires
log_info "5️⃣  Nettoyage des fichiers temporaires..."
rm -f /tmp/port-forward.log
rm -f /tmp/productapp-port-forward.pid
log_info "✓ Fichiers temporaires supprimés"

# 6. Nettoyer les volumes Docker orphelins (optionnel)
log_info "6️⃣  Nettoyage des volumes Docker orphelins..."
docker volume prune -f > /dev/null 2>&1 || true
log_info "✓ Volumes orphelins supprimés"

echo ""
log_success "========================================="
log_success "✓ Nettoyage complet terminé!"
log_success "========================================="
echo ""

# Vérification finale
log_info "📊 Vérification finale:"
echo ""

log_info "Namespaces Kubernetes:"
kubectl get namespaces | grep -E "NAME|${NAMESPACE}" || log_info "  ✓ Namespace ${NAMESPACE} bien supprimé"
echo ""

log_info "Images Docker ${IMAGE_NAME}:"
docker images | grep -E "REPOSITORY|${IMAGE_NAME}" || log_info "  ✓ Toutes les images supprimées"
echo ""

log_info "Port-forwards actifs sur 8080:"
if lsof -ti:8080 > /dev/null 2>&1; then
    lsof -ti:8080
else
    log_info "  ✓ Aucun port-forward actif"
fi
echo ""

log_success "Le système est maintenant propre!"
log_info "Pour redéployer l'application, exécutez:"
log_info "  ${YELLOW}./deploy-k8s.sh${NC}"
echo ""

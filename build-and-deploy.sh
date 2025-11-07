#!/bin/bash

###############################################################################
# Script de build et déploiement pour Kubernetes
# Auteur: Expert Docker & Kubernetes
# Description: Build de l'image Docker et déploiement sur Kubernetes
###############################################################################

set -e  # Arrêt en cas d'erreur

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
IMAGE_NAME="productapp"
IMAGE_TAG="${1:-latest}"
NAMESPACE="productapp"
K8S_DIR="k8s"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Build & Deploy ProductApp${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Fonction pour afficher les messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier les prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl n'est pas installé"
        exit 1
    fi
    
    log_info "✓ Prérequis OK"
}

# Build de l'image Docker
build_image() {
    log_info "Build de l'image Docker: ${IMAGE_NAME}:${IMAGE_TAG}"
    
    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
    
    if [ $? -eq 0 ]; then
        log_info "✓ Image Docker construite avec succès"
    else
        log_error "Échec du build de l'image Docker"
        exit 1
    fi
}

# Tag de l'image pour différents environnements
tag_image() {
    log_info "Tag de l'image..."
    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
    log_info "✓ Image taguée"
}

# Déploiement sur Kubernetes
deploy_to_k8s() {
    log_info "Déploiement sur Kubernetes..."
    
    # Créer le namespace si nécessaire
    kubectl apply -f ${K8S_DIR}/namespace.yaml
    
    # Appliquer tous les manifests
    kubectl apply -f ${K8S_DIR}/configmap.yaml
    kubectl apply -f ${K8S_DIR}/deployment.yaml
    kubectl apply -f ${K8S_DIR}/service.yaml
    kubectl apply -f ${K8S_DIR}/hpa.yaml
    kubectl apply -f ${K8S_DIR}/ingress.yaml
    kubectl apply -f ${K8S_DIR}/networkpolicy.yaml
    
    log_info "✓ Ressources Kubernetes déployées"
}

# Vérifier le déploiement
check_deployment() {
    log_info "Vérification du déploiement..."
    
    kubectl rollout status deployment/productapp-deployment -n ${NAMESPACE} --timeout=300s
    
    if [ $? -eq 0 ]; then
        log_info "✓ Déploiement réussi"
    else
        log_error "Échec du déploiement"
        exit 1
    fi
}

# Afficher les informations du déploiement
show_info() {
    echo ""
    log_info "========================================="
    log_info "Informations du déploiement:"
    log_info "========================================="
    
    echo -e "\n${YELLOW}Pods:${NC}"
    kubectl get pods -n ${NAMESPACE} -o wide
    
    echo -e "\n${YELLOW}Services:${NC}"
    kubectl get svc -n ${NAMESPACE}
    
    echo -e "\n${YELLOW}HPA:${NC}"
    kubectl get hpa -n ${NAMESPACE}
    
    echo -e "\n${YELLOW}Ingress:${NC}"
    kubectl get ingress -n ${NAMESPACE}
    
    echo ""
    log_info "Pour accéder à l'application:"
    log_info "1. Via LoadBalancer: kubectl get svc -n ${NAMESPACE}"
    log_info "2. Via Port-Forward: kubectl port-forward -n ${NAMESPACE} svc/productapp-service 8080:80"
    log_info "3. Via Ingress: http://productapp.local (ajoutez '127.0.0.1 productapp.local' dans /etc/hosts)"
    echo ""
    log_info "Pour voir les logs: kubectl logs -n ${NAMESPACE} -l app=productapp -f"
}

# Menu principal
main() {
    check_prerequisites
    build_image
    tag_image
    deploy_to_k8s
    check_deployment
    show_info
    
    echo ""
    log_info "${GREEN}✓ Build et déploiement terminés avec succès!${NC}"
}

# Exécution
main

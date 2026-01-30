#!/bin/bash

###############################################################################
# Script de déploiement Kubernetes avec Architecture 3-tiers
# Frontend (nginx) + Backend (API REST Java) + Database (PostgreSQL)
###############################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

FRONTEND_IMAGE="productapp-frontend"
BACKEND_IMAGE="productapp-backend"
IMAGE_TAG="${1:-latest}"
NAMESPACE="productapp"
K8S_DIR="k8s-3tiers"
RANCHER_DIR="rancher"
RANCHER_NAMESPACE="cattle-system"
PORT_FORWARD_PORT="${2:-8080}"
RANCHER_PORT="${3:-8443}"
DEPLOY_RANCHER="${DEPLOY_RANCHER:-true}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Déploiement K8s Architecture 3-Tiers${NC}"
echo -e "${BLUE}  Frontend + Backend + Database${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

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
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Impossible de se connecter au cluster Kubernetes"
        exit 1
    fi
    
    log_info "✓ Prérequis OK"
}

# Build des images Docker
build_images() {
    log_info "Build des images Docker..."
    
    # Build Frontend
    log_info "Build de l'image Frontend: ${FRONTEND_IMAGE}:${IMAGE_TAG}"
    docker build -f Dockerfile.frontend -t ${FRONTEND_IMAGE}:${IMAGE_TAG} .
    docker tag ${FRONTEND_IMAGE}:${IMAGE_TAG} ${FRONTEND_IMAGE}:latest
    log_info "✓ Image Frontend construite"
    
    # Build Backend
    log_info "Build de l'image Backend: ${BACKEND_IMAGE}:${IMAGE_TAG}"
    docker build -f Dockerfile.backend -t ${BACKEND_IMAGE}:${IMAGE_TAG} .
    docker tag ${BACKEND_IMAGE}:${IMAGE_TAG} ${BACKEND_IMAGE}:latest
    log_info "✓ Image Backend construite"
}

# Charger les images dans le cluster
load_images_to_cluster() {
    log_info "Chargement des images dans le cluster..."
    
    # Détecter le type de cluster
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        log_info "Minikube détecté - Chargement des images..."
        minikube image load ${FRONTEND_IMAGE}:latest
        minikube image load ${BACKEND_IMAGE}:latest
        log_info "✓ Images chargées dans Minikube"
    elif command -v kind &> /dev/null; then
        CLUSTER_NAME=$(kind get clusters 2>/dev/null | head -n 1)
        if [ ! -z "$CLUSTER_NAME" ]; then
            log_info "Kind détecté - Chargement des images..."
            kind load docker-image ${FRONTEND_IMAGE}:latest --name $CLUSTER_NAME
            kind load docker-image ${BACKEND_IMAGE}:latest --name $CLUSTER_NAME
            log_info "✓ Images chargées dans Kind"
        fi
    else
        log_warn "Cluster local non détecté (ni Minikube ni Kind)"
        log_warn "Images disponibles dans Docker local"
    fi
}

# Déployer Rancher
deploy_rancher() {
    if [ "$DEPLOY_RANCHER" != "true" ]; then
        log_info "Déploiement de Rancher désactivé"
        return 0
    fi
    
    log_info "Déploiement de Rancher..."  
    
    # Créer le namespace Rancher
    log_info "Création du namespace Rancher..."
    kubectl apply -f "$RANCHER_DIR/namespace.yaml"
    
    # Créer le secret bootstrap
    log_info "Création du secret bootstrap..."
    kubectl apply -f "$RANCHER_DIR/bootstrap-secret.yaml"
    
    # Déployer le ServiceAccount et ClusterRoleBinding
    log_info "Création du ServiceAccount et ClusterRoleBinding..."
    kubectl apply -f "$RANCHER_DIR/serviceaccount.yaml"
    
    # Déployer le PVC
    log_info "Création du PVC Rancher..."
    kubectl apply -f "$RANCHER_DIR/pvc.yaml"
    
    # Déployer Rancher
    log_info "Création du Deployment Rancher..."
    kubectl apply -f "$RANCHER_DIR/deployment.yaml"
    
    log_info "Création du Service Rancher..."
    kubectl apply -f "$RANCHER_DIR/service.yaml"
    
    # Déployer l'Ingress (optionnel)
    kubectl apply -f "$RANCHER_DIR/ingress.yaml" 2>/dev/null || log_warn "Ingress Rancher non créé"
    
    log_success "✓ Rancher déployé"
}

# Vérifier le déploiement de Rancher
check_rancher_deployment() {
    if [ "$DEPLOY_RANCHER" != "true" ]; then
        return 0
    fi
    
    if ! kubectl get namespace "$RANCHER_NAMESPACE" &> /dev/null; then
        return 0
    fi
    
    log_info "Vérification du statut de Rancher..."
    
    # Attendre que le pod soit prêt (timeout 30 secondes, non bloquant)
    if kubectl wait --for=condition=ready pod -l app=rancher -n "$RANCHER_NAMESPACE" --timeout=30s 2>/dev/null; then
        log_success "✓ Rancher est prêt"
    else
        log_warn "⏳ Rancher démarre en arrière-plan (peut prendre 2-3 minutes)"
        log_info "Vous pourrez y accéder sur https://localhost:${RANCHER_PORT} une fois démarré"
    fi
}

# Configuration du port-forward Rancher
setup_rancher_port_forward() {
    if [ "$DEPLOY_RANCHER" != "true" ]; then
        return 0
    fi
    
    if ! kubectl get namespace "$RANCHER_NAMESPACE" &> /dev/null; then
        return 0
    fi
    
    log_info "Configuration du port-forward Rancher..."
    
    # Tuer les anciens port-forwards
    if [ -f /tmp/rancher-port-forward.pid ]; then
        OLD_PID=$(cat /tmp/rancher-port-forward.pid)
        if ps -p $OLD_PID > /dev/null 2>&1; then
            kill $OLD_PID 2>/dev/null || true
        fi
        rm /tmp/rancher-port-forward.pid
    fi
    
    # Démarrer le port-forward en arrière-plan (même si le pod n'est pas encore Running)
    kubectl port-forward -n "$RANCHER_NAMESPACE" svc/rancher $RANCHER_PORT:443 > /tmp/rancher-port-forward.log 2>&1 &
    echo $! > /tmp/rancher-port-forward.pid
    
    sleep 2
    
    if ps -p $(cat /tmp/rancher-port-forward.pid 2>/dev/null) > /dev/null 2>&1; then
        log_success "✓ Port-forward Rancher configuré sur https://localhost:$RANCHER_PORT"
        log_info "   (Rancher sera accessible une fois le pod démarré)"
    else
        log_warn "⚠️  Port-forward Rancher non disponible pour le moment"
    fi
}

# Initialiser le mot de passe Rancher
init_rancher_password() {
    if [ "$DEPLOY_RANCHER" != "true" ]; then
        return
    fi
    
    # Attendre que Rancher soit prêt
    log_info "Attente du démarrage de Rancher..."
    kubectl wait --for=condition=ready pod -l app=rancher -n ${RANCHER_NAMESPACE} --timeout=300s 2>/dev/null || {
        log_warn "⚠️  Rancher prend plus de temps que prévu à démarrer"
        return
    }
    
    sleep 5  # Attendre que Rancher soit complètement initialisé
    
    log_info "Génération du mot de passe admin Rancher..."
    
    # Récupérer le nom du pod
    RANCHER_POD=$(kubectl get pods -n ${RANCHER_NAMESPACE} -l app=rancher -o jsonpath='{.items[0].metadata.name}')
    
    # Réinitialiser le mot de passe admin (fonctionne que l'utilisateur existe ou non)
    ADMIN_OUTPUT=$(kubectl exec -n ${RANCHER_NAMESPACE} ${RANCHER_POD} -- reset-password 2>&1)
    
    # Extraire le mot de passe de la sortie
    ADMIN_PASSWORD=$(echo "$ADMIN_OUTPUT" | grep "New password for default admin" | tail -1 | awk '{print $NF}')
    
    if [ -n "$ADMIN_PASSWORD" ]; then
        log_success "✓ Utilisateur admin Rancher créé"
        echo "$ADMIN_PASSWORD" > /tmp/rancher-admin-password.txt
        log_info "📝 Mot de passe admin sauvegardé dans: /tmp/rancher-admin-password.txt"
        echo ""
        log_info "🔑 Mot de passe admin Rancher: ${GREEN}${ADMIN_PASSWORD}${NC}"
        echo ""
    else
        log_warn "⚠️  Impossible de générer le mot de passe admin"
    fi
}

# Déploiement sur Kubernetes
deploy_to_k8s() {
    log_info "Déploiement sur Kubernetes..."
    
    # Créer le namespace
    log_info "Création du namespace..."
    kubectl apply -f ${K8S_DIR}/namespace.yaml
    
    # Déployer la base de données
    log_info "Déploiement de PostgreSQL (Database tier)..."
    kubectl apply -f ${K8S_DIR}/database/postgres-configmap.yaml
    kubectl apply -f ${K8S_DIR}/database/postgres-secret.yaml
    kubectl apply -f ${K8S_DIR}/database/postgres-pvc.yaml
    kubectl apply -f ${K8S_DIR}/database/postgres-statefulset.yaml
    kubectl apply -f ${K8S_DIR}/database/postgres-service.yaml
    
    # Attendre PostgreSQL
    log_info "Attente du démarrage de PostgreSQL..."
    kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=120s
    log_success "✓ PostgreSQL prêt"
    
    # Déployer le backend
    log_info "Déploiement du Backend (API REST tier)..."
    kubectl apply -f ${K8S_DIR}/backend/configmap.yaml
    kubectl apply -f ${K8S_DIR}/backend/deployment.yaml
    kubectl apply -f ${K8S_DIR}/backend/service.yaml
    kubectl apply -f ${K8S_DIR}/backend/hpa.yaml
    
    # Déployer le frontend
    log_info "Déploiement du Frontend (nginx tier)..."
    kubectl apply -f ${K8S_DIR}/frontend/deployment.yaml
    kubectl apply -f ${K8S_DIR}/frontend/service.yaml
    
    # Déployer Ingress et NetworkPolicy
    log_info "Déploiement de l'Ingress et NetworkPolicy..."
    kubectl apply -f ${K8S_DIR}/ingress.yaml
    kubectl apply -f ${K8S_DIR}/networkpolicy.yaml
    
    log_success "✓ Ressources Kubernetes déployées"
}

# Vérifier le déploiement
check_deployment() {
    log_info "Vérification du déploiement..."
    
    log_info "Vérification du Backend..."
    kubectl rollout status deployment/backend-deployment -n ${NAMESPACE} --timeout=180s
    
    log_info "Vérification du Frontend..."
    kubectl rollout status deployment/frontend-deployment -n ${NAMESPACE} --timeout=60s
    
    log_success "✓ Déploiement réussi"
}

# Port-forward
setup_port_forward() {
    log_info "Configuration du port-forward..."
    
    # Arrêter les anciens port-forwards
    if [ -f /tmp/productapp-port-forward.pid ]; then
        OLD_PID=$(cat /tmp/productapp-port-forward.pid)
        if ps -p $OLD_PID > /dev/null 2>&1; then
            kill $OLD_PID 2>/dev/null || true
        fi
        rm -f /tmp/productapp-port-forward.pid
    fi
    
    # Port-forward via le frontend service
    kubectl port-forward -n ${NAMESPACE} svc/frontend-service ${PORT_FORWARD_PORT}:80 > /tmp/port-forward.log 2>&1 &
    echo $! > /tmp/productapp-port-forward.pid
    
    sleep 2
    
    if ps -p $(cat /tmp/productapp-port-forward.pid) > /dev/null 2>&1; then
        log_success "✓ Port-forward actif sur http://localhost:${PORT_FORWARD_PORT}"
    fi
}

# Afficher les informations
show_info() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  Architecture 3-Tiers Déployée${NC}"
    echo -e "${CYAN}=========================================${NC}"
    
    echo -e "\n${YELLOW}🌐 Frontend (nginx):${NC}"
    kubectl get pods,svc -n ${NAMESPACE} -l tier=frontend
    
    echo -e "\n${YELLOW}🚀 Backend (API REST):${NC}"
    kubectl get pods,svc -n ${NAMESPACE} -l tier=backend
    
    echo -e "\n${YELLOW}💾 Database (PostgreSQL):${NC}"
    kubectl get statefulset,pod,svc -n ${NAMESPACE} -l app=postgres
    
    echo -e "\n${YELLOW}🌐 Ingress:${NC}"
    kubectl get ingress -n ${NAMESPACE}
    
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  Accès à l'application${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
    echo -e "${GREEN}🌍 Application Web:${NC}"
    echo -e "   ${MAGENTA}http://localhost:${PORT_FORWARD_PORT}${NC}"
    echo ""
    echo -e "${GREEN}🔌 API Backend (via nginx proxy):${NC}"
    echo -e "   Health:   http://localhost:${PORT_FORWARD_PORT}/api/health"
    echo -e "   Products: http://localhost:${PORT_FORWARD_PORT}/api/products"
    echo ""
    
    # Afficher les infos Rancher si déployé
    if [ "$DEPLOY_RANCHER" = "true" ] && kubectl get namespace "$RANCHER_NAMESPACE" &> /dev/null; then
        echo -e "${YELLOW}🎛️  Rancher (Gestion de cluster):${NC}"
        echo -e "   URL:      ${MAGENTA}https://localhost:${RANCHER_PORT}${NC}"
        echo ""
        echo -e "   ${CYAN}📌 Première connexion:${NC}"
        echo -e "      1. Ouvrez ${MAGENTA}https://localhost:${RANCHER_PORT}${NC}"
        echo -e "      2. Le mot de passe bootstrap s'affichera automatiquement sur la page"
        echo -e "      3. Copiez-le et configurez votre mot de passe admin"
        echo ""
        RANCHER_STATUS=$(kubectl get pods -n ${RANCHER_NAMESPACE} -l app=rancher -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Démarrage")
        echo -e "   Status:   ${CYAN}${RANCHER_STATUS}${NC}"
        if [ "$RANCHER_STATUS" != "Running" ]; then
            echo -e "   ${YELLOW}⏳ Rancher démarre... (2-3 minutes)${NC}"
        fi
        echo ""
    fi
    
    echo -e "${GREEN}📊 Commandes utiles:${NC}"
    echo -e "   Logs Frontend: ${YELLOW}kubectl logs -n ${NAMESPACE} -l tier=frontend -f${NC}"
    echo -e "   Logs Backend:  ${YELLOW}kubectl logs -n ${NAMESPACE} -l tier=backend -f${NC}"
    echo -e "   Logs DB:       ${YELLOW}kubectl logs -n ${NAMESPACE} postgres-0 -f${NC}"
    if [ "$DEPLOY_RANCHER" = "true" ]; then
        echo -e "   Logs Rancher:  ${YELLOW}kubectl logs -n ${RANCHER_NAMESPACE} -l app=rancher -f${NC}"
    fi
    echo ""
}

# Menu principal
main() {
    check_prerequisites
    build_images
    load_images_to_cluster
    deploy_rancher
    check_rancher_deployment
    deploy_to_k8s
    check_deployment
    setup_port_forward
    setup_rancher_port_forward
    init_rancher_password
    show_info
    
    echo ""
    log_success "========================================="
    log_success "✓ Déploiement 3-Tiers terminé!"
    log_success "========================================="
    echo ""
    
    # Ouvrir le navigateur
    if command -v open &> /dev/null; then
        log_info "Ouverture du navigateur..."
        sleep 2
        open http://localhost:${PORT_FORWARD_PORT}
    fi
}

# Gestion des erreurs
trap 'log_error "Une erreur est survenue"; exit 1' ERR

# Exécution
main

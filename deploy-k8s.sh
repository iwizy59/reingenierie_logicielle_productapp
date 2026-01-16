#!/bin/bash

###############################################################################
# Script de déploiement Kubernetes avec PostgreSQL
# Description: Déploie l'application ProductApp avec PostgreSQL sur K8s
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

IMAGE_NAME="productapp"
IMAGE_TAG="${1:-latest}"
NAMESPACE="productapp"
K8S_DIR="k8s"
RANCHER_DIR="rancher"
RANCHER_NAMESPACE="cattle-system"
PORT_FORWARD_PORT="${2:-8080}"
RANCHER_PORT="${3:-8443}"
DEPLOY_RANCHER="${DEPLOY_RANCHER:-true}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Déploiement Kubernetes ProductApp${NC}"
echo -e "${BLUE}  avec PostgreSQL et Rancher${NC}"
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
    
    # Vérifier la connexion au cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Impossible de se connecter au cluster Kubernetes"
        exit 1
    fi
    
    log_info "✓ Prérequis OK"
}

# Télécharger les images nécessaires
pull_required_images() {
    log_info "Téléchargement des images nécessaires..."
    
    # BusyBox pour l'init container
    if ! docker images busybox:1.36 | grep -q "1.36"; then
        log_info "Téléchargement de busybox:1.36..."
        docker pull busybox:1.36
    else
        log_info "✓ busybox:1.36 déjà présent"
    fi
    
    # PostgreSQL
    if ! docker images postgres:16-alpine | grep -q "16-alpine"; then
        log_info "Téléchargement de postgres:16-alpine..."
        docker pull postgres:16-alpine
    else
        log_info "✓ postgres:16-alpine déjà présent"
    fi
    
    log_info "✓ Images nécessaires prêtes"
}

# Build de l'image Docker
build_image() {
    log_info "Build de l'image Docker: ${IMAGE_NAME}:${IMAGE_TAG}"
    
    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
    
    if [ $? -eq 0 ]; then
        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
        log_info "✓ Image Docker construite avec succès"
    else
        log_error "Échec du build de l'image Docker"
        exit 1
    fi
}

# Charger l'image dans le cluster (pour minikube/kind)
load_image_to_cluster() {
    log_info "Chargement de l'image dans le cluster..."
    
    # Détecter le type de cluster
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        log_info "Minikube détecté - Chargement de l'image..."
        minikube image load ${IMAGE_NAME}:latest
        log_info "✓ Image chargée dans Minikube"
    elif command -v kind &> /dev/null; then
        CLUSTER_NAME=$(kind get clusters 2>/dev/null | head -n 1)
        if [ ! -z "$CLUSTER_NAME" ]; then
            log_info "Kind détecté - Chargement de l'image dans le cluster: $CLUSTER_NAME"
            kind load docker-image ${IMAGE_NAME}:latest --name $CLUSTER_NAME
            log_info "✓ Image chargée dans Kind"
        fi
    else
        log_warn "Cluster local non détecté (ni Minikube ni Kind)"
        log_warn "Si vous utilisez un cluster cloud, assurez-vous de push l'image vers un registry"
    fi
}

# Déploiement sur Kubernetes
deploy_to_k8s() {
    log_info "Déploiement sur Kubernetes..."
    
    # Créer le namespace
    kubectl apply -f ${K8S_DIR}/namespace.yaml
    
    # Déployer PostgreSQL
    log_info "Déploiement de PostgreSQL..."
    kubectl apply -f ${K8S_DIR}/postgres-configmap.yaml
    kubectl apply -f ${K8S_DIR}/postgres-secret.yaml
    kubectl apply -f ${K8S_DIR}/postgres-pvc.yaml
    kubectl apply -f ${K8S_DIR}/postgres-statefulset.yaml
    kubectl apply -f ${K8S_DIR}/postgres-service.yaml
    
    # Attendre que PostgreSQL soit prêt
    log_info "Attente du démarrage de PostgreSQL..."
    kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=120s
    
    # Déployer l'application
    log_info "Déploiement de l'application..."
    kubectl apply -f ${K8S_DIR}/configmap.yaml
    kubectl apply -f ${K8S_DIR}/deployment.yaml
    kubectl apply -f ${K8S_DIR}/service.yaml
    kubectl apply -f ${K8S_DIR}/hpa.yaml
    kubectl apply -f ${K8S_DIR}/ingress.yaml
    kubectl apply -f ${K8S_DIR}/networkpolicy.yaml
    
    log_info "✓ Ressources Kubernetes déployées"
}

# Déployer Rancher
deploy_rancher() {
    if [ "$DEPLOY_RANCHER" != "true" ]; then
        log_info "Déploiement de Rancher ignoré (DEPLOY_RANCHER=false)"
        return 0
    fi
    
    log_info "Déploiement de Rancher pour la gestion du cluster..."
    
    # Vérifier si Rancher est déjà déployé
    if kubectl get namespace "$RANCHER_NAMESPACE" &> /dev/null; then
        log_warn "Rancher est déjà déployé, passage..."
        return 0
    fi
    
    # Créer le namespace
    log_info "Création du namespace $RANCHER_NAMESPACE..."
    kubectl apply -f "$RANCHER_DIR/namespace.yaml"
    
    # Déployer le ServiceAccount et RBAC
    log_info "Déploiement du ServiceAccount et RBAC..."
    kubectl apply -f "$RANCHER_DIR/serviceaccount.yaml"
    
    # Déployer le PVC
    log_info "Création du PersistentVolumeClaim..."
    kubectl apply -f "$RANCHER_DIR/pvc.yaml"
    
    # Attendre que le PVC soit bound
    kubectl wait --for=condition=Bound pvc/rancher-data -n "$RANCHER_NAMESPACE" --timeout=120s 2>/dev/null || true
    
    # Déployer Rancher
    log_info "Déploiement de l'application Rancher..."
    kubectl apply -f "$RANCHER_DIR/deployment.yaml"
    
    # Déployer le Service
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

# Vérifier le déploiement
check_deployment() {
    log_info "Vérification du déploiement..."
    # Afficher les infos Rancher si déployé
    if [ "$DEPLOY_RANCHER" = "true" ] && kubectl get namespace "$RANCHER_NAMESPACE" &> /dev/null; then
        echo -e "\n${YELLOW}🎛️  Rancher (Gestion de cluster):${NC}"
        kubectl get pods -n ${RANCHER_NAMESPACE} -l app=rancher 2>/dev/null || echo "   Démarrage en cours..."
    fi
    
    
    # Vérifier PostgreSQL
    log_info "Vérification de PostgreSQL..."
    kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=60s
    
    # Vérifier l'application
    log_info "Vérification de l'application..."
    kubectl rollout status deployment/productapp-deployment -n ${NAMESPACE} --timeout=300s
    
    if [ $? -eq 0 ]; then
        log_info "✓ Déploiement réussi"
    else
        log_error "Échec du déploiement"
        exit 1
    fi
    
    # Afficher les infos Rancher si déployé
    if [ "$DEPLOY_RANCHER" = "true" ] && kubectl get namespace "$RANCHER_NAMESPACE" &> /dev/null 2>&1; then
        echo -e "${CYAN}=========================================${NC}"
        echo -e "${CYAN}  Rancher - Gestion de Cluster${NC}"
        echo -e "${CYAN}=========================================${NC}"
        echo ""
        echo -e "${GREEN}🎛️  Interface Rancher:${NC}"
        echo -e "   ${MAGENTA}https://localhost:${RANCHER_PORT}${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  Informations Rancher:${NC}"
        echo -e "   - Acceptez le certificat auto-signé"
        echo -e "   - Mot de passe initial: ${CYAN}admin${NC}"
        echo -e "   - Changez le mot de passe à la première connexion"
        echo ""
        echo -e "${GREEN}🛑 Arrêter le port-forward Rancher:${NC}"
        echo -e "   ${YELLOW}kill \$(cat /tmp/rancher-port-forward.pid)${NC}"
        echo ""
    fi
}

# Arrêter les anciens port-forward
stop_old_port_forwards() {
    log_info "Nettoyage des anciens port-forwards..."
    
    # Trouver et tuer les processus kubectl port-forward sur notre port
    if lsof -ti:${PORT_FORWARD_PORT} > /dev/null 2>&1; then
        lsof -ti:${PORT_FORWARD_PORT} | xargs kill -9 2>/dev/null || true
        log_info "✓ Anciens port-forwards arrêtés"
    fi
}

# Démarrer le port-forward en arrière-plan
start_port_forward() {
    log_info "Démarrage du port-forward sur le port ${PORT_FORWARD_PORT}..."
    
    # Créer un fichier PID pour pouvoir arrêter le port-forward plus tard
    PID_FILE="/tmp/productapp-port-forward.pid"
    
    # Arrêter l'ancien port-forward s'il existe
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p $OLD_PID > /dev/null 2>&1; then
            kill $OLD_PID 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi
    
    # Démarrer le nouveau port-forward
    kubectl port-forward -n ${NAMESPACE} svc/productapp-service ${PORT_FORWARD_PORT}:80 > /tmp/port-forward.log 2>&1 &
    echo $! > "$PID_FILE"
    
    # Attendre que le port-forward soit prêt
    sleep 3
    
    if ps -p $(cat "$PID_FILE") > /dev/null 2>&1; then
        log_success "✓ Port-forward actif sur http://localhost:${PORT_FORWARD_PORT}"
    else
        log_error "Échec du démarrage du port-forward"
        return 1
    fi
}

# Tester l'application
test_application() {
    log_info "Test de l'application..."
    
    sleep 2
    
    # Test health check
    if curl -s -f http://localhost:${PORT_FORWARD_PORT}/api/health > /dev/null; then
        log_success "✓ Health check OK"
    else
        log_warn "Health check failed (l'app démarre peut-être encore)"
    fi
    
    # Test API products
    PRODUCT_COUNT=$(curl -s http://localhost:${PORT_FORWARD_PORT}/api/products | jq '. | length' 2>/dev/null || echo "0")
    if [ "$PRODUCT_COUNT" -gt "0" ]; then
        log_success "✓ API Products OK ($PRODUCT_COUNT produits trouvés)"
    else
        log_warn "API Products retourne 0 produits"
    fi
}

# Afficher les informations
show_info() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  Informations du déploiement${NC}"
    echo -e "${CYAN}=========================================${NC}"
    
    echo -e "\n${YELLOW}📦 PostgreSQL:${NC}"
    kubectl get statefulset,pod,pvc -n ${NAMESPACE} -l app=postgres
    
    echo -e "\n${YELLOW}🚀 Application:${NC}"
    kubectl get pods -n ${NAMESPACE} -l app=productapp -o wide
    
    echo -e "\n${YELLOW}🌐 Services:${NC}"
    kubectl get svc -n ${NAMESPACE}
    
    echo -e "\n${YELLOW}📈 HPA:${NC}"
    kubectl get hpa -n ${NAMESPACE}
    
    echo -e "\n${YELLOW}💾 PersistentVolumeClaims:${NC}"
    kubectl get pvc -n ${NAMESPACE}
    
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  Accès à l'application${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
    deploy_rancher
    check_deployment
    check_rancher_deployment
    stop_old_port_forwards
    start_port_forward
    setup_rancher""
    echo -e "${GREEN}🔌 API Endpoints:${NC}"
    echo -e "   Health:   http://localhost:${PORT_FORWARD_PORT}/api/health"
    echo -e "   Products: http://localhost:${PORT_FORWARD_PORT}/api/products"
    echo -e "   Stats:    http://localhost:${PORT_FORWARD_PORT}/api/stats"
    echo ""
    echo -e "${GREEN}📊 Commandes utiles:${NC}"
    echo -e "   Logs App: ${YELLOW}kubectl logs -n ${NAMESPACE} -l app=productapp -f${NC}"
    echo -e "   Logs DB:  ${YELLOW}kubectl logs -n ${NAMESPACE} postgres-0 -f${NC}"
    echo -e "   Shell DB: ${YELLOW}kubectl exec -it -n ${NAMESPACE} postgres-0 -- psql -U postgres -d productdb${NC}"
    echo ""
    echo -e "${GREEN}🛑 Arrêter le port-forward:${NC}"
    echo -e "   ${YELLOW}kill \$(cat /tmp/productapp-port-forward.pid)${NC}"
    echo ""
}

# Menu principal
main() {
    check_prerequisites
    pull_required_images
    build_image
    load_image_to_cluster
    deploy_to_k8s
    deploy_rancher
    check_deployment
    check_rancher_deployment
    stop_old_port_forwards
    start_port_forward
    setup_rancher_port_forward
    test_application
    show_info
    
    echo ""
    log_success "========================================="
    log_success "✓ Déploiement terminé avec succès!"
    log_success "========================================="
    echo ""
    log_info "Ouvrez votre navigateur sur: ${MAGENTA}http://localhost:${PORT_FORWARD_PORT}${NC}"
    echo ""
    
    # Ouvrir automatiquement le navigateur (macOS)
    if command -v open &> /dev/null; then
        log_info "Ouverture du navigateur..."
        sleep 2
        open http://localhost:${PORT_FORWARD_PORT}
    fi
}

# Gestion du signal d'interruption
cleanup() {
    echo ""
    log_warn "Interruption détectée..."
    
    # Arrêter le port-forward
    if [ -f "/tmp/productapp-port-forward.pid" ]; then
        PID=$(cat /tmp/productapp-port-forward.pid)
        if ps -p $PID > /dev/null 2>&1; then
            kill $PID 2>/dev/null || true
            log_info "Port-forward arrêté"
        fi
        rm -f /tmp/productapp-port-forward.pid
    fi
    
    exit 0
}

# Trap pour cleanup
trap cleanup SIGINT SIGTERM

# Exécution
main

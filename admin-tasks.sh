#!/bin/bash

###############################################################################
# Script helper pour exécuter les tâches admin (12-Factor - Principe XII)
# Usage: ./admin-tasks.sh <task> [options]
###############################################################################

set -e

NAMESPACE="productapp"
IMAGE="productapp:latest"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Vérifier si kubectl est disponible
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl n'est pas installé ou pas dans le PATH"
    exit 1
fi

# Vérifier la connexion au cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Impossible de se connecter au cluster Kubernetes"
    exit 1
fi

case "$1" in
    seed|data-seed)
        print_header "🌱 DataSeed - Initialisation des données"
        echo ""
        
        # Option 1 : Via Job Kubernetes (recommandé)
        if [[ "$2" == "--job" ]]; then
            echo "Méthode : Kubernetes Job"
            echo ""
            kubectl apply -f k8s/job-data-seed.yaml -n $NAMESPACE
            print_success "Job créé"
            echo ""
            echo "Pour suivre l'exécution :"
            echo "  kubectl logs -f job/productapp-data-seed -n $NAMESPACE"
            echo ""
            echo "Pour vérifier le statut :"
            echo "  kubectl get job/productapp-data-seed -n $NAMESPACE"
        else
            # Option 2 : Via pod temporaire
            echo "Méthode : Pod temporaire (run --rm)"
            echo ""
            kubectl run data-seed-$(date +%s) --rm -it \
                --image=$IMAGE \
                --restart=Never \
                --namespace=$NAMESPACE \
                --env="DB_HOST=postgres-service" \
                --env="DB_PORT=5432" \
                -- java -cp app.jar com.reingenierie.admin.DataSeed
        fi
        ;;
    
    migrate|db-migrate)
        print_header "🔧 DBMigrate - Migrations de base de données"
        echo ""
        
        # Vérifier si une version spécifique est demandée
        VERSION_ARG=""
        if [[ "$2" =~ ^[0-9]+$ ]]; then
            VERSION_ARG="$2"
            echo "Cible : Migration version $VERSION_ARG"
        elif [[ "$2" == "--status" ]]; then
            VERSION_ARG="--status"
            echo "Mode : Affichage du statut"
        else
            echo "Mode : Toutes les migrations"
        fi
        echo ""
        
        # Option 1 : Via Job Kubernetes (recommandé)
        if [[ "$3" == "--job" ]] || [[ "$2" == "--job" ]]; then
            echo "Méthode : Kubernetes Job"
            echo ""
            kubectl apply -f k8s/job-db-migrate.yaml -n $NAMESPACE
            print_success "Job créé"
            echo ""
            echo "Pour suivre l'exécution :"
            echo "  kubectl logs -f job/productapp-db-migrate -n $NAMESPACE"
            echo ""
            echo "Pour vérifier le statut :"
            echo "  kubectl get job/productapp-db-migrate -n $NAMESPACE"
        else
            # Option 2 : Via pod temporaire
            echo "Méthode : Pod temporaire (run --rm)"
            echo ""
            
            CMD="java -cp app.jar com.reingenierie.admin.DBMigrate"
            if [[ -n "$VERSION_ARG" ]]; then
                CMD="$CMD $VERSION_ARG"
            fi
            
            kubectl run db-migrate-$(date +%s) --rm -it \
                --image=$IMAGE \
                --restart=Never \
                --namespace=$NAMESPACE \
                --env="DB_HOST=postgres-service" \
                --env="DB_PORT=5432" \
                -- sh -c "$CMD"
        fi
        ;;
    
    console)
        print_header "🖥️  Console Interactive"
        echo ""
        
        # Trouver un pod actif
        POD=$(kubectl get pods -n $NAMESPACE -l app=productapp -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        
        if [[ -z "$POD" ]]; then
            print_error "Aucun pod productapp trouvé dans le namespace $NAMESPACE"
            exit 1
        fi
        
        echo "Pod sélectionné : $POD"
        echo ""
        print_warn "Console non implémentée pour le moment"
        print_warn "Alternative : kubectl exec -it $POD -n $NAMESPACE -- /bin/sh"
        ;;
    
    list)
        print_header "📋 Tâches admin disponibles"
        echo ""
        echo "Usage: $0 <task> [options]"
        echo ""
        echo "Tâches disponibles :"
        echo ""
        echo "  seed, data-seed        Initialiser les données de test"
        echo "                         Options: --job (via Kubernetes Job)"
        echo ""
        echo "  migrate, db-migrate    Exécuter les migrations de base de données"
        echo "                         Options: [version] --job"
        echo "                         Exemples:"
        echo "                           $0 migrate              # Toutes les migrations"
        echo "                           $0 migrate 001          # Migration v001 seulement"
        echo "                           $0 migrate --status     # Afficher le statut"
        echo "                           $0 migrate --job        # Via Job K8s"
        echo ""
        echo "  console                Console interactive (à venir)"
        echo ""
        echo "  list                   Afficher cette aide"
        echo ""
        echo "Exemples rapides :"
        echo "  $0 seed                # Initialiser les données"
        echo "  $0 migrate             # Appliquer toutes les migrations"
        echo "  $0 migrate --status    # Voir l'état des migrations"
        echo ""
        ;;
    
    *)
        print_error "Tâche inconnue : $1"
        echo ""
        echo "Usage: $0 {seed|console|list}"
        echo "       $0 list pour voir toutes les tâches disponibles"
        exit 1
        ;;
esac

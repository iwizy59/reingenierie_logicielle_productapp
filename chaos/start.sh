#!/bin/bash

###############################################################################
# Quick Start Guide - Chaos Testing POBS
#
# Ce script est un guide interactif pour exécuter les tests de chaos
###############################################################################

set -euo pipefail

# Déterminer la racine du framework Chaos
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHAOS_ROOT="${SCRIPT_DIR}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}║          CHAOS TESTING POBS - QUICK START                 ║${NC}"
echo -e "${BLUE}║          ProductApp 3-Tiers - Kubernetes                  ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${GREEN}[1/3] Vérification des prérequis...${NC}"
echo ""

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl n'est pas installé"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "❌ curl n'est pas installé"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cluster Kubernetes inaccessible"
    exit 1
fi

if ! kubectl get namespace productapp &> /dev/null; then
    echo "❌ Namespace 'productapp' introuvable"
    echo ""
    echo "Pour déployer l'application :"
    echo "  cd .."
    echo "  ./deploy-k8s-3tiers.sh"
    exit 1
fi

if ! kubectl get deployment backend-deployment -n productapp &> /dev/null; then
    echo "❌ Deployment 'backend-deployment' introuvable"
    exit 1
fi

echo "✓ kubectl installé"
echo "✓ curl installé"
echo "✓ Cluster accessible"
echo "✓ Namespace productapp existe"
echo "✓ Backend deployment trouvé"
echo ""

# Show current state
echo -e "${GREEN}[2/3] État actuel du cluster${NC}"
echo ""
kubectl get pods -n productapp -l app=backend
echo ""

# Menu
echo -e "${GREEN}[3/3] Choix de l'expérience${NC}"
echo ""
echo "  1) Kill un pod backend (60s)"
echo "  2) Scale backend 2 → 1 → 2 (60s)"
echo "  3) Exécuter TOUTES les expériences (suite complète)"
echo "  4) Mode DRY-RUN (test sans vraiment casser)"
echo "  5) CHAOS EXTRÊME: Scale à 1 puis kill ce pod"
echo "  6) Quitter"
echo ""
read -p "Votre choix [1-6]: " choice

case $choice in
    1)
        echo ""
        echo -e "${YELLOW}Lancement: Kill Backend Pod${NC}"
        echo ""
        "${CHAOS_ROOT}/experiments/kill-one-backend-pod.sh"
        ;;
    2)
        echo ""
        echo -e "${YELLOW}Lancement: Scale Backend Down/Up${NC}"
        echo ""
        "${CHAOS_ROOT}/experiments/scale-backend-to-1-then-back.sh"
        ;;
    3)
        echo ""
        echo -e "${YELLOW}Lancement: Suite Complète${NC}"
        echo ""
        "${CHAOS_ROOT}/run-all.sh"
        ;;
    4)
        echo ""
        echo -e "${YELLOW}Mode DRY-RUN activé${NC}"
        echo ""
        echo "Quelle expérience ?"
        echo "  1) Kill pod"
        echo "  2) Scale"
        read -p "Choix [1-2]: " dry_choice
        case $dry_choice in
            1)
                DRY_RUN=true "${CHAOS_ROOT}/experiments/kill-one-backend-pod.sh"
                ;;
            2)
                DRY_RUN=true "${CHAOS_ROOT}/experiments/scale-backend-to-1-then-back.sh"
                ;;
            *)
                echo "Choix invalide"
                exit 1
                ;;
        esac
        ;;
    5)
        echo ""
        echo -e "${YELLOW}Lancement: CHAOS EXTRÊME - Scale puis Kill${NC}"
        echo ""
        "${CHAOS_ROOT}/experiments/scale-then-kill-last-pod.sh"
        ;;
    6)
        echo "Au revoir !"
        exit 0
        ;;
    *)
        echo "Choix invalide"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Test terminé !${NC}"
echo ""
echo "Logs détaillés dans: /tmp/chaos-*.log"
echo ""
echo "Pour relancer:"
echo "  ./start.sh"
echo ""

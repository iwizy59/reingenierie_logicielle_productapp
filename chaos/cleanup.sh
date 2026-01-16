#!/bin/bash

###############################################################################
# Chaos Testing - Cleanup Script
#
# Nettoie tous les processus et fichiers temporaires liés aux tests de chaos
###############################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}╔════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║   NETTOYAGE CHAOS TESTING                 ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════╝${NC}"
echo ""

# 1. Stop all port-forwards
echo -e "${GREEN}[1/5] Arrêt des port-forwards...${NC}"
pkill -f "kubectl port-forward.*frontend-service" 2>/dev/null && echo "  ✓ Port-forwards arrêtés" || echo "  ℹ Aucun port-forward actif"

# 2. Stop traffic generators
echo -e "${GREEN}[2/5] Arrêt des générateurs de trafic...${NC}"
if [ -f /tmp/chaos-traffic.pid ]; then
    pid=$(cat /tmp/chaos-traffic.pid)
    if ps -p "$pid" > /dev/null 2>&1; then
        kill "$pid" 2>/dev/null || true
        pkill -P "$pid" 2>/dev/null || true
        echo "  ✓ Générateur de trafic arrêté (PID: $pid)"
    else
        echo "  ℹ Processus déjà terminé"
    fi
else
    echo "  ℹ Aucun générateur actif"
fi

# 3. Clean PID files
echo -e "${GREEN}[3/5] Suppression des fichiers PID...${NC}"
rm -f /tmp/chaos-*.pid /tmp/chaos-traffic-log.txt /tmp/chaos-original-replicas.txt
echo "  ✓ Fichiers PID supprimés"

# 4. Restore backend replicas
echo -e "${GREEN}[4/5] Restauration des replicas backend...${NC}"
if kubectl get deployment backend-deployment -n productapp &> /dev/null; then
    current=$(kubectl get deployment backend-deployment -n productapp -o jsonpath='{.spec.replicas}')
    if [ "$current" != "3" ]; then
        kubectl scale deployment backend-deployment -n productapp --replicas=3 &> /dev/null
        echo "  ✓ Backend scalé à 3 replicas (était à $current)"
    else
        echo "  ✓ Backend déjà à 3 replicas"
    fi
else
    echo "  ⚠ Backend deployment introuvable"
fi

# 5. Show logs
echo -e "${GREEN}[5/5] Logs disponibles:${NC}"
if ls /tmp/chaos-*.log 1> /dev/null 2>&1; then
    ls -lht /tmp/chaos-*.log | head -5
    echo ""
    echo "Pour supprimer les logs:"
    echo "  rm -f /tmp/chaos-*.log"
else
    echo "  ℹ Aucun log trouvé"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Nettoyage terminé !${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo "État actuel du cluster:"
kubectl get pods -n productapp -l app=backend 2>/dev/null || echo "  ⚠ Namespace productapp inaccessible"

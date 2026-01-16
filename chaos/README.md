# Chaos Testing POBS - ProductApp 3-Tiers

## 📋 Objectif
Valider la résilience de l'API backend face à des pannes d'instances, conformément au risque business :
> **"L'API doit rester disponible si une instance backend tombe"**

## 🎯 Métriques de Succès
- **Taux de disponibilité** : ≥ 95% de requêtes réussies
- **Indisponibilité maximale continue** : ≤ 10 secondes
- **Temps de recovery** : mesure du temps de rétablissement

## 📂 Structure

```
chaos/
├── README.md                          # Ce fichier
├── lib/
│   └── common.sh                      # Fonctions utilitaires (logs, checks, cleanup)
├── traffic/
│   └── traffic.sh                     # Générateur de trafic HTTP
├── experiments/
│   ├── kill-one-backend-pod.sh        # Exp 1: Suppression d'un pod backend
│   └── scale-backend-to-1-then-back.sh # Exp 2: Scale down/up
└── run-all.sh                         # Orchestrateur de toutes les expériences
```

## ⚙️ Prérequis

### Outils
- `bash` ≥ 4.0
- `kubectl` configuré avec accès au cluster
- `curl` pour les tests HTTP
- Cluster Kubernetes avec l'application déployée

### Vérification rapide
```bash
kubectl get deployment -n productapp backend-deployment
kubectl get service -n productapp frontend-service backend-service
```

### Variables d'environnement (optionnelles)
```bash
export NAMESPACE="productapp"
export BACKEND_DEPLOYMENT="backend-deployment"
export FRONTEND_SERVICE="frontend-service"
export BASE_URL="http://localhost:8080"
export TEST_DURATION=60        # Durée du test en secondes
export CHECK_INTERVAL=1        # Intervalle entre checks (secondes)
export SUCCESS_THRESHOLD=95    # Seuil de succès (%)
export MAX_DOWNTIME=10         # Indisponibilité max continue (secondes)
```

## 🚀 Exécution

### Méthode 1 : Expériences individuelles

#### Expérience 1 : Kill un pod backend
```bash
cd chaos
./experiments/kill-one-backend-pod.sh
```

**Ce qui se passe** :
1. Port-forward automatique sur localhost:8080
2. Injection de trafic HTTP (1 req/s vers `/api/health`)
3. Suppression d'un pod backend aléatoire
4. Monitoring continu pendant 60s
5. Résumé des métriques + PASS/FAIL

#### Expérience 2 : Scale backend 2 → 1 → 2
```bash
cd chaos
./experiments/scale-backend-to-1-then-back.sh
```

**Ce qui se passe** :
1. Lecture du nombre de replicas initial
2. Scale à 1 replica pendant 30s
3. Scale retour à la valeur initiale
4. Monitoring + assertions

### Méthode 2 : Toutes les expériences d'un coup
```bash
cd chaos
./run-all.sh
```

Exécute séquentiellement toutes les expériences avec pause entre chaque.

### Mode Dry-Run
```bash
DRY_RUN=true ./experiments/kill-one-backend-pod.sh
```
Affiche les commandes sans les exécuter.

## 📊 Résultats

### Format de sortie
```
========================================
  CHAOS EXPERIMENT: Kill Backend Pod
========================================

[2026-01-16 11:30:00] ✓ Prérequis validés
[2026-01-16 11:30:01] ✓ Port-forward démarré (PID: 12345)
[2026-01-16 11:30:02] ✓ Générateur de trafic démarré (PID: 12346)
[2026-01-16 11:30:05] ⚡ Suppression du pod backend-deployment-abc123
[2026-01-16 11:30:15] ✓ Nouveau pod backend-deployment-xyz789 Ready

========================================
  RÉSUMÉ DE L'EXPÉRIENCE
========================================
Durée totale          : 60s
Checks effectués      : 60
Succès                : 58 (96.67%)
Échecs                : 2 (3.33%)
Plus longue panne     : 4s
Temps de recovery     : 10s

Seuils:
  ✓ Disponibilité ≥ 95%     : PASS (96.67%)
  ✓ Indispo max ≤ 10s       : PASS (4s)

========================================
  RÉSULTAT FINAL: PASS ✓
========================================
```

### Fichiers de logs
Les logs détaillés sont sauvegardés dans :
```
chaos/logs/chaos-<experiment>-<timestamp>.log
chaos/logs/chaos-traffic-<timestamp>.log
```

## 🔧 Personnalisation

### Augmenter la charge
Modifier `traffic.sh` pour ajouter des workers parallèles :
```bash
# Dans traffic.sh, section "traffic_loop"
for i in {1..5}; do
    traffic_loop &
done
```

### Changer les endpoints testés
```bash
# Tester /api/products au lieu de /api/health
export HEALTH_ENDPOINT="/api/products"
```

### Ajuster les seuils
```bash
export SUCCESS_THRESHOLD=99  # Plus strict
export MAX_DOWNTIME=5        # Plus exigeant
```

## 🧹 Nettoyage

Les scripts incluent un nettoyage automatique via `trap` :
- Arrêt du générateur de trafic
- Arrêt du port-forward
- Restauration des replicas originaux

En cas de problème, nettoyage manuel :
```bash
# Arrêter tous les port-forwards
pkill -f "kubectl port-forward.*frontend-service"

# Restaurer replicas backend
kubectl scale deployment backend-deployment -n productapp --replicas=3

# Supprimer les fichiers PID et logs
rm -f chaos/logs/chaos-*.pid
```

## 📈 Métriques Collectées

### Par expérience
- Nombre total de checks HTTP
- Taux de succès/échec
- Plus longue période d'indisponibilité continue
- Temps de recovery (retour à 100% disponibilité)
- Timestamps de début/fin de panne

### Calculs
```
Taux de succès = (Succès / Total) × 100
Recovery time  = Timestamp(premier succès après échec) - Timestamp(injection chaos)
Max downtime   = Plus longue séquence consécutive d'échecs × CHECK_INTERVAL
```

## 🐛 Troubleshooting

### Port déjà utilisé
```bash
lsof -ti:8080 | xargs kill -9
```

### Context Kubernetes incorrect
```bash
kubectl config get-contexts
kubectl config use-context docker-desktop
```

### Logs détaillés
```bash
VERBOSE=true ./experiments/kill-one-backend-pod.sh
```

## 📚 Références
- [Principles of Chaos Engineering](https://principlesofchaos.org/)
- [Kubernetes Chaos Engineering](https://kubernetes.io/docs/tasks/debug/)
- [Site Reliability Engineering - Google](https://sre.google/books/)

## 🤝 Contribution
Pour ajouter une nouvelle expérience :
1. Créer `chaos/experiments/nouvelle-experience.sh`
2. Sourcer `../lib/common.sh`
3. Implémenter les fonctions : `setup()`, `inject_chaos()`, `validate()`
4. Ajouter à `run-all.sh`

---

**Auteur** : Chaos Testing POBS Framework  
**Date** : 2026-01-16  
**Version** : 1.0.0

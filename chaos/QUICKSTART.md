# 🚀 Guide de Démarrage Rapide - Chaos Testing

## En 30 secondes

```bash
# 1. Déployer l'application (si pas déjà fait)
cd /Users/alexis/Documents/Ecole/FISA\ 5/Reing/Kub/reingenierie_logicielle_productapp
./deploy-k8s-3tiers.sh

# 2. Lancer les tests de chaos
cd chaos
./start.sh
```

## Ce qui va se passer

### Expérience 1 : Kill Backend Pod
- **Durée** : ~60 secondes
- **Action** : Supprime 1 pod backend aléatoire
- **Attendu** : API reste disponible ≥95%, indispo max ≤10s

### Expérience 2 : Scale Backend
- **Durée** : ~60 secondes  
- **Action** : Scale 3 → 1 → 3 replicas
- **Attendu** : API reste disponible ≥95%, indispo max ≤10s

## Résultats Typiques

### ✓ PASS (Bon comportement)
```
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
```

### ✗ FAIL (Problème détecté)
```
========================================
  RÉSUMÉ DE L'EXPÉRIENCE
========================================
Durée totale          : 60s
Checks effectués      : 60
Succès                : 50 (83.33%)
Échecs                : 10 (16.67%)
Plus longue panne     : 15s
Temps de recovery     : 25s

Seuils:
  ✗ Disponibilité ≥ 95%     : FAIL (83.33%)
  ✗ Indispo max ≤ 10s       : FAIL (15s)
```

## Commandes Rapides

```bash
# Test individuel - Kill pod
./experiments/kill-one-backend-pod.sh

# Test individuel - Scale
./experiments/scale-backend-to-1-then-back.sh

# Tous les tests d'un coup
./run-all.sh

# Mode dry-run (pas de vraie destruction)
DRY_RUN=true ./experiments/kill-one-backend-pod.sh

# Avec logs verbeux
VERBOSE=true ./experiments/kill-one-backend-pod.sh

# Personnalisation
TEST_DURATION=120 SUCCESS_THRESHOLD=99 ./experiments/kill-one-backend-pod.sh
```

## Variables d'Environnement

```bash
export NAMESPACE="productapp"              # Namespace K8s
export BACKEND_DEPLOYMENT="backend-deployment"  # Nom du deployment
export BASE_URL="http://localhost:8080"    # URL de test
export TEST_DURATION=60                    # Durée en secondes
export SUCCESS_THRESHOLD=95                # Seuil de succès (%)
export MAX_DOWNTIME=10                     # Indispo max (secondes)
export CHECK_INTERVAL=1                    # Fréquence des checks (s)
```

## Troubleshooting

### Port 8080 déjà utilisé
```bash
lsof -ti:8080 | xargs kill -9
```

### Cluster pas démarré
```bash
kubectl cluster-info
# Si erreur → démarrer Docker Desktop
```

### Nettoyer tout
```bash
pkill -f "kubectl port-forward.*frontend-service"
rm -f /tmp/chaos-*.pid /tmp/chaos-*.log
kubectl scale deployment backend-deployment -n productapp --replicas=3
```

## Logs

Tous les logs sont dans `/tmp/` :
```bash
ls -lth /tmp/chaos-*.log | head
tail -f /tmp/chaos-traffic-*.log
```

## Analyse des Résultats

### Métriques Clés
- **Taux de succès** : % de requêtes HTTP 200
- **Plus longue panne** : Séquence consécutive max d'échecs
- **Recovery time** : Temps pour revenir à 100% après injection

### Interprétation

| Métrique | Valeur | État | Signification |
|----------|--------|------|---------------|
| Succès | ≥95% | ✓ | Haute disponibilité |
| Succès | <95% | ✗ | Trop d'échecs |
| Max panne | ≤10s | ✓ | Recovery rapide |
| Max panne | >10s | ✗ | Recovery lent |

## Prochaines Étapes

1. ✅ Exécuter les tests de base
2. 📊 Analyser les métriques
3. 🔧 Ajuster les replicas/ressources si FAIL
4. 🔁 Relancer les tests
5. 📝 Documenter les résultats

## Voir Aussi

- [README.md](README.md) - Documentation complète
- [chaos/lib/common.sh](lib/common.sh) - Code des fonctions utilitaires
- [Principles of Chaos](https://principlesofchaos.org/) - Théorie

---

**Ready ?** → `./start.sh` 🚀

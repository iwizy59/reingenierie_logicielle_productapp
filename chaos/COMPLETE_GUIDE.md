# 📦 Arborescence Complète

```
chaos/
├── README.md                          # Documentation complète (objectifs, métriques, usage)
├── QUICKSTART.md                      # Guide de démarrage en 30 secondes
├── start.sh                           # Script interactif de lancement
├── run-all.sh                         # Orchestrateur - exécute toutes les expériences
├── cleanup.sh                         # Nettoyage complet (processus, PID, restauration)
│
├── lib/
│   └── common.sh                      # Fonctions utilitaires réutilisables
│                                      #   - Logs (info/warn/error/chaos)
│                                      #   - Checks prérequis
│                                      #   - Gestion port-forward
│                                      #   - Gestion trafic
│                                      #   - Opérations K8s (scale, delete, wait)
│                                      #   - Collecte métriques
│                                      #   - Cleanup automatique (trap)
│
├── traffic/
│   └── traffic.sh                     # Générateur de trafic HTTP
│                                      #   - Boucle infinie curl
│                                      #   - Logs timestamp + HTTP status
│                                      #   - Configurable (interval, timeout)
│
└── experiments/
    ├── kill-one-backend-pod.sh        # Exp 1: Suppression d'un pod backend
    │                                  #   - Sélection aléatoire
    │                                  #   - Monitoring recovery
    │                                  #   - Assertions disponibilité
    │
    ├── scale-backend-to-1-then-back.sh # Exp 2: Scale down/up
    │                                   #   - Lecture replicas initial
    │                                   #   - Scale 3→1 pendant 30s
    │                                   #   - Scale 1→3 et attente stabilisation
    │
    └── TEMPLATE.sh                     # Template pour nouvelles expériences
                                        #   - Structure standard
                                        #   - Exemples d'injections

```

# 🎯 Fichiers Générés (Runtime)

```
/tmp/
├── chaos-port-forward.pid             # PID du port-forward kubectl
├── chaos-traffic.pid                  # PID du générateur de trafic
├── chaos-traffic-log.txt              # Chemin vers le log du trafic en cours
├── chaos-original-replicas.txt        # Sauvegarde replicas pour restauration
│
├── chaos-traffic-20260116-120430.log  # Log détaillé du trafic
├── chaos-kill-pod-20260116-120530.log # Log de l'expérience kill-pod
└── chaos-scale-down-up-20260116.log   # Log de l'expérience scale
```

# 🚀 Guide d'Exécution Complet

## Étape 1 : Déployer l'application

```bash
cd /Users/alexis/Documents/Ecole/FISA\ 5/Reing/Kub/reingenierie_logicielle_productapp
./deploy-k8s-3tiers.sh
```

**Vérification** :
```bash
kubectl get pods -n productapp
# Attendu: backend-deployment-xxx (3 pods Running)
#          frontend-deployment-xxx (2 pods Running)
#          postgres-0 (1 pod Running)
```

## Étape 2 : Lancer les tests de chaos

### Méthode A : Interface interactive (recommandé)
```bash
cd chaos
./start.sh
```

Vous verrez un menu :
```
  1) Kill un pod backend (60s)
  2) Scale backend 2 → 1 → 2 (60s)
  3) Exécuter TOUTES les expériences (suite complète)
  4) Mode DRY-RUN (test sans vraiment casser)
  5) Quitter
```

### Méthode B : Commande directe
```bash
# Expérience 1
./experiments/kill-one-backend-pod.sh

# Expérience 2
./experiments/scale-backend-to-1-then-back.sh

# Toutes les expériences
./run-all.sh
```

### Méthode C : Avec personnalisation
```bash
# Augmenter la durée et le seuil
TEST_DURATION=120 SUCCESS_THRESHOLD=99 ./experiments/kill-one-backend-pod.sh

# Mode dry-run (pas de vraie destruction)
DRY_RUN=true ./experiments/kill-one-backend-pod.sh

# Logs verbeux
VERBOSE=true ./experiments/kill-one-backend-pod.sh

# Changer l'endpoint testé
HEALTH_ENDPOINT="/api/products" ./experiments/kill-one-backend-pod.sh
```

## Étape 3 : Analyser les résultats

### Sortie console
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

========================================
  RÉSULTAT FINAL: PASS ✓
========================================
```

### Logs détaillés
```bash
# Voir le dernier log de trafic
tail -100 /tmp/chaos-traffic-*.log | tail -20

# Format des logs de trafic:
# [1705405470] WORKER=1 HTTP_STATUS=200 URL=http://localhost:8080/api/health OK
# [1705405471] WORKER=1 HTTP_STATUS=000 URL=http://localhost:8080/api/health FAILED (curl_exit=7)
# [1705405472] WORKER=1 HTTP_STATUS=200 URL=http://localhost:8080/api/health OK
```

### Interprétation

| Métrique | Valeur Obtenue | Seuil | Résultat | Action |
|----------|----------------|-------|----------|--------|
| Disponibilité | 96.67% | ≥95% | ✓ PASS | RAS |
| Disponibilité | 92% | ≥95% | ✗ FAIL | Augmenter replicas |
| Max panne | 4s | ≤10s | ✓ PASS | RAS |
| Max panne | 15s | ≤10s | ✗ FAIL | Vérifier probes |

## Étape 4 : Nettoyage

```bash
# Nettoyage automatique (trap intégré dans chaque script)
# Mais si besoin de nettoyer manuellement:
./cleanup.sh
```

# 🔧 Variables d'Environnement

| Variable | Valeur par défaut | Description |
|----------|-------------------|-------------|
| `NAMESPACE` | `productapp` | Namespace Kubernetes |
| `BACKEND_DEPLOYMENT` | `backend-deployment` | Nom du deployment backend |
| `FRONTEND_SERVICE` | `frontend-service` | Nom du service frontend |
| `BACKEND_SERVICE` | `backend-service` | Nom du service backend |
| `BASE_URL` | `http://localhost:8080` | URL de base pour les tests |
| `PORT_FORWARD_PORT` | `8080` | Port local du port-forward |
| `TEST_DURATION` | `60` | Durée du test (secondes) |
| `CHECK_INTERVAL` | `1` | Intervalle entre checks (secondes) |
| `SUCCESS_THRESHOLD` | `95` | Seuil de disponibilité (%) |
| `MAX_DOWNTIME` | `10` | Indispo max continue (secondes) |
| `HEALTH_ENDPOINT` | `/api/health` | Endpoint de santé testé |
| `DRY_RUN` | `false` | Mode simulation |
| `VERBOSE` | `false` | Logs détaillés |
| `SCALE_DOWN_REPLICAS` | `1` | Replicas cible pour scale down |
| `SCALE_DOWN_DURATION` | `30` | Durée du scale down (secondes) |

# 📊 Métriques Collectées

## Métriques Brutes
- Nombre total de checks HTTP effectués
- Nombre de succès (HTTP 200)
- Nombre d'échecs (HTTP ≠ 200)

## Métriques Calculées
- **Taux de disponibilité** : `(Succès / Total) × 100`
- **Plus longue panne** : Séquence consécutive max d'échecs × CHECK_INTERVAL
- **Temps de recovery** : Timestamp(premier succès après chaos) - Timestamp(injection chaos)

## Assertions
1. **Disponibilité ≥ SUCCESS_THRESHOLD%** (défaut: 95%)
2. **Indisponibilité max ≤ MAX_DOWNTIME secondes** (défaut: 10s)

# 🐛 Troubleshooting

## Erreur: "Port 8080 already in use"
```bash
lsof -ti:8080 | xargs kill -9
```

## Erreur: "Namespace 'productapp' n'existe pas"
```bash
cd ..
./deploy-k8s-3tiers.sh
```

## Erreur: "Cluster Kubernetes inaccessible"
```bash
kubectl cluster-info
# Si erreur → démarrer Docker Desktop
# Ou vérifier contexte: kubectl config get-contexts
```

## Le script se bloque
```bash
# Ctrl+C pour interrompre
# Puis nettoyage manuel:
./cleanup.sh
```

## Pods backend ne reviennent pas Ready
```bash
kubectl get pods -n productapp -l app=backend
kubectl describe pod <pod-name> -n productapp
kubectl logs <pod-name> -n productapp
```

## Recovery time trop long (>30s)
Vérifier les probes du backend :
```bash
kubectl get deployment backend-deployment -n productapp -o yaml | grep -A 10 livenessProbe
# Ajuster initialDelaySeconds, periodSeconds, failureThreshold
```

## Tous les tests échouent systématiquement
1. Vérifier l'état de base :
   ```bash
   kubectl get pods -n productapp
   curl http://localhost:8080/api/health
   ```
2. Tester manuellement un port-forward :
   ```bash
   kubectl port-forward -n productapp svc/frontend-service 8080:80
   curl http://localhost:8080/api/health
   ```
3. Vérifier les logs backend :
   ```bash
   kubectl logs -n productapp -l app=backend --tail=50
   ```

# 🎓 Comprendre les Résultats

## Scénario Idéal (PASS)
```
Disponibilité: 98-100%
Max panne: 0-5s
Recovery: 5-15s
```
**Interprétation** : L'application est **hautement résiliente**. Kubernetes recrée les pods rapidement, le load-balancing fonctionne parfaitement.

## Scénario Acceptable (PASS limite)
```
Disponibilité: 95-97%
Max panne: 5-10s
Recovery: 15-30s
```
**Interprétation** : L'application est **résiliente** mais peut être optimisée (augmenter replicas, ajuster probes).

## Scénario Problématique (FAIL)
```
Disponibilité: <95%
Max panne: >10s
Recovery: >30s
```
**Interprétation** : **Problème de résilience**. Actions à mener :
- Augmenter le nombre de replicas (3 → 5)
- Vérifier les probes (initialDelaySeconds trop élevé)
- Ajouter des ressources CPU/RAM
- Vérifier la latence de démarrage du backend

# 📚 Pour Aller Plus Loin

## Créer une nouvelle expérience

1. **Copier le template** :
   ```bash
   cp experiments/TEMPLATE.sh experiments/mon-experience.sh
   ```

2. **Modifier la fonction inject_chaos()** :
   ```bash
   inject_chaos() {
       log_chaos "Mon injection custom"
       # Votre logique ici
   }
   ```

3. **Rendre exécutable** :
   ```bash
   chmod +x experiments/mon-experience.sh
   ```

4. **Tester** :
   ```bash
   ./experiments/mon-experience.sh
   ```

5. **Ajouter à run-all.sh** :
   ```bash
   # Dans EXPERIMENTS array
   EXPERIMENTS=(
       "experiments/kill-one-backend-pod.sh"
       "experiments/scale-backend-to-1-then-back.sh"
       "experiments/mon-experience.sh"  # <-- Ajouter ici
   )
   ```

## Exemples d'expériences avancées

### Tuer le pod frontend
```bash
kubectl delete pod -n productapp -l app=frontend --force --grace-period=0
```

### Saturer la base de données
```bash
kubectl exec -n productapp postgres-0 -- \
    psql -U postgres -d productdb -c "SELECT pg_sleep(30);"
```

### Bloquer le réseau entre tiers
```bash
# Nécessite NetworkPolicy avec deny rule temporaire
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-backend-to-postgres
  namespace: productapp
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
EOF
```

---

**🎉 Vous êtes prêt !**

Commencez avec : `./start.sh`

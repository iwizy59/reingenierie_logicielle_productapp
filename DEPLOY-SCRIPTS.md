# 🚀 Scripts de Déploiement Automatisé

## 📋 Scripts disponibles

### `deploy-k8s.sh` - Déploiement automatique
Script tout-en-un pour déployer l'application sur Kubernetes avec PostgreSQL.

**Fonctionnalités automatiques :**
- ✅ Téléchargement automatique des images Docker (busybox, postgres)
- ✅ Build de l'image de l'application
- ✅ Chargement dans le cluster (Minikube/Kind)
- ✅ Déploiement de PostgreSQL avec persistance
- ✅ Déploiement de l'application (3 replicas)
- ✅ Port-forward automatique en arrière-plan
- ✅ Tests de l'API
- ✅ Ouverture automatique du navigateur
- ✅ Nettoyage des anciens port-forwards

**Usage :**
```bash
# Déploiement avec paramètres par défaut (port 8080)
./deploy-k8s.sh

# Déploiement avec tag et port personnalisés
./deploy-k8s.sh v1.0.0 8081
```

**Paramètres :**
- `$1` : Tag de l'image Docker (défaut: `latest`)
- `$2` : Port local pour le port-forward (défaut: `8080`)

### `stop-k8s.sh` - Arrêt propre
Script pour arrêter proprement l'application et nettoyer les ressources.

**Fonctionnalités :**
- ✅ Arrêt du port-forward en arrière-plan
- ✅ Option pour supprimer toutes les ressources K8s
- ✅ Nettoyage du fichier PID

**Usage :**
```bash
./stop-k8s.sh
```

Le script vous demandera si vous voulez supprimer les ressources Kubernetes.

---

## 🎯 Workflow complet

### 1. Premier déploiement

```bash
# Déployer tout automatiquement
./deploy-k8s.sh

# Le script va :
# 1. Télécharger busybox:1.36 et postgres:16-alpine
# 2. Builder l'image productapp:latest
# 3. Déployer PostgreSQL + PVC
# 4. Déployer l'application (3 pods)
# 5. Lancer le port-forward sur localhost:8080
# 6. Tester l'API
# 7. Ouvrir http://localhost:8080 dans le navigateur
```

### 2. Vérifier le déploiement

```bash
# Vérifier les pods
kubectl get pods -n productapp

# Voir les logs de l'app
kubectl logs -n productapp -l app=productapp -f

# Voir les logs de PostgreSQL
kubectl logs -n productapp postgres-0 -f

# Tester l'API manuellement
curl http://localhost:8080/api/health
curl http://localhost:8080/api/products
```

### 3. Redéployer après modifications

```bash
# Arrêter l'ancien déploiement
./stop-k8s.sh
# Répondre 'N' pour garder les données PostgreSQL

# Redéployer
./deploy-k8s.sh
```

### 4. Nettoyage complet

```bash
# Tout supprimer (y compris les données)
./stop-k8s.sh
# Répondre 'Y' pour supprimer toutes les ressources
```

---

## 🔧 Configuration avancée

### Changer le port du port-forward

```bash
# Déployer sur le port 9000
./deploy-k8s.sh latest 9000

# Accéder à http://localhost:9000
```

### Arrêter uniquement le port-forward

```bash
# Trouver le PID
cat /tmp/productapp-port-forward.pid

# Tuer le processus
kill $(cat /tmp/productapp-port-forward.pid)

# Ou utiliser le port
lsof -ti:8080 | xargs kill -9
```

### Relancer uniquement le port-forward

```bash
# Lancer manuellement
kubectl port-forward -n productapp svc/productapp-service 8080:80 &
echo $! > /tmp/productapp-port-forward.pid
```

---

## 📊 Ce qui est déployé

### PostgreSQL
- **StatefulSet** : 1 replica
- **Service** : ClusterIP headless
- **PVC** : 5Gi de stockage persistant
- **ConfigMap** : Configuration DB
- **Secret** : Mots de passe

### Application
- **Deployment** : 3 replicas
- **Service** : LoadBalancer
- **HPA** : Auto-scaling (2-10 pods)
- **Ingress** : Point d'entrée HTTP
- **NetworkPolicy** : Sécurité réseau

---

## 🐛 Troubleshooting

### Le port-forward ne démarre pas

```bash
# Vérifier si le port est déjà utilisé
lsof -i :8080

# Tuer le processus
lsof -ti:8080 | xargs kill -9

# Relancer le déploiement
./deploy-k8s.sh
```

### Les pods ne démarrent pas

```bash
# Voir les événements
kubectl get events -n productapp --sort-by='.lastTimestamp'

# Décrire un pod problématique
kubectl describe pod -n productapp <pod-name>

# Voir les logs
kubectl logs -n productapp <pod-name>
```

### L'image busybox n'est pas trouvée

Le script télécharge automatiquement busybox:1.36, mais si ça échoue :

```bash
# Télécharger manuellement
docker pull busybox:1.36

# Relancer le déploiement
./deploy-k8s.sh
```

### PostgreSQL ne démarre pas

```bash
# Vérifier le StatefulSet
kubectl get statefulset -n productapp

# Vérifier le PVC
kubectl get pvc -n productapp

# Voir les logs
kubectl logs -n productapp postgres-0

# Si le PVC est bloqué (Minikube)
minikube addons enable storage-provisioner
minikube addons enable default-storageclass
```

---

## 🎓 Exemples d'utilisation

### Développement local

```bash
# Déploiement rapide pour dev
./deploy-k8s.sh

# Modifier le code
# ...

# Redéployer
./deploy-k8s.sh
```

### Test avec différentes versions

```bash
# Version 1.0.0
./deploy-k8s.sh v1.0.0 8080

# Version 2.0.0 (sur un autre port pour comparer)
./deploy-k8s.sh v2.0.0 8081
```

### Production-like

```bash
# Déployer avec tag stable
./deploy-k8s.sh stable

# Scaler manuellement
kubectl scale deployment productapp-deployment --replicas=5 -n productapp

# Surveiller
kubectl get hpa -n productapp -w
```

---

## 📝 Logs et PID

### Fichiers générés

| Fichier | Description |
|---------|-------------|
| `/tmp/productapp-port-forward.pid` | PID du processus port-forward |
| `/tmp/port-forward.log` | Logs du port-forward |

### Commandes utiles

```bash
# Voir le PID du port-forward
cat /tmp/productapp-port-forward.pid

# Voir les logs du port-forward
tail -f /tmp/port-forward.log

# Vérifier que le processus tourne
ps -p $(cat /tmp/productapp-port-forward.pid)
```

---

## ✨ Avantages du script automatisé

✅ **Zéro configuration manuelle** - Tout est automatique  
✅ **Idempotent** - Peut être exécuté plusieurs fois sans problème  
✅ **Auto-nettoyage** - Arrête les anciens port-forwards  
✅ **Tests intégrés** - Vérifie que l'app fonctionne  
✅ **Feedback visuel** - Messages colorés et clairs  
✅ **Ouverture auto du navigateur** - Gain de temps  
✅ **Gestion des erreurs** - Arrêt propre en cas de problème  

---

**Bon déploiement ! 🚀**

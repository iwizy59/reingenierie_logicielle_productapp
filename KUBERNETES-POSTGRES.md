# 🚀 Déploiement Kubernetes avec PostgreSQL

## 📋 Architecture Kubernetes

```
┌──────────────────────────────────────────────────────┐
│                    Ingress                           │
│              (productapp.local)                      │
└────────────────────┬─────────────────────────────────┘
                     │
         ┌───────────▼────────────┐
         │   Service (LB)         │
         │   productapp-service   │
         └───────────┬────────────┘
                     │
    ┌────────────────┼────────────────┐
    │                │                │
┌───▼────┐      ┌───▼────┐      ┌───▼────┐
│ Pod 1  │      │ Pod 2  │      │ Pod 3  │
│ App    │      │ App    │      │ App    │
└───┬────┘      └───┬────┘      └───┬────┘
    │               │               │
    └───────────────┼───────────────┘
                    │
         ┌──────────▼──────────┐
         │  postgres-service   │
         │   (Headless)        │
         └──────────┬──────────┘
                    │
              ┌─────▼─────┐
              │ postgres-0│
              │StatefulSet│
              └─────┬─────┘
                    │
            ┌───────▼────────┐
            │ PersistentVol  │
            │    (5Gi)       │
            └────────────────┘
```

## 🎯 Ressources Kubernetes créées

### PostgreSQL (Base de données)
- **StatefulSet**: `postgres` (1 replica)
- **Service**: `postgres-service` (ClusterIP headless)
- **PVC**: `postgres-pvc` (5Gi de stockage persistant)
- **ConfigMap**: `postgres-config` (configuration DB)
- **Secret**: `postgres-secret` (mot de passe)

### Application ProductApp
- **Deployment**: `productapp-deployment` (3 replicas)
- **Service**: `productapp-service` (LoadBalancer)
- **ConfigMap**: `productapp-config`
- **HPA**: Auto-scaling (2-10 pods)
- **Ingress**: Point d'entrée HTTP
- **NetworkPolicy**: Sécurité réseau

## 🚀 Déploiement Rapide

### Option 1: Script automatisé (RECOMMANDÉ)

```bash
# Déployer tout automatiquement
./deploy-k8s.sh

# Ou avec un tag spécifique
./deploy-k8s.sh v1.0.0
```

Le script va :
1. ✅ Vérifier Docker et kubectl
2. ✅ Builder l'image Docker
3. ✅ Charger l'image dans le cluster (Minikube/Kind)
4. ✅ Déployer PostgreSQL avec persistance
5. ✅ Attendre que PostgreSQL soit prêt
6. ✅ Déployer l'application (3 replicas)
7. ✅ Vérifier que tout fonctionne
8. ✅ Afficher les informations de connexion

### Option 2: Déploiement manuel

```bash
# 1. Build l'image
docker build -t productapp:latest .

# 2. Charger dans le cluster (si Minikube)
minikube image load productapp:latest
# OU (si Kind)
kind load docker-image productapp:latest

# 3. Créer le namespace
kubectl apply -f k8s/namespace.yaml

# 4. Déployer PostgreSQL
kubectl apply -f k8s/postgres-configmap.yaml
kubectl apply -f k8s/postgres-secret.yaml
kubectl apply -f k8s/postgres-pvc.yaml
kubectl apply -f k8s/postgres-statefulset.yaml
kubectl apply -f k8s/postgres-service.yaml

# 5. Attendre PostgreSQL
kubectl wait --for=condition=ready pod -l app=postgres -n productapp --timeout=120s

# 6. Déployer l'application
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/networkpolicy.yaml

# 7. Vérifier le déploiement
kubectl rollout status deployment/productapp-deployment -n productapp
```

### Option 3: Avec Kustomize

```bash
# Déployer tout avec kustomize
kubectl apply -k k8s/

# Supprimer
kubectl delete -k k8s/
```

## 🌐 Accès à l'Application

### Méthode 1: Port-Forward (Plus simple)

```bash
# Port-forward vers l'application
kubectl port-forward -n productapp svc/productapp-service 8080:80

# Accéder à l'application
open http://localhost:8080
```

### Méthode 2: Minikube Service

```bash
# Exposer le service (ouvre automatiquement le navigateur)
minikube service productapp-service -n productapp
```

### Méthode 3: Via Ingress

```bash
# Ajouter l'entrée dans /etc/hosts
echo "127.0.0.1 productapp.local" | sudo tee -a /etc/hosts

# Si Minikube, démarrer le tunnel
minikube tunnel

# Accéder via le domaine
open http://productapp.local
```

### Méthode 4: LoadBalancer IP (Cloud)

```bash
# Récupérer l'IP externe
kubectl get svc productapp-service -n productapp

# Accéder via l'IP
open http://<EXTERNAL-IP>
```

## 🔍 Monitoring et Vérification

### Vérifier les pods

```bash
# Tous les pods
kubectl get pods -n productapp

# Détails d'un pod
kubectl describe pod -n productapp <pod-name>

# Logs de l'application
kubectl logs -n productapp -l app=productapp -f

# Logs de PostgreSQL
kubectl logs -n productapp postgres-0 -f
```

### Vérifier la base de données

```bash
# Se connecter à PostgreSQL
kubectl exec -it -n productapp postgres-0 -- psql -U postgres -d productdb

# Commandes SQL utiles
\dt                          # Lister les tables
\d products                  # Décrire la table products
SELECT COUNT(*) FROM products;
SELECT * FROM products LIMIT 5;
\q                          # Quitter
```

### Vérifier le stockage

```bash
# Voir les PVC
kubectl get pvc -n productapp

# Détails du PVC
kubectl describe pvc postgres-pvc -n productapp

# Voir les PV
kubectl get pv
```

### Vérifier l'auto-scaling

```bash
# État du HPA
kubectl get hpa -n productapp

# Détails
kubectl describe hpa productapp-hpa -n productapp

# Surveiller en temps réel
kubectl get hpa -n productapp -w
```

### Tester les health checks

```bash
# Health check via port-forward
kubectl port-forward -n productapp svc/productapp-service 8080:80

# Dans un autre terminal
curl http://localhost:8080/api/health
curl http://localhost:8080/api/products
```

## 🧪 Tests et Validation

### Test 1: Vérifier la connexion DB

```bash
# Créer un produit via l'API
curl -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test K8s Product",
    "description": "Created in Kubernetes",
    "price": "199.99",
    "quantity": 5
  }'

# Vérifier dans PostgreSQL
kubectl exec -it -n productapp postgres-0 -- \
  psql -U postgres -d productdb -c "SELECT * FROM products ORDER BY id DESC LIMIT 1;"
```

### Test 2: Persistance des données

```bash
# Supprimer le pod PostgreSQL
kubectl delete pod -n productapp postgres-0

# Attendre qu'il redémarre
kubectl wait --for=condition=ready pod postgres-0 -n productapp

# Vérifier que les données sont toujours là
kubectl port-forward -n productapp svc/productapp-service 8080:80
curl http://localhost:8080/api/products
```

### Test 3: Résilience de l'app

```bash
# Supprimer un pod de l'app
kubectl delete pod -n productapp -l app=productapp --force --grace-period=0

# Kubernetes va automatiquement recréer le pod
kubectl get pods -n productapp -w
```

### Test 4: Auto-scaling

```bash
# Générer de la charge (installer hey: brew install hey)
hey -z 60s -c 50 http://localhost:8080/api/products

# Observer le scaling
kubectl get hpa -n productapp -w
kubectl get pods -n productapp -w
```

### Test 5: Endpoint crash (auto-healing)

```bash
# Provoquer un crash
curl -X POST http://localhost:8080/api/crash

# Kubernetes va redémarrer le pod automatiquement
kubectl get pods -n productapp -w
```

## 🔧 Configuration

### Variables d'environnement

Les variables sont configurées via ConfigMap et Secret :

**PostgreSQL** (dans `postgres-config` et `postgres-secret`):
- `POSTGRES_DB`: productdb
- `POSTGRES_USER`: postgres
- `POSTGRES_PASSWORD`: postgres (dans Secret)

**Application** (dans `deployment.yaml`):
- `DB_HOST`: postgres-service
- `DB_PORT`: 5432
- `DB_NAME`: récupéré de la ConfigMap
- `DB_USER`: récupéré de la ConfigMap
- `DB_PASSWORD`: récupéré du Secret

### Modifier la configuration

```bash
# Éditer la ConfigMap
kubectl edit configmap postgres-config -n productapp

# Éditer le Secret (base64 encoded)
kubectl edit secret postgres-secret -n productapp

# Redémarrer les pods pour prendre en compte les changements
kubectl rollout restart deployment/productapp-deployment -n productapp
kubectl rollout restart statefulset/postgres -n productapp
```

### Scaler manuellement

```bash
# Scaler l'application
kubectl scale deployment productapp-deployment --replicas=5 -n productapp

# Note: Le HPA va override ce réglage si activé
```

## 🐛 Troubleshooting

### Les pods ne démarrent pas

```bash
# Voir les événements
kubectl get events -n productapp --sort-by='.lastTimestamp'

# Décrire un pod problématique
kubectl describe pod -n productapp <pod-name>

# Voir les logs d'init container
kubectl logs -n productapp <pod-name> -c wait-for-postgres
```

### L'app ne se connecte pas à PostgreSQL

```bash
# Vérifier que PostgreSQL est running
kubectl get pods -n productapp -l app=postgres

# Tester la résolution DNS
kubectl run -it --rm debug --image=busybox --restart=Never -n productapp -- nslookup postgres-service

# Tester la connexion
kubectl run -it --rm debug --image=postgres:16-alpine --restart=Never -n productapp -- \
  psql -h postgres-service -U postgres -d productdb
```

### PVC bloqué en Pending

```bash
# Vérifier les PVC
kubectl get pvc -n productapp

# Si Minikube, activer le provisionneur
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

# Vérifier les StorageClass disponibles
kubectl get storageclass
```

### Image non trouvée

```bash
# Pour Minikube
eval $(minikube docker-env)
docker build -t productapp:latest .

# Ou charger l'image
minikube image load productapp:latest

# Pour Kind
kind load docker-image productapp:latest
```

### Problème de ressources

```bash
# Vérifier les ressources du cluster
kubectl top nodes
kubectl top pods -n productapp

# Si insuffisant, augmenter les ressources Minikube
minikube delete
minikube start --cpus=4 --memory=8192
```

## 🧹 Nettoyage

### Supprimer l'application

```bash
# Supprimer toutes les ressources
kubectl delete -f k8s/

# Ou supprimer le namespace complet
kubectl delete namespace productapp
```

### Supprimer les PV (données)

```bash
# Les PV peuvent persister même après suppression du namespace
kubectl get pv
kubectl delete pv <pv-name>
```

### Reset complet

```bash
# Tout supprimer
kubectl delete namespace productapp

# Attendre que tout soit supprimé
kubectl get all -n productapp

# Les PVC peuvent être en état "Terminating"
# Forcer si nécessaire
kubectl patch pvc postgres-pvc -n productapp -p '{"metadata":{"finalizers":null}}'
```

## 📊 Ressources Kubernetes détaillées

| Ressource | Nom | Type | Réplicas | Stockage | Port |
|-----------|-----|------|----------|----------|------|
| StatefulSet | postgres | PostgreSQL 16 | 1 | 5Gi PVC | 5432 |
| Deployment | productapp-deployment | Java 21 App | 3 | - | 8080 |
| Service | postgres-service | ClusterIP (Headless) | - | - | 5432 |
| Service | productapp-service | LoadBalancer | - | - | 80→8080 |
| HPA | productapp-hpa | Auto-scale | 2-10 | - | - |
| PVC | postgres-pvc | Storage | - | 5Gi | - |

## 🎓 Points clés de l'architecture

✅ **StatefulSet pour PostgreSQL** : Garantit l'identité stable du pod et la persistance  
✅ **PersistentVolume** : Les données survivent aux redémarrages  
✅ **Init Container** : L'app attend que PostgreSQL soit prêt  
✅ **Headless Service** : Pour la communication directe avec le StatefulSet  
✅ **Secrets** : Mots de passe stockés de manière sécurisée  
✅ **Health Checks** : Liveness, Readiness et Startup probes  
✅ **Auto-scaling** : HPA basé sur CPU/RAM  
✅ **Network Policy** : Isolation réseau entre les pods  

---

**Bon déploiement sur Kubernetes ! 🚀**

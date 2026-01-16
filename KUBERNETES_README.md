# Déploiement Kubernetes - ProductApp avec Rancher

## Vue d'ensemble

Ce projet permet de déployer automatiquement :
- **ProductApp** : Application Java avec PostgreSQL
- **Rancher** : Interface de gestion de cluster Kubernetes

## Prérequis

- Docker Desktop avec Kubernetes activé
- kubectl configuré
- Cluster Kubernetes local (Docker Desktop, Minikube, ou Kind)

## Déploiement

### Déployer tout (ProductApp + Rancher)

```bash
./deploy-k8s.sh
```

Le script va :
1. Construire l'image Docker de ProductApp
2. Déployer PostgreSQL
3. Déployer ProductApp (3 replicas)
4. Déployer Rancher pour la gestion du cluster
5. Configurer les port-forwards

### Déployer uniquement ProductApp (sans Rancher)

```bash
DEPLOY_RANCHER=false ./deploy-k8s.sh
```

### Ports personnalisés

```bash
./deploy-k8s.sh latest 8080 9443
# - 8080 : port pour ProductApp (défaut: 8080)
# - 9443 : port pour Rancher (défaut: 8443)
```

## Accès aux applications

### ProductApp
- **Interface Web** : http://localhost:8080
- **API Health** : http://localhost:8080/api/health
- **API Products** : http://localhost:8080/api/products
- **API Stats** : http://localhost:8080/api/stats

### Rancher
- **Interface Web** : https://localhost:8443
- **Mot de passe initial** : `admin`
- ⚠️ Acceptez le certificat auto-signé dans votre navigateur
- ⚠️ Changez le mot de passe à la première connexion

## Commandes utiles

### Voir les logs

```bash
# Logs ProductApp
kubectl logs -n productapp -l app=productapp -f

# Logs PostgreSQL
kubectl logs -n productapp postgres-0 -f

# Logs Rancher
kubectl logs -n cattle-system -l app=rancher -f
```

### Voir l'état des pods

```bash
# ProductApp
kubectl get pods -n productapp

# Rancher
kubectl get pods -n cattle-system

# Tout
kubectl get pods --all-namespaces
```

### Accéder à la base de données

```bash
kubectl exec -it -n productapp postgres-0 -- psql -U postgres -d productdb
```

### Voir les services

```bash
kubectl get svc -n productapp
kubectl get svc -n cattle-system
```

## Arrêt du déploiement

### Arrêter tout (ProductApp + Rancher)

```bash
./stop-k8s.sh
```

### Arrêter en conservant les données

```bash
./stop-k8s.sh --keep-data
```

### Arrêter sans confirmation

```bash
./stop-k8s.sh --force
```

### Arrêter uniquement les port-forwards

```bash
# ProductApp
kill $(cat /tmp/productapp-port-forward.pid)

# Rancher
kill $(cat /tmp/rancher-port-forward.pid)
```

## Structure des fichiers Kubernetes

### ProductApp (dossier `k8s/`)
- `namespace.yaml` : Namespace productapp
- `postgres-*.yaml` : Configuration PostgreSQL (StatefulSet, PVC, ConfigMap, Secret)
- `deployment.yaml` : Déploiement de l'application (3 replicas)
- `service.yaml` : Service LoadBalancer
- `configmap.yaml` : Configuration de l'application
- `hpa.yaml` : Horizontal Pod Autoscaler
- `ingress.yaml` : Ingress Controller
- `networkpolicy.yaml` : Politique réseau
- `kustomization.yaml` : Configuration Kustomize

### Rancher (dossier `rancher/`)
- `namespace.yaml` : Namespace cattle-system
- `deployment.yaml` : Déploiement Rancher
- `service.yaml` : Service LoadBalancer
- `serviceaccount.yaml` : ServiceAccount et ClusterRoleBinding
- `pvc.yaml` : PersistentVolumeClaim (10Gi)
- `ingress.yaml` : Ingress Controller

## Fonctionnalités de Rancher

Une fois Rancher déployé, vous pouvez :
- Visualiser tous les pods, services, déploiements
- Gérer plusieurs clusters Kubernetes
- Surveiller les ressources (CPU, mémoire)
- Gérer les namespaces et les secrets
- Visualiser les logs en temps réel
- Exécuter des commandes dans les pods
- Gérer les ConfigMaps et les Secrets
- Déployer des applications via l'interface graphique

## Dépannage

### Rancher ne démarre pas

Rancher peut prendre 2-3 minutes à démarrer la première fois. Vérifiez les logs :

```bash
kubectl logs -n cattle-system -l app=rancher -f
```

### Port déjà utilisé

Si le port 8080 ou 8443 est déjà utilisé :

```bash
# Trouver le processus
lsof -ti:8080
lsof -ti:8443

# Arrêter le processus
kill $(lsof -ti:8080)
kill $(lsof -ti:8443)
```

### Problèmes de connexion au cluster

```bash
# Vérifier la connexion
kubectl cluster-info

# Vérifier les nodes
kubectl get nodes

# Redémarrer Docker Desktop si nécessaire
```

### Images non trouvées

Le script charge automatiquement les images dans le cluster local. Si vous utilisez un cluster distant, modifiez le script pour pusher vers un registry.

## Variables d'environnement

- `DEPLOY_RANCHER` : `true` ou `false` (défaut: `true`)
- `IMAGE_NAME` : Nom de l'image Docker (défaut: `productapp`)
- `IMAGE_TAG` : Tag de l'image (défaut: `latest`)

## Notes

- Le déploiement par défaut crée 3 replicas de ProductApp pour la haute disponibilité
- PostgreSQL utilise un StatefulSet avec un PersistentVolume de 5Gi
- Rancher utilise un PersistentVolume de 10Gi
- Les données sont conservées même après l'arrêt (sauf si `--force` est utilisé)
- Le HPA (Horizontal Pod Autoscaler) scale automatiquement de 2 à 10 replicas

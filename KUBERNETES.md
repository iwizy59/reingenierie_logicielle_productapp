# 🚀 Guide de Déploiement Kubernetes - ProductApp

Ce guide vous explique comment déployer l'application ProductApp dans un cluster Kubernetes.

## 📋 Table des Matières

- [Prérequis](#prérequis)
- [Architecture Kubernetes](#architecture-kubernetes)
- [Déploiement Rapide](#déploiement-rapide)
- [Déploiement Manuel](#déploiement-manuel)
- [Configuration Avancée](#configuration-avancée)
- [Monitoring et Logs](#monitoring-et-logs)
- [Troubleshooting](#troubleshooting)

---

## 🔧 Prérequis

### Outils nécessaires

```bash
# Docker
docker --version  # >= 20.10

# Kubernetes
kubectl version --client  # >= 1.25

# Optionnel - Pour cluster local
minikube version  # >= 1.30
# OU
kind version  # >= 0.20
```

### Cluster Kubernetes

Vous pouvez utiliser :
- **Minikube** (développement local)
- **Kind** (Kubernetes in Docker)
- **Docker Desktop** (Mac/Windows)
- **Cloud providers** (GKE, EKS, AKS)

---

## 🏗️ Architecture Kubernetes

```
┌─────────────────────────────────────────────────────┐
│                    Ingress                          │
│              (productapp.local)                     │
└────────────────────┬────────────────────────────────┘
                     │
         ┌───────────▼───────────┐
         │   Service (LB)        │
         │   Port: 80 → 8080     │
         └───────────┬───────────┘
                     │
    ┌────────────────┼────────────────┐
    │                │                │
┌───▼───┐       ┌───▼───┐       ┌───▼───┐
│ Pod 1 │       │ Pod 2 │       │ Pod 3 │
│ :8080 │       │ :8080 │       │ :8080 │
└───────┘       └───────┘       └───────┘
    │                │                │
    └────────────────┼────────────────┘
                     │
              ┌──────▼──────┐
              │     HPA     │
              │  (2-10 pods)│
              └─────────────┘
```

### Composants déployés

| Ressource | Description | Fichier |
|-----------|-------------|---------|
| **Namespace** | Isolation logique `productapp` | `namespace.yaml` |
| **Deployment** | 3 réplicas avec Rolling Update | `deployment.yaml` |
| **Service** | LoadBalancer exposant le port 80 | `service.yaml` |
| **ConfigMap** | Configuration de l'application | `configmap.yaml` |
| **HPA** | Auto-scaling (2-10 pods) | `hpa.yaml` |
| **Ingress** | Point d'entrée HTTP(S) | `ingress.yaml` |
| **NetworkPolicy** | Sécurité réseau | `networkpolicy.yaml` |

---

## ⚡ Déploiement Rapide

### Option 1: Script automatisé (Recommandé)

```bash
# Rendre le script exécutable
chmod +x build-and-deploy.sh

# Build et déploiement complet
./build-and-deploy.sh

# Ou avec un tag spécifique
./build-and-deploy.sh v1.0.0
```

### Option 2: Docker Compose (Test local)

```bash
# Lancer l'application avec Docker Compose
docker-compose up -d

# Accéder à l'application
open http://localhost:8080

# Arrêter
docker-compose down
```

---

## 🎯 Déploiement Manuel

### Étape 1: Build de l'image Docker

```bash
# Build de l'image
docker build -t productapp:latest .

# Vérifier l'image
docker images | grep productapp

# Tester localement (optionnel)
docker run -p 8080:8080 productapp:latest
```

### Étape 2: Déploiement sur Kubernetes

```bash
# Créer le namespace
kubectl apply -f k8s/namespace.yaml

# Déployer la ConfigMap
kubectl apply -f k8s/configmap.yaml

# Déployer l'application
kubectl apply -f k8s/deployment.yaml

# Créer le service
kubectl apply -f k8s/service.yaml

# Configurer l'auto-scaling
kubectl apply -f k8s/hpa.yaml

# Configurer l'ingress (optionnel)
kubectl apply -f k8s/ingress.yaml

# Appliquer la NetworkPolicy (optionnel)
kubectl apply -f k8s/networkpolicy.yaml
```

### Étape 3: Vérifier le déploiement

```bash
# Vérifier les pods
kubectl get pods -n productapp

# Vérifier les services
kubectl get svc -n productapp

# Vérifier le déploiement
kubectl rollout status deployment/productapp-deployment -n productapp
```

---

## 🌐 Accès à l'Application

### Méthode 1: Via LoadBalancer (Cloud)

```bash
# Récupérer l'IP externe
kubectl get svc productapp-service -n productapp

# Accéder via l'IP
curl http://<EXTERNAL-IP>/api/health
```

### Méthode 2: Via Port-Forward (Local)

```bash
# Port-forward vers un pod
kubectl port-forward -n productapp svc/productapp-service 8080:80

# Accéder à l'application
open http://localhost:8080
```

### Méthode 3: Via Ingress (Production)

```bash
# Installer Nginx Ingress Controller (si nécessaire)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Ajouter l'entrée DNS dans /etc/hosts (local)
echo "127.0.0.1 productapp.local" | sudo tee -a /etc/hosts

# Accéder via le nom de domaine
open http://productapp.local
```

### Méthode 4: Via Minikube

```bash
# Démarrer le tunnel (si vous utilisez Minikube)
minikube tunnel

# Ou utiliser le service minikube
minikube service productapp-service -n productapp
```

---

## 🔍 Monitoring et Logs

### Consulter les logs

```bash
# Logs de tous les pods
kubectl logs -n productapp -l app=productapp -f

# Logs d'un pod spécifique
kubectl logs -n productapp <pod-name> -f

# Logs des 100 dernières lignes
kubectl logs -n productapp <pod-name> --tail=100
```

### Surveiller les pods

```bash
# État des pods en temps réel
kubectl get pods -n productapp -w

# Détails d'un pod
kubectl describe pod -n productapp <pod-name>

# Ressources utilisées
kubectl top pods -n productapp
```

### Vérifier l'HPA

```bash
# État de l'auto-scaling
kubectl get hpa -n productapp

# Détails de l'HPA
kubectl describe hpa productapp-hpa -n productapp
```

### Tester les health checks

```bash
# Liveness probe
kubectl exec -n productapp <pod-name> -- wget -qO- http://localhost:8080/api/health

# Readiness probe
kubectl exec -n productapp <pod-name> -- wget -qO- http://localhost:8080/api/health
```

---

## ⚙️ Configuration Avancée

### Personnaliser les variables d'environnement

Modifier `k8s/deployment.yaml` :

```yaml
env:
- name: PORT
  value: "8080"
- name: JAVA_OPTS
  value: "-Xmx1g -Xms512m"
```

### Modifier le nombre de réplicas

```bash
# Via kubectl
kubectl scale deployment productapp-deployment -n productapp --replicas=5

# Ou modifier deployment.yaml
spec:
  replicas: 5
```

### Configurer les ressources

Modifier `k8s/deployment.yaml` :

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

### Activer HTTPS avec TLS

1. Créer un certificat TLS :

```bash
# Générer un certificat auto-signé (développement)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=productapp.local"

# Créer le secret Kubernetes
kubectl create secret tls productapp-tls \
  --cert=tls.crt --key=tls.key -n productapp
```

2. Décommenter la section TLS dans `k8s/ingress.yaml`

---

## 🧪 Tests de Résilience

### Test du crash endpoint

```bash
# Provoquer un crash
curl -X POST http://productapp.local/api/crash

# Kubernetes va automatiquement redémarrer le pod
kubectl get pods -n productapp -w
```

### Test de charge

```bash
# Installer Apache Bench ou hey
brew install hey  # macOS

# Générer de la charge
hey -z 60s -c 50 http://productapp.local/api/products

# Observer l'auto-scaling
kubectl get hpa -n productapp -w
```

### Rolling Update

```bash
# Mettre à jour l'image
kubectl set image deployment/productapp-deployment \
  productapp=productapp:v2.0.0 -n productapp

# Suivre le déploiement
kubectl rollout status deployment/productapp-deployment -n productapp

# Rollback si nécessaire
kubectl rollout undo deployment/productapp-deployment -n productapp
```

---

## 🐛 Troubleshooting

### Les pods ne démarrent pas

```bash
# Vérifier les événements
kubectl get events -n productapp --sort-by='.lastTimestamp'

# Décrire le pod
kubectl describe pod -n productapp <pod-name>

# Vérifier les logs
kubectl logs -n productapp <pod-name>
```

### Problème d'image Docker

```bash
# Si l'image n'est pas trouvée
# 1. Vérifier que l'image existe
docker images | grep productapp

# 2. Pour Minikube, utiliser le daemon Docker de Minikube
eval $(minikube docker-env)
docker build -t productapp:latest .

# 3. Ou charger l'image dans Minikube
minikube image load productapp:latest
```

### Service inaccessible

```bash
# Vérifier le service
kubectl get svc -n productapp

# Vérifier les endpoints
kubectl get endpoints -n productapp

# Tester depuis un pod
kubectl run -it --rm debug --image=alpine --restart=Never -n productapp -- sh
apk add curl
curl http://productapp-service/api/health
```

### HPA ne scale pas

```bash
# Vérifier que metrics-server est installé
kubectl get deployment metrics-server -n kube-system

# Installer metrics-server si nécessaire (Minikube)
minikube addons enable metrics-server

# Vérifier les métriques
kubectl top pods -n productapp
```

---

## 🧹 Nettoyage

### Supprimer l'application

```bash
# Supprimer toutes les ressources
kubectl delete -f k8s/

# Ou supprimer le namespace complet
kubectl delete namespace productapp
```

### Nettoyer les images Docker

```bash
# Supprimer les images
docker rmi productapp:latest

# Nettoyer les images inutilisées
docker system prune -a
```

---

## 📚 Ressources Additionnelles

- [Documentation Kubernetes](https://kubernetes.io/docs/)
- [Javalin Documentation](https://javalin.io/)
- [Hibernate Documentation](https://hibernate.org/orm/documentation/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

---

## 🎓 Exercices Pratiques

1. **Sécurité** : Ajouter des SecurityContext et PodSecurityPolicy
2. **Persistence** : Intégrer une base PostgreSQL avec PersistentVolume
3. **Monitoring** : Installer Prometheus et Grafana
4. **CI/CD** : Créer un pipeline GitLab/GitHub Actions
5. **Service Mesh** : Déployer avec Istio ou Linkerd

---

**Bon déploiement ! 🚀**

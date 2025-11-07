# 🐳 Guide Docker Compose - ProductApp avec PostgreSQL

## 📋 Architecture

```
┌─────────────────┐         ┌──────────────────┐
│   ProductApp    │◄───────►│   PostgreSQL     │
│   (Java 21)     │         │   (Port 5432)    │
│   Port 8080     │         │                  │
└─────────────────┘         └──────────────────┘
        │                            │
        └────────────────┬───────────┘
                         │
                  Docker Network
```

## 🚀 Démarrage

### Lancer les deux conteneurs

```bash
# Build et démarrage
docker-compose up -d --build

# Voir les logs
docker-compose logs -f

# Logs d'un service spécifique
docker-compose logs -f productapp
docker-compose logs -f postgres
```

### Vérifier l'état

```bash
# État des conteneurs
docker-compose ps

# Santé des services
docker-compose ps --format json | jq
```

## 🧪 Tester l'application

```bash
# Health check
curl http://localhost:8080/api/health

# Lister les produits
curl http://localhost:8080/api/products

# Créer un produit
curl -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Product",
    "description": "From Docker Compose",
    "price": "99.99",
    "quantity": 10
  }'

# Ou ouvrir dans le navigateur
open http://localhost:8080
```

## 🔧 Commandes utiles

### Gestion des conteneurs

```bash
# Arrêter les conteneurs
docker-compose stop

# Redémarrer les conteneurs
docker-compose restart

# Arrêter et supprimer
docker-compose down

# Supprimer avec les volumes (⚠️ efface les données)
docker-compose down -v
```

### Accès à la base de données

```bash
# Se connecter à PostgreSQL
docker exec -it productapp-postgres psql -U postgres -d productdb

# Commandes SQL utiles
\dt                          # Lister les tables
SELECT * FROM products;      # Voir les produits
\q                          # Quitter
```

### Logs et debug

```bash
# Logs en temps réel
docker-compose logs -f

# Les 100 dernières lignes
docker-compose logs --tail=100

# Exécuter des commandes dans un conteneur
docker-compose exec productapp sh
docker-compose exec postgres sh
```

### Rebuild

```bash
# Rebuild sans cache
docker-compose build --no-cache

# Rebuild et redémarrer
docker-compose up -d --build --force-recreate
```

## 🌍 Variables d'environnement

Configuration dans `docker-compose.yaml` :

### PostgreSQL
- `POSTGRES_DB`: productdb
- `POSTGRES_USER`: postgres
- `POSTGRES_PASSWORD`: postgres

### Application
- `DB_HOST`: postgres (nom du service)
- `DB_PORT`: 5432
- `DB_NAME`: productdb
- `DB_USER`: postgres
- `DB_PASSWORD`: postgres

## 📊 Volumes

### Volume PostgreSQL
Les données sont persistées dans un volume Docker :
```bash
# Lister les volumes
docker volume ls | grep productapp

# Inspecter le volume
docker volume inspect reingenierie_logicielle_productapp_postgres-data

# Supprimer le volume
docker volume rm reingenierie_logicielle_productapp_postgres-data
```

## 🔍 Troubleshooting

### L'app ne se connecte pas à la DB

```bash
# Vérifier que postgres est healthy
docker-compose ps

# Vérifier les logs de postgres
docker-compose logs postgres

# Tester la connexion depuis l'app
docker-compose exec productapp sh
nc -zv postgres 5432
```

### Reset complet

```bash
# Tout supprimer et recommencer
docker-compose down -v
docker-compose up -d --build
```

### Ports déjà utilisés

```bash
# Vérifier les ports
lsof -i :8080
lsof -i :5432

# Modifier les ports dans docker-compose.yaml si nécessaire
```

## 📈 Monitoring

### Ressources utilisées

```bash
# Stats en temps réel
docker stats productapp productapp-postgres

# Espace disque
docker system df
```

## 🎯 Prochaines étapes

✅ Les deux conteneurs fonctionnent séparément  
✅ Communication via réseau Docker  
✅ Données persistées dans PostgreSQL  

Maintenant vous pouvez :
1. ✅ Tester l'application localement
2. 🚀 Passer au déploiement Kubernetes avec PostgreSQL

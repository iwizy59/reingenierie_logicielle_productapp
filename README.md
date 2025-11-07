# Application Web - Réingénierie Logicielle

Application web de gestion de produits développée avec Java, Maven, Hibernate et base de données H2.

## 📋 Description

Cette application démontre une architecture en couches classique:
- **Modèle (Model)**: Entités JPA/Hibernate
- **DAO (Data Access Object)**: Accès aux données
- **Service**: Logique métier
- **Contrôleur**: API REST
- **Base de données**: H2 (base locale embarquée)

## 🛠️ Technologies

- **Java 21 (LTS)**
- **Maven** - Gestion de dépendances
- **Hibernate 6.3** - ORM
- **H2 Database** - Base de données embarquée
- **Javalin 5.6** - Framework web léger
- **Jackson** - Sérialisation JSON

## 📦 Structure du projet

```
src/
├── main/
│   ├── java/com/reingenierie/
│   │   ├── Main.java                    # Point d'entrée
│   │   ├── model/
│   │   │   └── Product.java             # Entité Product
│   │   ├── dao/
│   │   │   └── ProductDAO.java          # Accès aux données
│   │   ├── service/
│   │   │   └── ProductService.java      # Logique métier
│   │   ├── controller/
│   │   │   └── ProductController.java   # API REST
│   │   └── util/
│   │       └── HibernateUtil.java       # Configuration Hibernate
│   └── resources/
│       ├── META-INF/
│       │   └── persistence.xml          # Configuration JPA
│       └── public/
│           └── index.html               # Interface web
pom.xml                                   # Configuration Maven
```

## 🚀 Installation et Lancement

### Prérequis
- Java JDK 21 (recommendé) ou supérieur
- Maven 3.6+

### Compilation

```powershell
mvn clean install
```

### Lancement de l'application

```powershell
mvn exec:java -Dexec.mainClass="com.reingenierie.Main"
```

Ou avec le JAR compilé:

```powershell
java -jar target/webapp-demo-1.0-SNAPSHOT.jar
```

L'application démarre sur **http://localhost:8080**

## 🔌 API REST

### Endpoints disponibles

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/` | Page d'accueil |
| GET | `/api/health` | Vérification de santé |
| GET | `/api/products` | Liste tous les produits |
| GET | `/api/products/{id}` | Récupère un produit par ID |
| POST | `/api/products` | Crée un nouveau produit |
| PUT | `/api/products/{id}` | Met à jour un produit |
| DELETE | `/api/products/{id}` | Supprime un produit |
| GET | `/api/products/search?name=xxx` | Recherche par nom |
| PATCH | `/api/products/{id}/stock` | Modifie le stock |
| GET | `/api/stats` | Statistiques |
| POST | `/api/crash` | Crash l'application (pour tests K8s) |

### Exemples de requêtes

#### Créer un produit
```bash
curl -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Laptop",
    "description": "Ordinateur portable performant",
    "price": "999.99",
    "quantity": 10
  }'
```

#### Lister les produits
```bash
curl http://localhost:8080/api/products
```

#### Supprimer un produit
```bash
curl -X DELETE http://localhost:8080/api/products/1
```

## 💾 Base de données

La base de données H2 est stockée localement dans `./data/webapp-demo.mv.db`

Pour accéder à la console H2:
- URL JDBC: `jdbc:h2:./data/webapp-demo`
- Utilisateur: `sa`
- Mot de passe: _(vide)_

## 🧪 Test de l'application

1. Ouvrez votre navigateur sur http://localhost:8080
2. Utilisez l'interface web pour ajouter des produits
3. Testez les endpoints API avec curl ou Postman

## 🐛 Endpoint de "crash" pour Kubernetes

L'endpoint `/api/crash` permet de tester la résilience de Kubernetes:

```bash
curl -X POST http://localhost:8080/api/crash
```

Cet endpoint arrête l'application après 1 seconde, permettant de voir Kubernetes redémarrer automatiquement le pod.

## 📝 Variables d'environnement

- `PORT` - Port d'écoute (défaut: 8080)

## 🔧 Développement

### Modifier le code
Après modification, recompilez avec:
```powershell
mvn clean package
```

### Activer les logs SQL
Les requêtes SQL sont affichées dans la console (configuré dans `persistence.xml`)

## 📄 Licence

Projet éducatif - Réingénierie Logicielle

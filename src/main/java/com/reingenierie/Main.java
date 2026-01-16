package com.reingenierie;

import java.util.Map;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.reingenierie.controller.ProductController;
import com.reingenierie.service.ProductService;
import com.reingenierie.util.DataInitializer;
import com.reingenierie.util.HibernateUtil;
import io.javalin.Javalin;
import io.javalin.http.staticfiles.Location;
import io.javalin.json.JavalinJackson;

public class Main {
    
    public static void main(String[] args) {
        // Port par défaut ou depuis variable d'environnement
        int port = getPort();
        
        // Initialiser Hibernate au démarrage
        System.out.println("Initialisation de l'application...");
        HibernateUtil.getEntityManager().close();
        
        // Initialiser les données mockées (seulement si INIT_MOCK_DATA=true)
        // 12-Factor App : Principe XII - Admin Processes
        // L'initialisation devrait être une tâche one-off via com.reingenierie.admin.DataSeed
        ProductService productService = new ProductService();
        String initMockData = System.getenv().getOrDefault("INIT_MOCK_DATA", "false");
        if ("true".equalsIgnoreCase(initMockData)) {
            System.out.println("⚠️  INIT_MOCK_DATA=true - Initialisation des données au démarrage");
            System.out.println("   (Recommandé : utiliser com.reingenierie.admin.DataSeed en one-off)");
            DataInitializer dataInitializer = new DataInitializer(productService);
            dataInitializer.initializeMockData();
        } else {
            System.out.println("✅ INIT_MOCK_DATA=false - Pas d'initialisation automatique");
            System.out.println("   Pour initialiser : kubectl run data-seed --image=productapp:latest -- java -cp app.jar com.reingenierie.admin.DataSeed");
        }
        
        // Configurer Jackson pour supporter LocalDateTime (Java 8 Date/Time)
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule());
        objectMapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        
        // Créer l'application Javalin
        Javalin app = Javalin.create(config -> {
            config.jsonMapper(new JavalinJackson(objectMapper));
            config.staticFiles.add("/public", Location.CLASSPATH);
            config.plugins.enableCors(cors -> {
                cors.add(it -> {
                    it.anyHost();
                });
            });
        }).start(port);
        
        System.out.println("Application démarrée sur le port " + port);
        
        // Contrôleur
        ProductController productController = new ProductController();
        
        // Routes API - La route "/" sert automatiquement index.html grâce aux fichiers statiques
        // app.get("/", ctx -> ctx.result("Application de Réingénierie Logicielle - API REST"));
        
        app.get("/api/health", ctx -> {
            // Vérifier la connexion DB
            try {
                productService.getAllProducts(); // Test DB
                ctx.json(Map.of("status", "UP", "database", "connected"));
            } catch (Exception e) {
                ctx.status(503).json(Map.of("status", "DOWN", "database", "disconnected"));
            }
        });
        
        // CRUD Products
        app.get("/api/products", productController::getAllProducts);
        app.get("/api/products/{id}", productController::getProductById);
        app.post("/api/products", productController::createProduct);
        app.put("/api/products/{id}", productController::updateProduct);
        app.delete("/api/products/{id}", productController::deleteProduct);
        
        // Recherche et statistiques
        app.get("/api/products/search", productController::searchProducts);
        app.patch("/api/products/{id}/stock", productController::updateStock);
        app.get("/api/stats", productController::getStats);
        
        // Endpoint pour "casser" l'application (pour tests Kubernetes)
        app.post("/api/crash", ctx -> {
            System.err.println("Endpoint /api/crash appelé - Arrêt de l'application!");
            ctx.result("Application en cours d'arrêt...");
            new Thread(() -> {
                try {
                    Thread.sleep(1000);
                    System.exit(1);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }).start();
        });
        
        // Hook d'arrêt propre
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            System.out.println("Arrêt de l'application...");
            app.stop();
            HibernateUtil.shutdown();
            System.out.println("Application arrêtée proprement.");
        }));
    }
    
    private static int getPort() {
        String portEnv = System.getenv("PORT");
        int port = 8080; // Port par défaut
        if (portEnv != null) {
            try {
                port = Integer.parseInt(portEnv);
            } catch (NumberFormatException e) {
                System.err.println("PORT invalide '" + portEnv + "', utilisation du port par défaut: 8080");
                port = 8080;
            }
        }
        return port;
    }
    
    public static class HealthResponse {
        public String status;
        public String message;
        
        public HealthResponse(String status, String message) {
            this.status = status;
            this.message = message;
        }
    }
}

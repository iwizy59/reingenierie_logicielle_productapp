package com.reingenierie;

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
        
        // Initialiser les données mockées
        ProductService productService = new ProductService();
        DataInitializer dataInitializer = new DataInitializer(productService);
        dataInitializer.initializeMockData();
        
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
        
        app.get("/api/health", ctx -> ctx.json(new HealthResponse("OK", "Application en cours d'exécution")));
        
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
        if (portEnv != null && !portEnv.isEmpty()) {
            try {
                return Integer.parseInt(portEnv);
            } catch (NumberFormatException e) {
                System.err.println("Port invalide dans la variable d'environnement, utilisation du port 8080");
            }
        }
        return 8080;
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

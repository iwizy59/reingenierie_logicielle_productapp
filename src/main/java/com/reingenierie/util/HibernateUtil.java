package com.reingenierie.util;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.Persistence;
import java.util.HashMap;
import java.util.Map;

public class HibernateUtil {
    
    private static final EntityManagerFactory entityManagerFactory;
    
    static {
        EntityManagerFactory tempFactory = null;
        
        // Configuration du retry logic depuis variables d'environnement
        int maxRetries = getEnvAsInt("DB_MAX_RETRIES", 10);
        int retryDelay = getEnvAsInt("DB_RETRY_DELAY_MS", 5000); // millisecondes
        
        // Récupérer les variables d'environnement pour la configuration de la DB
        Map<String, String> props = new HashMap<>();
        
        String dbHost = System.getenv().getOrDefault("DB_HOST", "localhost");
        String dbPort = System.getenv().getOrDefault("DB_PORT", "5432");
        String dbName = System.getenv().getOrDefault("DB_NAME", "productdb");
        String dbUser = System.getenv().getOrDefault("DB_USER", "postgres");
        String dbPassword = System.getenv().getOrDefault("DB_PASSWORD", "postgres");
        
        String jdbcUrl = String.format("jdbc:postgresql://%s:%s/%s", dbHost, dbPort, dbName);
        
        // Forcer PostgreSQL
        props.put("jakarta.persistence.jdbc.driver", "org.postgresql.Driver");
        props.put("jakarta.persistence.jdbc.url", jdbcUrl);
        props.put("jakarta.persistence.jdbc.user", dbUser);
        props.put("jakarta.persistence.jdbc.password", dbPassword);
        props.put("hibernate.dialect", "org.hibernate.dialect.PostgreSQLDialect");
        
        System.out.println("========================================");
        System.out.println("Configuration Base de Données:");
        System.out.println("  Host: " + dbHost);
        System.out.println("  Port: " + dbPort);
        System.out.println("  Database: " + dbName);
        System.out.println("  User: " + dbUser);
        System.out.println("  JDBC URL: " + jdbcUrl);
        System.out.println("Configuration Retry:");
        System.out.println("  Max Retries: " + maxRetries);
        System.out.println("  Retry Delay: " + retryDelay + "ms");
        System.out.println("========================================");
        
        // Retry logic pour la connexion à PostgreSQL
        for (int attempt = 1; attempt <= maxRetries; attempt++) {
            try {
                System.out.println("Tentative de connexion " + attempt + "/" + maxRetries + "...");
                tempFactory = Persistence.createEntityManagerFactory("webapp-demo-pu", props);
                System.out.println("✓ EntityManagerFactory créé avec succès");
                break;
            } catch (Exception ex) {
                System.err.println("Échec tentative " + attempt + ": " + ex.getMessage());
                if (attempt < maxRetries) {
                    try {
                        System.out.println("Attente de " + (retryDelay/1000) + "s avant nouvelle tentative...");
                        Thread.sleep(retryDelay);
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        throw new ExceptionInInitializerError("Interrupted during retry");
                    }
                } else {
                    System.err.println("Échec après " + maxRetries + " tentatives");
                    throw new ExceptionInInitializerError(ex);
                }
            }
        }
        
        entityManagerFactory = tempFactory;
    }
    
    public static EntityManager getEntityManager() {
        return entityManagerFactory.createEntityManager();
    }
    
    public static void shutdown() {
        if (entityManagerFactory != null && entityManagerFactory.isOpen()) {
            entityManagerFactory.close();
        }
    }
    
    /**
     * Récupère une variable d'environnement en tant qu'entier avec une valeur par défaut
     * @param envName Nom de la variable d'environnement
     * @param defaultValue Valeur par défaut si la variable n'existe pas ou est invalide
     * @return La valeur de la variable d'environnement ou la valeur par défaut
     */
    private static int getEnvAsInt(String envName, int defaultValue) {
        String value = System.getenv(envName);
        if (value != null && !value.isEmpty()) {
            try {
                return Integer.parseInt(value);
            } catch (NumberFormatException e) {
                System.err.println("Valeur invalide pour " + envName + ": " + value + 
                                   ". Utilisation de la valeur par défaut: " + defaultValue);
            }
        }
        return defaultValue;
    }
}

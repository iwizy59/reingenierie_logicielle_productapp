package com.reingenierie.admin;

import com.reingenierie.util.HibernateUtil;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityTransaction;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * DBMigrate - Tâche admin one-off pour les migrations de base de données
 * 
 * Principe 12-Factor : XII. Admin Processes
 * 
 * Fonctionnalités :
 * - Création de la table schema_migrations si inexistante
 * - Exécution idempotente (skip si déjà appliquée)
 * - Versioning des migrations
 * - Logs détaillés
 * - Rollback en cas d'erreur
 * 
 * Usage:
 *   java -cp app.jar com.reingenierie.admin.DBMigrate [version]
 *   
 * Exemples:
 *   java -cp app.jar com.reingenierie.admin.DBMigrate           # Toutes les migrations
 *   java -cp app.jar com.reingenierie.admin.DBMigrate 001       # Migration v001 seulement
 *   java -cp app.jar com.reingenierie.admin.DBMigrate --status  # Afficher le statut
 */
public class DBMigrate {
    
    private static final String MIGRATIONS_TABLE = "schema_migrations";
    
    /**
     * Liste des migrations à appliquer (versionnées)
     * Format : Migration(version, description, sql)
     */
    private static final List<Migration> MIGRATIONS = List.of(
        new Migration(
            "001",
            "Création de la table schema_migrations",
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version VARCHAR(10) PRIMARY KEY,
                description VARCHAR(255) NOT NULL,
                applied_at TIMESTAMP NOT NULL,
                execution_time_ms BIGINT NOT NULL,
                success BOOLEAN NOT NULL DEFAULT TRUE
            );
            """
        ),
        new Migration(
            "002",
            "Ajout d'index sur products.name",
            """
            CREATE INDEX IF NOT EXISTS idx_products_name 
            ON products(name);
            """
        ),
        new Migration(
            "003",
            "Ajout d'index sur products.category",
            """
            CREATE INDEX IF NOT EXISTS idx_products_category 
            ON products(category);
            """
        )
        // Ajouter ici de futures migrations...
    );
    
    public static void main(String[] args) {
        printHeader();
        
        long startTime = System.currentTimeMillis();
        int applied = 0;
        int skipped = 0;
        
        try {
            // Mode : status only
            if (args.length > 0 && "--status".equals(args[0])) {
                printStatus();
                System.exit(0);
            }
            
            // Mode : version spécifique
            String targetVersion = args.length > 0 ? args[0] : null;
            
            // Initialiser Hibernate
            EntityManager em = HibernateUtil.getEntityManager();
            em.close();
            
            // Obtenir une connexion JDBC directe pour les migrations
            Connection conn = getJdbcConnection();
            
            System.out.println("✅ Connexion à la base de données établie");
            System.out.println("   → Host: " + System.getenv().getOrDefault("DB_HOST", "localhost"));
            System.out.println("   → Database: " + System.getenv().getOrDefault("DB_NAME", "productdb"));
            System.out.println("");
            
            // Créer la table de migrations si elle n'existe pas
            ensureMigrationsTableExists(conn);
            
            // Exécuter les migrations
            for (Migration migration : MIGRATIONS) {
                // Si version spécifiée, skip les autres
                if (targetVersion != null && !migration.version.equals(targetVersion)) {
                    continue;
                }
                
                if (isMigrationApplied(conn, migration.version)) {
                    System.out.println("⏭️  Migration " + migration.version + " : DÉJÀ APPLIQUÉE");
                    System.out.println("   → " + migration.description);
                    skipped++;
                } else {
                    System.out.println("🔄 Migration " + migration.version + " : EN COURS...");
                    System.out.println("   → " + migration.description);
                    
                    long migrationStart = System.currentTimeMillis();
                    applyMigration(conn, migration);
                    long migrationTime = System.currentTimeMillis() - migrationStart;
                    
                    System.out.println("✅ Migration " + migration.version + " : SUCCÈS (" + migrationTime + "ms)");
                    applied++;
                }
                System.out.println("");
            }
            
            conn.close();
            
            // Rapport final
            printFooter(applied, skipped, System.currentTimeMillis() - startTime);
            
            // Fermer proprement Hibernate
            HibernateUtil.shutdown();
            System.out.println("🛑 Connexions DB fermées proprement");
            System.out.println("");
            
            System.exit(0);
            
        } catch (Exception e) {
            System.err.println("");
            System.err.println("========================================");
            System.err.println("❌ ERREUR lors des migrations");
            System.err.println("========================================");
            System.err.println("Message : " + e.getMessage());
            e.printStackTrace();
            System.err.println("");
            
            // Fermer proprement Hibernate
            try {
                HibernateUtil.shutdown();
            } catch (Exception shutdownEx) {
                // Ignorer les erreurs de shutdown
            }
            
            System.exit(1);
        }
    }
    
    /**
     * Obtenir une connexion JDBC directe (pour exécuter du SQL brut)
     */
    private static Connection getJdbcConnection() throws SQLException {
        String host = System.getenv().getOrDefault("DB_HOST", "localhost");
        String port = System.getenv().getOrDefault("DB_PORT", "5432");
        String dbName = System.getenv().getOrDefault("DB_NAME", "productdb");
        String user = System.getenv().getOrDefault("DB_USER", "postgres");
        String password = System.getenv().getOrDefault("DB_PASSWORD", "postgres");
        
        String url = "jdbc:postgresql://" + host + ":" + port + "/" + dbName;
        
        return DriverManager.getConnection(url, user, password);
    }
    
    /**
     * Créer la table schema_migrations si elle n'existe pas
     */
    private static void ensureMigrationsTableExists(Connection conn) throws SQLException {
        String createTableSql = """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version VARCHAR(10) PRIMARY KEY,
                description VARCHAR(255) NOT NULL,
                applied_at TIMESTAMP NOT NULL,
                execution_time_ms BIGINT NOT NULL,
                success BOOLEAN NOT NULL DEFAULT TRUE
            );
            """;
        
        try (Statement stmt = conn.createStatement()) {
            stmt.execute(createTableSql);
        }
    }
    
    /**
     * Vérifier si une migration a déjà été appliquée
     */
    private static boolean isMigrationApplied(Connection conn, String version) throws SQLException {
        String checkSql = "SELECT COUNT(*) FROM " + MIGRATIONS_TABLE + " WHERE version = ? AND success = TRUE";
        
        try (PreparedStatement stmt = conn.prepareStatement(checkSql)) {
            stmt.setString(1, version);
            
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1) > 0;
                }
            }
        }
        
        return false;
    }
    
    /**
     * Appliquer une migration
     */
    private static void applyMigration(Connection conn, Migration migration) throws SQLException {
        long startTime = System.currentTimeMillis();
        
        // Désactiver l'autocommit pour gérer la transaction manuellement
        conn.setAutoCommit(false);
        
        try {
            // Exécuter le SQL de la migration
            try (Statement stmt = conn.createStatement()) {
                stmt.execute(migration.sql);
            }
            
            // Enregistrer la migration dans schema_migrations
            long executionTime = System.currentTimeMillis() - startTime;
            recordMigration(conn, migration, executionTime, true);
            
            // Commit la transaction
            conn.commit();
            
        } catch (SQLException e) {
            // Rollback en cas d'erreur
            conn.rollback();
            
            // Enregistrer l'échec (si possible)
            try {
                long executionTime = System.currentTimeMillis() - startTime;
                recordMigration(conn, migration, executionTime, false);
                conn.commit();
            } catch (SQLException recordEx) {
                // Ignorer les erreurs d'enregistrement
            }
            
            throw e;
        } finally {
            // Réactiver l'autocommit
            conn.setAutoCommit(true);
        }
    }
    
    /**
     * Enregistrer une migration dans la table schema_migrations
     */
    private static void recordMigration(Connection conn, Migration migration, long executionTimeMs, boolean success) throws SQLException {
        String insertSql = """
            INSERT INTO schema_migrations (version, description, applied_at, execution_time_ms, success)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT (version) DO UPDATE 
            SET applied_at = EXCLUDED.applied_at,
                execution_time_ms = EXCLUDED.execution_time_ms,
                success = EXCLUDED.success;
            """;
        
        try (PreparedStatement stmt = conn.prepareStatement(insertSql)) {
            stmt.setString(1, migration.version);
            stmt.setString(2, migration.description);
            stmt.setTimestamp(3, Timestamp.from(Instant.now()));
            stmt.setLong(4, executionTimeMs);
            stmt.setBoolean(5, success);
            
            stmt.executeUpdate();
        }
    }
    
    /**
     * Afficher le statut des migrations
     */
    private static void printStatus() {
        try {
            Connection conn = getJdbcConnection();
            
            System.out.println("📊 Statut des migrations");
            System.out.println("");
            System.out.println("┌──────────┬─────────────────────────────────────────┬─────────────┬──────────┐");
            System.out.println("│ Version  │ Description                             │ Status      │ Durée    │");
            System.out.println("├──────────┼─────────────────────────────────────────┼─────────────┼──────────┤");
            
            for (Migration migration : MIGRATIONS) {
                boolean applied = isMigrationApplied(conn, migration.version);
                String status = applied ? "✅ Appliquée" : "⏳ En attente";
                String duration = applied ? getMigrationDuration(conn, migration.version) : "-";
                
                System.out.printf("│ %-8s │ %-39s │ %-11s │ %-8s │%n",
                    migration.version,
                    truncate(migration.description, 39),
                    status,
                    duration);
            }
            
            System.out.println("└──────────┴─────────────────────────────────────────┴─────────────┴──────────┘");
            System.out.println("");
            
            conn.close();
            
        } catch (Exception e) {
            System.err.println("❌ Erreur lors de la récupération du statut : " + e.getMessage());
            System.exit(1);
        }
    }
    
    /**
     * Récupérer la durée d'exécution d'une migration
     */
    private static String getMigrationDuration(Connection conn, String version) throws SQLException {
        String sql = "SELECT execution_time_ms FROM " + MIGRATIONS_TABLE + " WHERE version = ?";
        
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, version);
            
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    long ms = rs.getLong(1);
                    return ms + "ms";
                }
            }
        }
        
        return "-";
    }
    
    /**
     * Tronquer une chaîne
     */
    private static String truncate(String str, int maxLength) {
        if (str.length() <= maxLength) {
            return str;
        }
        return str.substring(0, maxLength - 3) + "...";
    }
    
    /**
     * Afficher l'en-tête
     */
    private static void printHeader() {
        System.out.println("");
        System.out.println("========================================");
        System.out.println("🔧 DBMigrate - Migrations de base de données");
        System.out.println("========================================");
        System.out.println("");
    }
    
    /**
     * Afficher le pied de page
     */
    private static void printFooter(int applied, int skipped, long totalTime) {
        System.out.println("========================================");
        System.out.println("✅ Migrations terminées avec succès");
        System.out.println("========================================");
        System.out.println("📊 Rapport :");
        System.out.println("   → Migrations appliquées : " + applied);
        System.out.println("   → Migrations skippées   : " + skipped);
        System.out.println("   → Durée totale          : " + totalTime + "ms");
        System.out.println("");
    }
    
    /**
     * Classe interne représentant une migration
     */
    private static class Migration {
        final String version;
        final String description;
        final String sql;
        
        Migration(String version, String description, String sql) {
            this.version = version;
            this.description = description;
            this.sql = sql;
        }
    }
}

package com.reingenierie.admin;

import com.reingenierie.service.ProductService;
import com.reingenierie.util.DataInitializer;
import com.reingenierie.util.HibernateUtil;

/**
 * Tâche admin one-off : Initialisation des données de test
 * 
 * Cette classe doit être exécutée manuellement une seule fois après le déploiement initial.
 * Conforme au principe XII des 12-Factor Apps (Admin Processes).
 * 
 * Usage:
 *   java -cp app.jar com.reingenierie.admin.DataSeed
 * 
 * Kubernetes:
 *   kubectl run data-seed --rm -it --image=productapp:latest \
 *     --restart=Never --namespace=productapp \
 *     -- java -cp app.jar com.reingenierie.admin.DataSeed
 */
public class DataSeed {
    
    public static void main(String[] args) {
        long startTime = System.currentTimeMillis();
        
        System.out.println("========================================");
        System.out.println("🌱 DataSeed - Initialisation des données");
        System.out.println("========================================");
        System.out.println();
        
        try {
            // Créer le service
            ProductService productService = new ProductService();
            
            // Vérifier si des données existent déjà (idempotence)
            int existingProducts = productService.getAllProducts().size();
            
            if (existingProducts > 0) {
                System.out.println("⚠️  Base de données non vide :");
                System.out.println("   → " + existingProducts + " produit(s) existant(s)");
                System.out.println();
                System.out.println("❌ Initialisation annulée (idempotence)");
                System.out.println("   Pour forcer la réinitialisation :");
                System.out.println("   1. Supprimer manuellement les produits");
                System.out.println("   2. Ou ajouter un flag --force (à implémenter)");
                System.out.println();
                System.exit(0);
            }
            
            System.out.println("✅ Base de données vide - Démarrage de l'initialisation...");
            System.out.println();
            
            // Initialiser les données
            DataInitializer dataInitializer = new DataInitializer(productService);
            dataInitializer.initializeMockData();
            
            // Vérifier le résultat
            int insertedProducts = productService.getAllProducts().size();
            long duration = System.currentTimeMillis() - startTime;
            
            System.out.println();
            System.out.println("========================================");
            System.out.println("✅ Initialisation terminée avec succès");
            System.out.println("========================================");
            System.out.println("📊 Rapport :");
            System.out.println("   → Produits insérés : " + insertedProducts);
            System.out.println("   → Durée : " + duration + "ms");
            System.out.println();
            
            // Succès
            System.exit(0);
            
        } catch (Exception e) {
            System.err.println();
            System.err.println("========================================");
            System.err.println("❌ ERREUR lors de l'initialisation");
            System.err.println("========================================");
            System.err.println("Message : " + e.getMessage());
            System.err.println();
            System.err.println("Stack trace :");
            e.printStackTrace();
            System.err.println();
            
            // Échec
            System.exit(1);
            
        } finally {
            // Toujours fermer Hibernate proprement
            try {
                HibernateUtil.shutdown();
                System.out.println("🛑 Connexions DB fermées proprement");
            } catch (Exception e) {
                System.err.println("⚠️  Erreur lors de la fermeture : " + e.getMessage());
            }
        }
    }
}

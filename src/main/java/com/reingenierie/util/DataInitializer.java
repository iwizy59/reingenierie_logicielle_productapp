package com.reingenierie.util;

import com.reingenierie.model.Product;
import com.reingenierie.service.ProductService;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * Classe utilitaire pour initialiser la base de données avec des données mockées
 */
public class DataInitializer {
    
    private final ProductService productService;
    
    public DataInitializer(ProductService productService) {
        this.productService = productService;
    }
    
    /**
     * Initialise la base de données avec des produits mockés
     */
    public void initializeMockData() {
        // Vérifier si des données existent déjà
        if (!productService.getAllProducts().isEmpty()) {
            System.out.println("Des données existent déjà dans la base de données. Initialisation ignorée.");
            return;
        }
        
        System.out.println("Initialisation des données mockées...");
        
        List<Product> mockProducts = createMockProducts();
        
        for (Product product : mockProducts) {
            productService.createProduct(
                product.getName(),
                product.getDescription(),
                product.getPrice(),
                product.getQuantity()
            );
        }
        
        System.out.println(mockProducts.size() + " produits mockés ont été ajoutés à la base de données.");
    }
    
    /**
     * Crée une liste de produits mockés pour les tests
     */
    private List<Product> createMockProducts() {
        List<Product> products = new ArrayList<>();
        
        products.add(createProduct(
            "Laptop Dell XPS 15",
            "Ordinateur portable haute performance avec écran 15.6 pouces, processeur Intel Core i7, 16GB RAM, SSD 512GB",
            new BigDecimal("1299.99"),
            15
        ));
        
        products.add(createProduct(
            "iPhone 15 Pro",
            "Smartphone Apple avec écran Super Retina XDR 6.1 pouces, puce A17 Pro, appareil photo 48MP",
            new BigDecimal("1199.00"),
            25
        ));
        
        products.add(createProduct(
            "Sony WH-1000XM5",
            "Casque audio sans fil à réduction de bruit, Bluetooth, autonomie 30h",
            new BigDecimal("349.99"),
            40
        ));
        
        products.add(createProduct(
            "Samsung Galaxy Tab S9",
            "Tablette Android 11 pouces, écran AMOLED, S Pen inclus, 128GB",
            new BigDecimal("799.00"),
            12
        ));
        
        products.add(createProduct(
            "Logitech MX Master 3S",
            "Souris sans fil ergonomique, 8000 DPI, rechargeable, compatible multi-appareils",
            new BigDecimal("99.99"),
            50
        ));
        
        products.add(createProduct(
            "Apple MacBook Air M2",
            "Ordinateur portable ultra-léger, puce M2, écran Retina 13.6 pouces, 8GB RAM, 256GB SSD",
            new BigDecimal("1449.00"),
            8
        ));
        
        products.add(createProduct(
            "Nintendo Switch OLED",
            "Console de jeux portable et de salon, écran OLED 7 pouces, 64GB",
            new BigDecimal("349.99"),
            20
        ));
        
        products.add(createProduct(
            "Canon EOS R6",
            "Appareil photo hybride plein format, 20.1MP, vidéo 4K, stabilisation IBIS",
            new BigDecimal("2499.00"),
            5
        ));
        
        products.add(createProduct(
            "Samsung 55\" QLED 4K",
            "Téléviseur QLED 55 pouces, résolution 4K, HDR10+, Smart TV",
            new BigDecimal("899.99"),
            10
        ));
        
        products.add(createProduct(
            "Kindle Paperwhite",
            "Liseuse électronique étanche, écran 6.8 pouces, éclairage intégré, 16GB",
            new BigDecimal("139.99"),
            35
        ));
        
        products.add(createProduct(
            "iPad Pro 12.9\"",
            "Tablette Apple avec puce M2, écran Liquid Retina XDR, 128GB, compatible Apple Pencil",
            new BigDecimal("1099.00"),
            7
        ));
        
        products.add(createProduct(
            "Bose SoundLink Revolve+",
            "Enceinte Bluetooth portable 360°, résistante à l'eau, autonomie 17h",
            new BigDecimal("299.00"),
            18
        ));
        
        products.add(createProduct(
            "Microsoft Surface Pro 9",
            "Tablette PC hybride, écran tactile 13 pouces, processeur Intel Core i5, 8GB RAM",
            new BigDecimal("1199.99"),
            9
        ));
        
        products.add(createProduct(
            "GoPro HERO12 Black",
            "Caméra d'action 5.3K, stabilisation HyperSmooth 6.0, étanche 10m",
            new BigDecimal("449.99"),
            22
        ));
        
        products.add(createProduct(
            "Dyson V15 Detect",
            "Aspirateur sans fil avec laser et écran LCD, autonomie 60 min",
            new BigDecimal("699.00"),
            6
        ));
        
        return products;
    }
    
    /**
     * Méthode helper pour créer un produit
     */
    private Product createProduct(String name, String description, BigDecimal price, int quantity) {
        Product product = new Product();
        product.setName(name);
        product.setDescription(description);
        product.setPrice(price);
        product.setQuantity(quantity);
        return product;
    }
}

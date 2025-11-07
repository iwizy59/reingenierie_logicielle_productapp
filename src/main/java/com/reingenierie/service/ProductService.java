package com.reingenierie.service;

import com.reingenierie.dao.ProductDAO;
import com.reingenierie.model.Product;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

public class ProductService {
    
    private final ProductDAO productDAO;
    
    public ProductService() {
        this.productDAO = new ProductDAO();
    }
    
    public Product createProduct(String name, String description, BigDecimal price, Integer quantity) {
        validateProduct(name, price, quantity);
        
        Product product = new Product(name, description, price, quantity);
        return productDAO.create(product);
    }
    
    public Optional<Product> getProductById(Long id) {
        if (id == null || id <= 0) {
            throw new IllegalArgumentException("L'ID du produit doit être positif");
        }
        return productDAO.findById(id);
    }
    
    public List<Product> getAllProducts() {
        return productDAO.findAll();
    }
    
    public List<Product> searchProductsByName(String name) {
        if (name == null || name.trim().isEmpty()) {
            throw new IllegalArgumentException("Le nom de recherche ne peut pas être vide");
        }
        return productDAO.findByName(name);
    }
    
    public Product updateProduct(Long id, String name, String description, BigDecimal price, Integer quantity) {
        validateProduct(name, price, quantity);
        
        Optional<Product> existingProduct = productDAO.findById(id);
        if (existingProduct.isEmpty()) {
            throw new IllegalArgumentException("Produit non trouvé avec l'ID: " + id);
        }
        
        Product product = existingProduct.get();
        product.setName(name);
        product.setDescription(description);
        product.setPrice(price);
        product.setQuantity(quantity);
        
        return productDAO.update(product);
    }
    
    public void deleteProduct(Long id) {
        if (id == null || id <= 0) {
            throw new IllegalArgumentException("L'ID du produit doit être positif");
        }
        productDAO.delete(id);
    }
    
    public long getProductCount() {
        return productDAO.count();
    }
    
    public boolean updateStock(Long id, int quantityChange) {
        Optional<Product> productOpt = productDAO.findById(id);
        if (productOpt.isEmpty()) {
            return false;
        }
        
        Product product = productOpt.get();
        int newQuantity = product.getQuantity() + quantityChange;
        
        if (newQuantity < 0) {
            throw new IllegalArgumentException("Stock insuffisant. Quantité actuelle: " + product.getQuantity());
        }
        
        product.setQuantity(newQuantity);
        productDAO.update(product);
        return true;
    }
    
    private void validateProduct(String name, BigDecimal price, Integer quantity) {
        if (name == null || name.trim().isEmpty()) {
            throw new IllegalArgumentException("Le nom du produit est obligatoire");
        }
        if (price == null || price.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("Le prix doit être positif ou nul");
        }
        if (quantity == null || quantity < 0) {
            throw new IllegalArgumentException("La quantité doit être positive ou nulle");
        }
    }
}

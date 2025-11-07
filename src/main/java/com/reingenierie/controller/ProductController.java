package com.reingenierie.controller;

import com.reingenierie.model.Product;
import com.reingenierie.service.ProductService;
import io.javalin.http.Context;
import io.javalin.http.HttpStatus;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

public class ProductController {
    
    private final ProductService productService;
    
    public ProductController() {
        this.productService = new ProductService();
    }
    
    public void getAllProducts(Context ctx) {
        try {
            List<Product> products = productService.getAllProducts();
            ctx.json(products).status(HttpStatus.OK);
        } catch (Exception e) {
            ctx.json(new ErrorResponse("Erreur lors de la récupération des produits: " + e.getMessage()))
               .status(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    
    public void getProductById(Context ctx) {
        try {
            Long id = Long.parseLong(ctx.pathParam("id"));
            Optional<Product> product = productService.getProductById(id);
            
            if (product.isPresent()) {
                ctx.json(product.get()).status(HttpStatus.OK);
            } else {
                ctx.json(new ErrorResponse("Produit non trouvé"))
                   .status(HttpStatus.NOT_FOUND);
            }
        } catch (NumberFormatException e) {
            ctx.json(new ErrorResponse("ID invalide"))
               .status(HttpStatus.BAD_REQUEST);
        } catch (Exception e) {
            ctx.json(new ErrorResponse("Erreur: " + e.getMessage()))
               .status(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    
    public void createProduct(Context ctx) {
        try {
            ProductRequest request = ctx.bodyAsClass(ProductRequest.class);
            
            Product product = productService.createProduct(
                request.name,
                request.description,
                new BigDecimal(request.price),
                request.quantity
            );
            
            ctx.json(product).status(HttpStatus.CREATED);
        } catch (IllegalArgumentException e) {
            ctx.json(new ErrorResponse(e.getMessage()))
               .status(HttpStatus.BAD_REQUEST);
        } catch (Exception e) {
            ctx.json(new ErrorResponse("Erreur lors de la création: " + e.getMessage()))
               .status(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    
    public void updateProduct(Context ctx) {
        try {
            Long id = Long.parseLong(ctx.pathParam("id"));
            ProductRequest request = ctx.bodyAsClass(ProductRequest.class);
            
            Product product = productService.updateProduct(
                id,
                request.name,
                request.description,
                new BigDecimal(request.price),
                request.quantity
            );
            
            ctx.json(product).status(HttpStatus.OK);
        } catch (NumberFormatException e) {
            ctx.json(new ErrorResponse("ID invalide"))
               .status(HttpStatus.BAD_REQUEST);
        } catch (IllegalArgumentException e) {
            ctx.json(new ErrorResponse(e.getMessage()))
               .status(HttpStatus.BAD_REQUEST);
        } catch (Exception e) {
            ctx.json(new ErrorResponse("Erreur lors de la mise à jour: " + e.getMessage()))
               .status(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    
    public void deleteProduct(Context ctx) {
        try {
            Long id = Long.parseLong(ctx.pathParam("id"));
            productService.deleteProduct(id);
            ctx.json(new SuccessResponse("Produit supprimé avec succès"))
               .status(HttpStatus.OK);
        } catch (NumberFormatException e) {
            ctx.json(new ErrorResponse("ID invalide"))
               .status(HttpStatus.BAD_REQUEST);
        } catch (Exception e) {
            ctx.json(new ErrorResponse("Erreur lors de la suppression: " + e.getMessage()))
               .status(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    
    public void searchProducts(Context ctx) {
        try {
            String name = ctx.queryParam("name");
            if (name == null || name.trim().isEmpty()) {
                ctx.json(new ErrorResponse("Le paramètre 'name' est requis"))
                   .status(HttpStatus.BAD_REQUEST);
                return;
            }
            
            List<Product> products = productService.searchProductsByName(name);
            ctx.json(products).status(HttpStatus.OK);
        } catch (Exception e) {
            ctx.json(new ErrorResponse("Erreur lors de la recherche: " + e.getMessage()))
               .status(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    
    public void updateStock(Context ctx) {
        try {
            Long id = Long.parseLong(ctx.pathParam("id"));
            StockUpdateRequest request = ctx.bodyAsClass(StockUpdateRequest.class);
            
            boolean success = productService.updateStock(id, request.quantityChange);
            if (success) {
                ctx.json(new SuccessResponse("Stock mis à jour avec succès"))
                   .status(HttpStatus.OK);
            } else {
                ctx.json(new ErrorResponse("Produit non trouvé"))
                   .status(HttpStatus.NOT_FOUND);
            }
        } catch (NumberFormatException e) {
            ctx.json(new ErrorResponse("ID invalide"))
               .status(HttpStatus.BAD_REQUEST);
        } catch (IllegalArgumentException e) {
            ctx.json(new ErrorResponse(e.getMessage()))
               .status(HttpStatus.BAD_REQUEST);
        } catch (Exception e) {
            ctx.json(new ErrorResponse("Erreur: " + e.getMessage()))
               .status(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    
    public void getStats(Context ctx) {
        try {
            long count = productService.getProductCount();
            ctx.json(new StatsResponse(count)).status(HttpStatus.OK);
        } catch (Exception e) {
            ctx.json(new ErrorResponse("Erreur: " + e.getMessage()))
               .status(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    
    // DTOs
    public static class ProductRequest {
        public String name;
        public String description;
        public String price;
        public Integer quantity;
    }
    
    public static class StockUpdateRequest {
        public int quantityChange;
    }
    
    public static class ErrorResponse {
        public String error;
        public ErrorResponse(String error) {
            this.error = error;
        }
    }
    
    public static class SuccessResponse {
        public String message;
        public SuccessResponse(String message) {
            this.message = message;
        }
    }
    
    public static class StatsResponse {
        public long totalProducts;
        public StatsResponse(long totalProducts) {
            this.totalProducts = totalProducts;
        }
    }
}

-- Script d'initialisation de la base de données PostgreSQL
-- Ce script est exécuté automatiquement au premier démarrage

-- Créer la base de données si elle n'existe pas (déjà créée via POSTGRES_DB)
-- CREATE DATABASE IF NOT EXISTS productdb;

-- Se connecter à la base
\c productdb;

-- Créer l'extension pour les UUID si nécessaire
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Message de confirmation
SELECT 'Base de données productdb initialisée avec succès !' AS status;

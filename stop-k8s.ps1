###############################################################################
# Script pour arreter proprement le deploiement Kubernetes (PowerShell)
# Usage: .\stop-k8s.ps1 [-Force] [-KeepData]
# Options:
#   -Force      : Supprime sans confirmation
#   -KeepData   : Conserve les PersistentVolumeClaims (donnees PostgreSQL)
###############################################################################

param(
    [switch]$Force,
    [switch]$KeepData
)

$ErrorActionPreference = "Stop"

# Variables
$NAMESPACE = "productapp"
$PID_FILE = "$env:TEMP\productapp-port-forward.pid"

# Couleurs pour la console
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Magenta
}

Write-Host "`n========================================" -ForegroundColor Blue
Write-Host "  Arret de ProductApp Kubernetes" -ForegroundColor Blue
Write-Host "========================================`n" -ForegroundColor Blue

# Arreter tous les port-forwards actifs sur le port 8080
Write-Info "Recherche des port-forwards actifs..."
$processes = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue | 
             Select-Object -ExpandProperty OwningProcess -Unique

if ($processes) {
    Write-Info "Arret des port-forwards sur le port 8080..."
    foreach ($pid in $processes) {
        try {
            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        } catch {
            # Ignorer les erreurs
        }
    }
    Write-Info "Port-forwards arretes"
} else {
    Write-Info "Aucun port-forward actif sur le port 8080"
}

# Arreter le port-forward via le fichier PID
if (Test-Path $PID_FILE) {
    $jobId = Get-Content $PID_FILE -ErrorAction SilentlyContinue
    if ($jobId) {
        try {
            $job = Get-Job -Id $jobId -ErrorAction SilentlyContinue
            if ($job) {
                Write-Info "Arret du port-forward (Job ID: $jobId)..."
                Stop-Job -Id $jobId -ErrorAction SilentlyContinue
                Remove-Job -Id $jobId -ErrorAction SilentlyContinue
                Write-Info "Port-forward arrete"
            }
        } catch {
            # Ignorer les erreurs
        }
    }
    Remove-Item $PID_FILE -Force -ErrorAction SilentlyContinue
}

# Vérifier si le namespace existe
try {
    $null = kubectl get namespace $NAMESPACE 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Le namespace $NAMESPACE n'existe pas"
        exit 0
    }
} catch {
    Write-Warn "Le namespace $NAMESPACE n'existe pas"
    exit 0
}

# Afficher les ressources actuelles
Write-Host ""
Write-Info "Ressources actuelles dans le namespace ${NAMESPACE}:"
kubectl get all,pvc,networkpolicy -n $NAMESPACE
Write-Host ""

# Option pour supprimer toutes les ressources
$deleteResources = $Force
if (-not $Force) {
    $response = Read-Host "Voulez-vous supprimer toutes les ressources Kubernetes? (y/N)"
    $deleteResources = ($response -eq 'y' -or $response -eq 'Y')
}

if ($deleteResources) {
    Write-Info "Suppression des ressources Kubernetes..."
    
    if ($KeepData) {
        Write-Warn "Conservation des PersistentVolumeClaims (donnees PostgreSQL)"
        
        # Supprimer les ressources sauf les PVC
        Write-Info "Suppression du HPA..."
        kubectl delete hpa --all -n $NAMESPACE --ignore-not-found=true
        
        Write-Info "Suppression de l'Ingress..."
        kubectl delete ingress --all -n $NAMESPACE --ignore-not-found=true
        
        Write-Info "Suppression de la NetworkPolicy..."
        kubectl delete networkpolicy --all -n $NAMESPACE --ignore-not-found=true
        
        Write-Info "Suppression du Deployment..."
        kubectl delete deployment productapp-deployment -n $NAMESPACE --ignore-not-found=true
        
        Write-Info "Suppression du StatefulSet PostgreSQL..."
        kubectl delete statefulset postgres -n $NAMESPACE --ignore-not-found=true
        
        Write-Info "Suppression des Services..."
        kubectl delete service --all -n $NAMESPACE --ignore-not-found=true
        
        Write-Info "Suppression des ConfigMaps et Secrets..."
        kubectl delete configmap --all -n $NAMESPACE --ignore-not-found=true
        kubectl delete secret --all -n $NAMESPACE --ignore-not-found=true
        
        Write-Host ""
        Write-Success "Ressources supprimees (PVC conserves)"
        
        Write-Host ""
        Write-Info "PersistentVolumeClaims conserves:"
        kubectl get pvc -n $NAMESPACE
        Write-Host ""
        Write-Warn "Pour supprimer les donnees, executez:"
        Write-Warn "  kubectl delete pvc --all -n $NAMESPACE"
        Write-Warn "  kubectl delete namespace $NAMESPACE"
    } else {
        Write-Info "Suppression complete du namespace (incluant les donnees)..."
        kubectl delete namespace $NAMESPACE --timeout=60s
        Write-Success "Namespace et toutes les ressources supprimes"
    }
} else {
    Write-Info "Les ressources Kubernetes sont conservees"
    Write-Info "Les pods continuent de tourner dans le namespace: $NAMESPACE"
}

Write-Host ""
Write-Success "========================================="
Write-Success "Arret termine!"
Write-Success "========================================="
Write-Host ""

# Afficher un recapitulatif
if ($deleteResources) {
    if (-not $KeepData) {
        Write-Info "Pour redemarrer l'application:"
        Write-Host "  .\deploy-k8s.ps1" -ForegroundColor Yellow
    } else {
        Write-Info "Pour redemarrer l'application avec les donnees existantes:"
        Write-Host "  .\deploy-k8s.ps1" -ForegroundColor Yellow
        Write-Host ""
        Write-Info "Les donnees PostgreSQL seront automatiquement reutilisees"
    }
}

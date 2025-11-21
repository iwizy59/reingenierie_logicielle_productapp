###############################################################################
# Script pour arrêter proprement le déploiement Kubernetes (PowerShell)
# Usage : .\stop-k8s.ps1 [-Force] [-KeepData]
# Options :
#   -Force      : Supprime sans confirmation
#   -KeepData   : Conserve les PersistentVolumeClaims (données PostgreSQL)
###############################################################################

param(
    [switch]$Force,
    [switch]$KeepData
)

$ErrorActionPreference = "Stop"

# Variables
$NAMESPACE = "productapp"
$PID_FILE = "$env:TEMP\productapp-port-forward.pid"

# Fonctions d'affichage
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Error-Custom { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Success { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Magenta }

Write-Host "`n========================================" -ForegroundColor Blue
Write-Host "  Arrêt de ProductApp Kubernetes" -ForegroundColor Blue
Write-Host "========================================`n" -ForegroundColor Blue

###############################################################################
# Arrêt du port-forward
###############################################################################

Write-Info "Recherche des port-forwards actifs..."
$processes = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique

if ($processes) {
    Write-Info "Arrêt des port-forwards sur le port 8080..."
    foreach ($pid in $processes) {
        try {
            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    Write-Info "Port-forwards arrêtés"
} else {
    Write-Info "Aucun port-forward actif sur le port 8080"
}

# Arrêt du port-forward via PID
if (Test-Path $PID_FILE) {
    $jobId = Get-Content $PID_FILE -ErrorAction SilentlyContinue
    if ($jobId) {
        try {
            $job = Get-Job -Id $jobId -ErrorAction SilentlyContinue
            if ($job) {
                Write-Info "Arrêt du port-forward (Job ID : $jobId)..."
                Stop-Job -Id $jobId -ErrorAction SilentlyContinue
                Remove-Job -Id $jobId -ErrorAction SilentlyContinue
                Write-Info "Port-forward arrêté"
            }
        } catch {}
    }
    Remove-Item $PID_FILE -Force -ErrorAction SilentlyContinue
}

###############################################################################
# Vérification du namespace
###############################################################################

try {
    kubectl get namespace $NAMESPACE *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Le namespace $NAMESPACE n'existe pas"
        exit 0
    }
} catch {
    Write-Warn "Le namespace $NAMESPACE n'existe pas"
    exit 0
}

###############################################################################
# Affichage des ressources existantes
###############################################################################

Write-Host ""
Write-Info "Ressources actuelles dans le namespace $NAMESPACE :"
kubectl get all,pvc,networkpolicy -n $NAMESPACE
Write-Host ""

###############################################################################
# Demande confirmation si -Force non utilisé
###############################################################################

$deleteResources = $Force
if (-not $Force) {
    $response = Read-Host "Voulez-vous supprimer toutes les ressources Kubernetes ? (y/N)"
    $deleteResources = ($response -eq 'y' -or $response -eq 'Y')
}

###############################################################################
# Suppression des ressources
###############################################################################

if ($deleteResources) {

    if ($KeepData) {
        Write-Warn "Conservation des PersistentVolumeClaims (données PostgreSQL)"

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
        Write-Success "Ressources supprimées (PVC conservés)"

        Write-Host ""
        Write-Info "PersistentVolumeClaims conservés :"
        kubectl get pvc -n $NAMESPACE

        Write-Host ""
        Write-Warn "Pour supprimer les données, exécutez :"
        Write-Warn "  kubectl delete pvc --all -n $NAMESPACE"
        Write-Warn "  kubectl delete namespace $NAMESPACE"

    } else {

        Write-Info "Suppression complète du namespace (incluant les données)..."
        kubectl delete namespace $NAMESPACE --timeout=60s
        Write-Success "Namespace et toutes les ressources supprimés"
    }

} else {
    Write-Info "Les ressources Kubernetes sont conservées."
    Write-Info "Les pods continuent de tourner dans le namespace : $NAMESPACE"
}

###############################################################################
# Fin
###############################################################################

Write-Host ""
Write-Success "========================================="
Write-Success "Arrêt terminé !"
Write-Success "========================================="
Write-Host ""

###############################################################################
# Instructions de redémarrage
###############################################################################

if ($deleteResources) {
    if (-not $KeepData) {
        Write-Info "Pour redémarrer l'application :"
        Write-Host "  .\deploy-k8s.ps1" -ForegroundColor Yellow
    } else {
        Write-Info "Pour redémarrer l'application avec les données existantes :"
        Write-Host "  .\deploy-k8s.ps1" -ForegroundColor Yellow
        Write-Host ""
        Write-Info "Les données PostgreSQL seront automatiquement réutilisées"
    }
}

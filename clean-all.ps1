###############################################################################
# Script de nettoyage complet (PowerShell)
# Usage: .\clean-all.ps1 [-NoConfirm]
# Description: Supprime TOUT - namespace, images Docker, caches
###############################################################################

param(
    [switch]$NoConfirm
)

$ErrorActionPreference = "Stop"

# Variables
$NAMESPACE = "productapp"
$IMAGE_NAME = "productapp"

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

Write-Host "`n========================================" -ForegroundColor Red
Write-Host "  NETTOYAGE COMPLET ProductApp" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Red

Write-Warn "⚠️  Ce script va supprimer:"
Write-Host "   - Le namespace Kubernetes '$NAMESPACE' et TOUTES ses ressources"
Write-Host "   - Les PersistentVolumeClaims (TOUTES LES DONNÉES PostgreSQL)"
Write-Host "   - Les images Docker '$IMAGE_NAME'"
Write-Host "   - Les caches Docker"
Write-Host "   - Les port-forwards actifs"
Write-Host ""

if (-not $NoConfirm) {
    $response = Read-Host "Êtes-vous ABSOLUMENT SÛR de vouloir continuer? (tapez 'yes' pour confirmer)"
    if ($response -ne 'yes') {
        Write-Info "Opération annulée"
        exit 0
    }
}

Write-Host ""
Write-Warn "🔥 Début du nettoyage complet..."
Write-Host ""

# 1. Arrêter les port-forwards
Write-Info "1️⃣  Arrêt des port-forwards..."
$processes = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue | 
             Select-Object -ExpandProperty OwningProcess -Unique

if ($processes) {
    foreach ($pid in $processes) {
        try {
            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        } catch {
            # Ignorer les erreurs
        }
    }
    Write-Info "✓ Port-forwards arrêtés"
} else {
    Write-Info "✓ Aucun port-forward actif"
}

$PID_FILE = "$env:TEMP\productapp-port-forward.pid"
if (Test-Path $PID_FILE) {
    $jobId = Get-Content $PID_FILE -ErrorAction SilentlyContinue
    if ($jobId) {
        try {
            Stop-Job -Id $jobId -ErrorAction SilentlyContinue
            Remove-Job -Id $jobId -ErrorAction SilentlyContinue
        } catch {
            # Ignorer les erreurs
        }
    }
    Remove-Item $PID_FILE -Force -ErrorAction SilentlyContinue
}

# 2. Supprimer le namespace Kubernetes
Write-Info "2️⃣  Suppression du namespace Kubernetes..."
try {
    $null = kubectl get namespace $NAMESPACE 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Warn "Suppression de toutes les ressources dans $NAMESPACE..."
        kubectl delete namespace $NAMESPACE --timeout=120s
        Write-Info "✓ Namespace supprimé"
    } else {
        Write-Info "✓ Namespace déjà supprimé"
    }
} catch {
    Write-Info "✓ Namespace déjà supprimé"
}

# 3. Supprimer les images Docker
Write-Info "3️⃣  Suppression des images Docker..."
try {
    $images = docker images --filter=reference="$IMAGE_NAME" --format "{{.ID}}" 2>$null
    if ($images) {
        $images | ForEach-Object {
            docker rmi -f $_ 2>$null | Out-Null
        }
        Write-Info "✓ Images Docker supprimées"
    } else {
        Write-Info "✓ Aucune image à supprimer"
    }
} catch {
    Write-Info "✓ Aucune image à supprimer"
}

# 4. Nettoyer le cache Docker
Write-Info "4️⃣  Nettoyage du cache Docker..."
try {
    docker builder prune -f 2>$null | Out-Null
    Write-Info "✓ Cache Docker nettoyé"
} catch {
    Write-Warn "Impossible de nettoyer le cache Docker"
}

# 5. Supprimer les fichiers temporaires
Write-Info "5️⃣  Nettoyage des fichiers temporaires..."
$tempFiles = @(
    "$env:TEMP\port-forward.log",
    "$env:TEMP\productapp-port-forward.pid"
)

foreach ($file in $tempFiles) {
    if (Test-Path $file) {
        Remove-Item $file -Force -ErrorAction SilentlyContinue
    }
}
Write-Info "✓ Fichiers temporaires supprimés"

# 6. Nettoyer les volumes Docker orphelins
Write-Info "6️⃣  Nettoyage des volumes Docker orphelins..."
try {
    docker volume prune -f 2>$null | Out-Null
    Write-Info "✓ Volumes orphelins supprimés"
} catch {
    Write-Warn "Impossible de nettoyer les volumes Docker"
}

Write-Host ""
Write-Success "========================================="
Write-Success "✓ Nettoyage complet terminé!"
Write-Success "========================================="
Write-Host ""

# Vérification finale
Write-Info "📊 Vérification finale:"
Write-Host ""

Write-Info "Namespaces Kubernetes:"
try {
    $namespaces = kubectl get namespaces -o name 2>$null | Select-String $NAMESPACE
    if (-not $namespaces) {
        Write-Info "  ✓ Namespace $NAMESPACE bien supprimé"
    }
} catch {
    Write-Info "  ✓ Namespace $NAMESPACE bien supprimé"
}
Write-Host ""

Write-Info "Images Docker ${IMAGE_NAME}:"
try {
    $images = docker images --filter=reference="$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}" 2>$null
    if (-not $images) {
        Write-Info "  ✓ Toutes les images supprimées"
    } else {
        $images | ForEach-Object { Write-Host "  - $_" }
    }
} catch {
    Write-Info "  ✓ Toutes les images supprimées"
}
Write-Host ""

Write-Info "Port-forwards actifs sur 8080:"
$processes = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
if (-not $processes) {
    Write-Info "  ✓ Aucun port-forward actif"
} else {
    $processes | ForEach-Object { Write-Host "  - PID: $($_.OwningProcess)" }
}
Write-Host ""

Write-Success "Le système est maintenant propre!"
Write-Info "Pour redéployer l'application, exécutez:"
Write-Host "  .\deploy-k8s.ps1" -ForegroundColor Yellow
Write-Host ""

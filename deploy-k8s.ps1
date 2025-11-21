##############################################################################################################
# Script de déploiement Kubernetes avec PostgreSQL (PowerShell)
# Description : Déploie l'application ProductApp avec PostgreSQL sur Kubernetes
# Usage       : .\deploy-k8s.ps1 [ImageTag] [Port]
# Exemple     : .\deploy-k8s.ps1 latest 8080
##############################################################################################################

param(
    [string]$ImageTag = "latest",
    [int]$PortForwardPort = 8080
)

$ErrorActionPreference = "Stop"

# Variables
$IMAGE_NAME = "productapp"
$NAMESPACE = "productapp"
$K8S_DIR = "k8s"
$PID_FILE = "$env:TEMP\productapp-port-forward.pid"
$LOG_FILE = "$env:TEMP\port-forward.log"

# Fonctions d'affichage
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Error-Custom { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Success { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Magenta }

function Write-Header {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Blue
    Write-Host "  $Message" -ForegroundColor Blue
    Write-Host "========================================`n" -ForegroundColor Blue
}

Write-Header "Déploiement Kubernetes ProductApp avec PostgreSQL"

##############################################################################################################
# Vérification des prérequis
##############################################################################################################

function Test-Prerequisites {
    Write-Info "Vérification des prérequis..."

    try { docker --version } catch {
        Write-Error-Custom "Docker n'est pas installé ou pas dans le PATH"
        exit 1
    }

    try { kubectl version --client=true 2>$null } catch {
        Write-Error-Custom "kubectl n'est pas installé ou pas dans le PATH"
        exit 1
    }

    try {
        kubectl cluster-info *> $null
        if ($LASTEXITCODE -ne 0) { throw }
    } catch {
        Write-Error-Custom "Impossible de se connecter au cluster Kubernetes"
        exit 1
    }

    Write-Success "Prérequis OK"
}

##############################################################################################################
# Téléchargement des images nécessaires
##############################################################################################################

function Get-RequiredImages {
    Write-Info "Téléchargement des images nécessaires..."

    if (-not (docker images busybox:1.36 --format "{{.Repository}}:{{.Tag}}" | Select-String "busybox:1.36")) {
        Write-Info "Téléchargement de busybox:1.36..."
        docker pull busybox:1.36
    } else {
        Write-Info "busybox:1.36 déjà présent"
    }

    if (-not (docker images postgres:16-alpine --format "{{.Repository}}:{{.Tag}}" | Select-String "postgres:16-alpine")) {
        Write-Info "Téléchargement de postgres:16-alpine..."
        docker pull postgres:16-alpine
    } else {
        Write-Info "postgres:16-alpine déjà présent"
    }

    Write-Success "Images nécessaires prêtes"
}

##############################################################################################################
# Build Docker
##############################################################################################################

function Build-DockerImage {
    Write-Info "Build de l'image Docker : ${IMAGE_NAME}:${ImageTag}"

    docker build -t "${IMAGE_NAME}:${ImageTag}" .

    if ($LASTEXITCODE -eq 0) {
        docker tag "${IMAGE_NAME}:${ImageTag}" "${IMAGE_NAME}:latest"
        Write-Success "Image Docker construite"
    } else {
        Write-Error-Custom "Échec du build Docker"
        exit 1
    }
}

##############################################################################################################
# Import image dans le cluster
##############################################################################################################

function Import-ImageToCluster {
    Write-Info "Chargement de l'image dans le cluster..."

    # Minikube
    try {
        minikube status *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Minikube détecté - chargement..."
            minikube image load "${IMAGE_NAME}:latest"
            Write-Success "Image chargée dans Minikube"
            return
        }
    } catch {}

    # Kind
    try {
        $kindClusters = kind get clusters 2>$null
        if ($LASTEXITCODE -eq 0 -and $kindClusters) {
            $clusterName = $kindClusters[0]
            Write-Info "Kind détecté - cluster : $clusterName"
            kind load docker-image "${IMAGE_NAME}:latest" --name $clusterName
            Write-Success "Image chargée dans Kind"
            return
        }
    } catch {}

    Write-Warn "Cluster local non détecté"
    Write-Warn "Utilisez un registry si cluster cloud"
}

##############################################################################################################
# Déploiement Kubernetes
##############################################################################################################

function Deploy-ToK8s {
    Write-Info "Déploiement Kubernetes..."

    kubectl apply -f "$K8S_DIR/namespace.yaml"

    Write-Info "Déploiement PostgreSQL..."
    kubectl apply -f "$K8S_DIR/postgres-configmap.yaml"
    kubectl apply -f "$K8S_DIR/postgres-secret.yaml"
    kubectl apply -f "$K8S_DIR/postgres-pvc.yaml"
    kubectl apply -f "$K8S_DIR/postgres-statefulset.yaml"
    kubectl apply -f "$K8S_DIR/postgres-service.yaml"

    Write-Info "Attente PostgreSQL..."
    kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=120s

    Write-Info "Déploiement App..."
    kubectl apply -f "$K8S_DIR/configmap.yaml"
    kubectl apply -f "$K8S_DIR/deployment.yaml"
    kubectl apply -f "$K8S_DIR/service.yaml"
    kubectl apply -f "$K8S_DIR/hpa.yaml"
    kubectl apply -f "$K8S_DIR/ingress.yaml"
    kubectl apply -f "$K8S_DIR/networkpolicy.yaml"

    Write-Success "Ressources Kubernetes déployées"
}

##############################################################################################################
# Vérification du déploiement
##############################################################################################################

function Test-Deployment {
    Write-Info "Vérification du déploiement..."

    kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=60s

    kubectl rollout status deployment/productapp-deployment -n $NAMESPACE --timeout=300s

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Déploiement réussi"
    } else {
        Write-Error-Custom "Échec du déploiement"
        exit 1
    }
}

##############################################################################################################
# Port-forward : cleanup
##############################################################################################################

function Stop-OldPortForwards {
    Write-Info "Nettoyage des anciens port-forward..."

    $processes = Get-NetTCPConnection -LocalPort $PortForwardPort -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique

    foreach ($pid in $processes) {
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $PID_FILE) {
        $oldPid = Get-Content $PID_FILE -ErrorAction SilentlyContinue
        Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
        Remove-Item $PID_FILE -Force
    }

    Write-Success "Ancien port-forward stoppé"
}

##############################################################################################################
# Port-forward : start
##############################################################################################################

function Start-PortForward {
    Write-Info "Démarrage du port-forward sur ${PortForwardPort}..."

    $job = Start-Job -ScriptBlock {
        param($ns, $port, $logFile)
        kubectl port-forward -n $ns svc/productapp-service "$port:80" 2>&1 | Out-File $logFile
    } -ArgumentList $NAMESPACE, $PortForwardPort, $LOG_FILE

    $job.Id | Out-File $PID_FILE
    Start-Sleep 3

    if ($job.State -eq "Running") {
        Write-Success "Port-forward actif : http://localhost:${PortForwardPort}"
    } else {
        Write-Error-Custom "Échec port-forward"
        return $false
    }

    return $true
}

##############################################################################################################
# Test API
##############################################################################################################

function Test-Application {
    Write-Info "Tests API..."

    Start-Sleep 2

    try {
        $response = Invoke-WebRequest "http://localhost:${PortForwardPort}/api/health" -TimeoutSec 5
        Write-Success "Health check OK"
    } catch {
        Write-Warn "Health check échoué"
    }

    try {
        $response = Invoke-RestMethod "http://localhost:${PortForwardPort}/api/products" -TimeoutSec 5
        Write-Success "API Products OK ($($response.Count) produits)"
    } catch {
        Write-Warn "Impossible de tester l'API Products"
    }
}

##############################################################################################################
# Informations
##############################################################################################################

function Show-Info {
    Write-Host "`n=== Informations ===" -ForegroundColor Cyan

    Write-Host "PostgreSQL:" -ForegroundColor Yellow
    kubectl get statefulset,pod,pvc -n $NAMESPACE -l app=postgres

    Write-Host "`nApplication:" -ForegroundColor Yellow
    kubectl get pods -n $NAMESPACE -l app=productapp -o wide

    Write-Host "`nServices:" -ForegroundColor Yellow
    kubectl get svc -n $NAMESPACE

    Write-Host "`nHPA:" -ForegroundColor Yellow
    kubectl get hpa -n $NAMESPACE

    Write-Host "`nPVC:" -ForegroundColor Yellow
    kubectl get pvc -n $NAMESPACE

    Write-Host "`nAccès : http://localhost:${PortForwardPort}" -ForegroundColor Magenta
}

##############################################################################################################
# Fonction principale
##############################################################################################################

function Main {
    try {
        Test-Prerequisites
        Get-RequiredImages
        Build-DockerImage
        Import-ImageToCluster
        Deploy-ToK8s
        Test-Deployment
        Stop-OldPortForwards
        $ok = Start-PortForward
        if ($ok) { Test-Application }
        Show-Info
        Write-Success "Déploiement terminé avec succès 🎉"
    } catch {
        Write-Error-Custom "Erreur : $_"
        exit 1
    }
}

##############################################################################################################
# Execution
##############################################################################################################

Main
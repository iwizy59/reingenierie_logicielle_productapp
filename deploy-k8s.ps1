###############################################################################
# Script de deploiement Kubernetes avec PostgreSQL (PowerShell)
# Description: Deploie l'application ProductApp avec PostgreSQL sur K8s
# Usage: .\deploy-k8s.ps1 [ImageTag] [Port]
# Exemple: .\deploy-k8s.ps1 latest 8080
###############################################################################

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

function Write-Header {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Blue
    Write-Host "  $Message" -ForegroundColor Blue
    Write-Host "========================================`n" -ForegroundColor Blue
}

Write-Header "Deploiement Kubernetes ProductApp avec PostgreSQL"

# Verifier les prerequis
function Test-Prerequisites {
    Write-Info "Verification des prerequis..."
    
    # Verifier Docker
    try {
        $null = docker --version
    } catch {
        Write-Error-Custom "Docker n'est pas installe ou n'est pas dans le PATH"
        exit 1
    }
    
    # Verifier kubectl
    try {
        $null = kubectl version --client=true 2>$null
    } catch {
        Write-Error-Custom "kubectl n'est pas installe ou n'est pas dans le PATH"
        exit 1
    }
    
    # Verifier la connexion au cluster
    try {
        $null = kubectl cluster-info 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw
        }
    } catch {
        Write-Error-Custom "Impossible de se connecter au cluster Kubernetes"
        exit 1
    }
    
    Write-Info "✓ Prerequis OK"
}

# Telecharger les images necessaires
function Get-RequiredImages {
    Write-Info "Telechargement des images necessaires..."
    
    # BusyBox pour l'init container
    $busyboxExists = docker images busybox:1.36 --format "{{.Repository}}:{{.Tag}}" | Select-String "busybox:1.36"
    if (-not $busyboxExists) {
        Write-Info "Telechargement de busybox:1.36..."
        docker pull busybox:1.36
    } else {
        Write-Info "✓ busybox:1.36 deja present"
    }
    
    # PostgreSQL
    $postgresExists = docker images postgres:16-alpine --format "{{.Repository}}:{{.Tag}}" | Select-String "postgres:16-alpine"
    if (-not $postgresExists) {
        Write-Info "Telechargement de postgres:16-alpine..."
        docker pull postgres:16-alpine
    } else {
        Write-Info "✓ postgres:16-alpine deja present"
    }
    
    Write-Info "✓ Images necessaires pretes"
}

# Build de l'image Docker
function Build-DockerImage {
    Write-Info "Build de l'image Docker: ${IMAGE_NAME}:${ImageTag}"
    
    docker build -t "${IMAGE_NAME}:${ImageTag}" .
    
    if ($LASTEXITCODE -eq 0) {
        docker tag "${IMAGE_NAME}:${ImageTag}" "${IMAGE_NAME}:latest"
        Write-Info "✓ Image Docker construite avec succes"
    } else {
        Write-Error-Custom "echec du build de l'image Docker"
        exit 1
    }
}

# Charger l'image dans le cluster
function Import-ImageToCluster {
    Write-Info "Chargement de l'image dans le cluster..."
    
    # Detecter Minikube
    try {
        $minikubeStatus = minikube status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Minikube detecte - Chargement de l'image..."
            minikube image load "${IMAGE_NAME}:latest"
            Write-Info "✓ Image chargee dans Minikube"
            return
        }
    } catch {
        # Minikube n'est pas disponible
    }
    
    # Detecter Kind
    try {
        $kindClusters = kind get clusters 2>$null
        if ($LASTEXITCODE -eq 0 -and $kindClusters) {
            $clusterName = $kindClusters[0]
            Write-Info "Kind detecte - Chargement de l'image dans le cluster: $clusterName"
            kind load docker-image "${IMAGE_NAME}:latest" --name $clusterName
            Write-Info "✓ Image chargee dans Kind"
            return
        }
    } catch {
        # Kind n'est pas disponible
    }
    
    Write-Warn "Cluster local non detecte (ni Minikube ni Kind)"
    Write-Warn "Si vous utilisez un cluster cloud, assurez-vous de push l'image vers un registry"
}

# Deploiement sur Kubernetes
function Deploy-ToK8s {
    Write-Info "Deploiement sur Kubernetes..."
    
    # Creer le namespace
    kubectl apply -f "$K8S_DIR/namespace.yaml"
    
    # Deployer PostgreSQL
    Write-Info "Deploiement de PostgreSQL..."
    kubectl apply -f "$K8S_DIR/postgres-configmap.yaml"
    kubectl apply -f "$K8S_DIR/postgres-secret.yaml"
    kubectl apply -f "$K8S_DIR/postgres-pvc.yaml"
    kubectl apply -f "$K8S_DIR/postgres-statefulset.yaml"
    kubectl apply -f "$K8S_DIR/postgres-service.yaml"
    
    # Attendre que PostgreSQL soit pret
    Write-Info "Attente du demarrage de PostgreSQL..."
    kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=120s
    
    # Deployer l'application
    Write-Info "Deploiement de l'application..."
    kubectl apply -f "$K8S_DIR/configmap.yaml"
    kubectl apply -f "$K8S_DIR/deployment.yaml"
    kubectl apply -f "$K8S_DIR/service.yaml"
    kubectl apply -f "$K8S_DIR/hpa.yaml"
    kubectl apply -f "$K8S_DIR/ingress.yaml"
    kubectl apply -f "$K8S_DIR/networkpolicy.yaml"
    
    Write-Info "✓ Ressources Kubernetes deployees"
}

# Verifier le deploiement
function Test-Deployment {
    Write-Info "Verification du deploiement..."
    
    # Verifier PostgreSQL
    Write-Info "Verification de PostgreSQL..."
    kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=60s
    
    # Verifier l'application
    Write-Info "Verification de l'application..."
    kubectl rollout status deployment/productapp-deployment -n $NAMESPACE --timeout=300s
    
    if ($LASTEXITCODE -eq 0) {
        Write-Info "✓ Deploiement reussi"
    } else {
        Write-Error-Custom "echec du deploiement"
        exit 1
    }
}

# Arrêter les anciens port-forward
function Stop-OldPortForwards {
    Write-Info "Nettoyage des anciens port-forwards..."
    
    # Trouver et tuer les processus sur le port
    $processes = Get-NetTCPConnection -LocalPort $PortForwardPort -ErrorAction SilentlyContinue | 
                 Select-Object -ExpandProperty OwningProcess -Unique
    
    if ($processes) {
        foreach ($pid in $processes) {
            try {
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            } catch {
                # Ignorer les erreurs
            }
        }
        Write-Info "✓ Anciens port-forwards arretes"
    }
    
    # Nettoyer l'ancien fichier PID
    if (Test-Path $PID_FILE) {
        $oldPid = Get-Content $PID_FILE -ErrorAction SilentlyContinue
        if ($oldPid) {
            try {
                Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
            } catch {
                # Ignorer les erreurs
            }
        }
        Remove-Item $PID_FILE -Force -ErrorAction SilentlyContinue
    }
}

# Demarrer le port-forward
function Start-PortForward {
    Write-Info "Demarrage du port-forward sur le port ${PortForwardPort}..."
    
    # Demarrer le port-forward en arriere-plan
    $job = Start-Job -ScriptBlock {
        param($ns, $port, $logFile)
        kubectl port-forward -n $ns svc/productapp-service "${port}:80" 2>&1 | Out-File -FilePath $logFile
    } -ArgumentList $NAMESPACE, $PortForwardPort, $LOG_FILE
    
    # Sauvegarder le PID du job
    $job.Id | Out-File -FilePath $PID_FILE
    
    # Attendre que le port-forward soit pret
    Start-Sleep -Seconds 3
    
    if ($job.State -eq "Running") {
        Write-Success "✓ Port-forward actif sur http://localhost:${PortForwardPort}"
        Write-Host "   Job ID: $($job.Id) (utilisez 'Stop-Job $($job.Id); Remove-Job $($job.Id)' pour arreter)" -ForegroundColor Gray
    } else {
        Write-Error-Custom "echec du demarrage du port-forward"
        return $false
    }
    
    return $true
}

# Tester l'application
function Test-Application {
    Write-Info "Test de l'application..."
    
    Start-Sleep -Seconds 2
    
    # Test health check
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:${PortForwardPort}/api/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Success "✓ Health check OK"
        }
    } catch {
        Write-Warn "Health check failed (l'app demarre peut-etre encore)"
    }
    
    # Test API products
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:${PortForwardPort}/api/products" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $productCount = $response.Count
        if ($productCount -gt 0) {
            Write-Success "✓ API Products OK ($productCount produits trouves)"
        } else {
            Write-Warn "API Products retourne 0 produits"
        }
    } catch {
        Write-Warn "Impossible de tester l'API Products"
    }
}

# Afficher les informations
function Show-Info {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "  Informations du deploiement" -ForegroundColor Cyan
    Write-Host "=========================================`n" -ForegroundColor Cyan
    
    Write-Host "📦 PostgreSQL:" -ForegroundColor Yellow
    kubectl get statefulset,pod,pvc -n $NAMESPACE -l app=postgres
    
    Write-Host "`n🚀 Application:" -ForegroundColor Yellow
    kubectl get pods -n $NAMESPACE -l app=productapp -o wide
    
    Write-Host "`n🌐 Services:" -ForegroundColor Yellow
    kubectl get svc -n $NAMESPACE
    
    Write-Host "`n📈 HPA:" -ForegroundColor Yellow
    kubectl get hpa -n $NAMESPACE
    
    Write-Host "`n💾 PersistentVolumeClaims:" -ForegroundColor Yellow
    kubectl get pvc -n $NAMESPACE
    
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "  Acces a l'application" -ForegroundColor Cyan
    Write-Host "=========================================`n" -ForegroundColor Cyan
    
    Write-Host "🌍 Application Web:" -ForegroundColor Green
    Write-Host "   http://localhost:${PortForwardPort}" -ForegroundColor Magenta
    
    Write-Host "`n🔌 API Endpoints:" -ForegroundColor Green
    Write-Host "   Health:   http://localhost:${PortForwardPort}/api/health"
    Write-Host "   Products: http://localhost:${PortForwardPort}/api/products"
    Write-Host "   Stats:    http://localhost:${PortForwardPort}/api/stats"
    
    Write-Host "`n📊 Commandes utiles:" -ForegroundColor Green
    Write-Host "   Logs App: " -NoNewline
    Write-Host "kubectl logs -n $NAMESPACE -l app=productapp -f" -ForegroundColor Yellow
    Write-Host "   Logs DB:  " -NoNewline
    Write-Host "kubectl logs -n $NAMESPACE postgres-0 -f" -ForegroundColor Yellow
    Write-Host "   Shell DB: " -NoNewline
    Write-Host "kubectl exec -it -n $NAMESPACE postgres-0 -- psql -U postgres -d productdb" -ForegroundColor Yellow
    
    Write-Host "`n🛑 Arreter le port-forward:" -ForegroundColor Green
    if (Test-Path $PID_FILE) {
        $jobId = Get-Content $PID_FILE
        Write-Host "   Stop-Job $jobId; Remove-Job $jobId" -ForegroundColor Yellow
    }
    Write-Host "   Ou utilisez: " -NoNewline
    Write-Host ".\stop-k8s.ps1" -ForegroundColor Yellow
    Write-Host ""
}

# Fonction principale
function Main {
    try {
        Test-Prerequisites
        Get-RequiredImages
        Build-DockerImage
        Import-ImageToCluster
        Deploy-ToK8s
        Test-Deployment
        Stop-OldPortForwards
        $portForwardStarted = Start-PortForward
        
        if ($portForwardStarted) {
            Test-Application
        }
        
        Show-Info
        
        Write-Host ""
        Write-Success "========================================="
        Write-Success "✓ Deploiement termine avec succes!"
        Write-Success "========================================="
        Write-Host ""
        Write-Info "Ouvrez votre navigateur sur: http://localhost:${PortForwardPort}"
        Write-Host ""
        
        # Ouvrir automatiquement le navigateur
        try {
            Start-Sleep -Seconds 2
            Start-Process "http://localhost:${PortForwardPort}"
        } catch {
            # Ignorer si l'ouverture echoue
        }
        
    } catch {
        Write-Error-Custom "Une erreur s'est produite: $_"
        exit 1
    }
}

# Gestion de l'interruption
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    if (Test-Path $PID_FILE) {
        $jobId = Get-Content $PID_FILE -ErrorAction SilentlyContinue
        if ($jobId) {
            Stop-Job -Id $jobId -ErrorAction SilentlyContinue
            Remove-Job -Id $jobId -ErrorAction SilentlyContinue
        }
        Remove-Item $PID_FILE -Force -ErrorAction SilentlyContinue
    }
}

# Execution
Main

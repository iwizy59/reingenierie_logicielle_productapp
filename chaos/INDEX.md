# 🎯 Chaos Testing POBS - Index

## 📂 Navigation Rapide

### 🚀 Démarrage Immédiat
- **[QUICKSTART.md](QUICKSTART.md)** ← Commencez ici ! (30 secondes)
- **[start.sh](start.sh)** - Interface interactive

### 📖 Documentation
- **[README.md](README.md)** - Documentation complète (objectifs, métriques, prérequis)
- **[COMPLETE_GUIDE.md](COMPLETE_GUIDE.md)** - Guide exhaustif (troubleshooting, exemples avancés)
- **[INDEX.md](INDEX.md)** - Ce fichier

### 🔬 Expériences
- **[experiments/kill-one-backend-pod.sh](experiments/kill-one-backend-pod.sh)** - Exp 1: Suppression pod
- **[experiments/scale-backend-to-1-then-back.sh](experiments/scale-backend-to-1-then-back.sh)** - Exp 2: Scale down/up
- **[experiments/TEMPLATE.sh](experiments/TEMPLATE.sh)** - Template pour nouvelles expériences

### ⚙️ Infrastructure
- **[lib/common.sh](lib/common.sh)** - Fonctions utilitaires (logs, K8s, métriques)
- **[traffic/traffic.sh](traffic/traffic.sh)** - Générateur de trafic HTTP
- **[run-all.sh](run-all.sh)** - Orchestrateur (toutes les expériences)
- **[cleanup.sh](cleanup.sh)** - Nettoyage complet

---

## 🎓 Parcours d'Apprentissage

### Niveau 1 : Débutant
1. Lire [QUICKSTART.md](QUICKSTART.md)
2. Lancer `./start.sh`
3. Choisir expérience 1 ou 2
4. Observer les résultats

### Niveau 2 : Intermédiaire
1. Lire [README.md](README.md)
2. Exécuter `./run-all.sh` (toutes les expériences)
3. Analyser les logs dans `/tmp/chaos-*.log`
4. Modifier les variables d'environnement

### Niveau 3 : Avancé
1. Lire [COMPLETE_GUIDE.md](COMPLETE_GUIDE.md)
2. Étudier [lib/common.sh](lib/common.sh)
3. Créer une expérience custom depuis [experiments/TEMPLATE.sh](experiments/TEMPLATE.sh)
4. Ajouter des métriques personnalisées

---

## 📋 Checklist Rapide

### Avant de commencer
- [ ] Application déployée : `kubectl get pods -n productapp`
- [ ] Cluster accessible : `kubectl cluster-info`
- [ ] Scripts exécutables : `chmod +x *.sh experiments/*.sh`

### Premier test
- [ ] Lancer : `./start.sh`
- [ ] Choisir expérience 1
- [ ] Attendre résultats (~60s)
- [ ] Vérifier : PASS ou FAIL ?

### Si FAIL
- [ ] Lire [COMPLETE_GUIDE.md#troubleshooting](COMPLETE_GUIDE.md#troubleshooting)
- [ ] Vérifier état cluster : `kubectl get pods -n productapp`
- [ ] Augmenter replicas : `kubectl scale deployment backend-deployment -n productapp --replicas=5`
- [ ] Relancer le test

### Après les tests
- [ ] Nettoyage : `./cleanup.sh`
- [ ] Sauvegarder les logs : `cp /tmp/chaos-*.log ./results/`
- [ ] Documenter les résultats

---

## 🔗 Liens Utiles

### Documentation Projet
- [Architecture 3-Tiers](../ARCHITECTURE_3TIERS_DETAILLEE.md)
- [Script de déploiement](../deploy-k8s-3tiers.sh)
- [Script de nettoyage](../stop-k8s-3tiers.sh)

### Ressources Externes
- [Principles of Chaos Engineering](https://principlesofchaos.org/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Site Reliability Engineering](https://sre.google/books/)

---

## 🆘 Aide Rapide

| Problème | Solution |
|----------|----------|
| Port 8080 occupé | `lsof -ti:8080 \| xargs kill -9` |
| Namespace inexistant | `cd .. && ./deploy-k8s-3tiers.sh` |
| Script bloqué | Ctrl+C puis `./cleanup.sh` |
| Tous les tests FAIL | Vérifier `kubectl get pods -n productapp` |
| Logs introuvables | Chercher dans `/tmp/chaos-*.log` |

---

## 📊 Résultats Types

### ✅ Application Résiliente
```
Disponibilité: 96-100%
Max panne: 0-5s
Recovery: 5-15s
→ RAS, architecture OK
```

### ⚠️ À Améliorer
```
Disponibilité: 90-95%
Max panne: 10-15s
Recovery: 20-30s
→ Augmenter replicas ou ajuster probes
```

### ❌ Problème Critique
```
Disponibilité: <90%
Max panne: >15s
Recovery: >30s
→ Revoir l'architecture (replicas, ressources, healthchecks)
```

---

## 🎯 Objectifs du Chaos Testing

1. **Valider la résilience** : L'API reste disponible malgré les pannes
2. **Mesurer le MTTR** : Mean Time To Recovery (temps de récupération)
3. **Détecter les SPOF** : Single Point Of Failure
4. **Documenter les comportements** : Pour amélioration continue

---

## 📞 Contact & Contribution

Pour questions ou contributions :
- Lire [COMPLETE_GUIDE.md](COMPLETE_GUIDE.md)
- Utiliser le template [experiments/TEMPLATE.sh](experiments/TEMPLATE.sh)
- Tester avec `DRY_RUN=true`

---

**Ready to break things?** → `./start.sh` 🚀

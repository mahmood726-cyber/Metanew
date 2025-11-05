# Kubernetes Deployment Guide

This directory contains Kubernetes manifests for deploying EvidenceOS PRIME to a Kubernetes cluster.

## 📁 Structure

```
k8s/
├── base/                    # Base Kubernetes resources
│   ├── namespace.yaml       # Namespace definition
│   ├── configmap.yaml       # Configuration and secrets
│   ├── backend-deployment.yaml  # Backend application
│   ├── redis-deployment.yaml    # Redis cache
│   ├── postgres-statefulset.yaml # PostgreSQL database
│   ├── ingress.yaml         # Ingress rules
│   ├── pvc.yaml             # Persistent volume claims
│   └── kustomization.yaml   # Kustomize base config
├── overlays/
│   ├── staging/             # Staging environment config
│   │   ├── kustomization.yaml
│   │   └── namespace.yaml
│   └── production/          # Production environment config
│       ├── kustomization.yaml
│       └── namespace.yaml
└── README.md                # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Kubernetes cluster** (v1.25+)
2. **kubectl** installed and configured
3. **kustomize** (v4.5+) or kubectl with built-in kustomize
4. **cert-manager** for TLS certificates
5. **nginx-ingress-controller** for ingress

### Deploy to Staging

```bash
# Apply staging configuration
kubectl apply -k k8s/overlays/staging/

# Check deployment status
kubectl get pods -n evidenceos-staging

# View logs
kubectl logs -f deployment/staging-evidenceos-backend -n evidenceos-staging
```

### Deploy to Production

```bash
# Apply production configuration
kubectl apply -k k8s/overlays/production/

# Check deployment status
kubectl get pods -n evidenceos-production

# Verify all services are running
kubectl get all -n evidenceos-production
```

## 🔧 Configuration

### Secrets

**IMPORTANT:** Update secrets before deploying to production!

```bash
# Generate strong passwords
openssl rand -base64 32

# Update secrets
kubectl create secret generic evidenceos-secrets \
  --from-literal=postgres-password=<strong-password> \
  --from-literal=jwt-secret=<strong-random-string> \
  --from-literal=admin-password=<admin-password> \
  --from-literal=database-url=postgresql://evidenceos:<password>@postgres-service:5432/evidenceos \
  -n evidenceos-production --dry-run=client -o yaml | kubectl apply -f -
```

### ConfigMap

Edit `k8s/base/configmap.yaml` to customize:
- Redis settings
- Cache TTL
- ML model paths
- Feature flags

### Resource Limits

Default resource allocation:

| Component | Requests | Limits |
|-----------|----------|--------|
| Backend | 2 GB / 1 CPU | 4 GB / 2 CPU |
| Redis | 1 GB / 0.5 CPU | 2 GB / 1 CPU |
| PostgreSQL | 2 GB / 1 CPU | 4 GB / 2 CPU |

Adjust in deployment manifests based on your workload.

## 📊 Monitoring

### Health Checks

All deployments include:
- **Liveness probe:** Ensures pod is alive
- **Readiness probe:** Ensures pod is ready for traffic
- **Startup probe:** Allows slow-starting containers

```bash
# Check health status
kubectl exec -it deployment/evidenceos-backend -n evidenceos -- \
  curl http://localhost:8000/health/detailed
```

### Auto-scaling

Horizontal Pod Autoscaler (HPA) configured for backend:
- **Min replicas:** 3 (staging: 2)
- **Max replicas:** 10
- **CPU target:** 70%
- **Memory target:** 80%

```bash
# Check HPA status
kubectl get hpa -n evidenceos-production

# Describe HPA for details
kubectl describe hpa backend-hpa -n evidenceos-production
```

### Prometheus Metrics

Backend exposes metrics at `/metrics` endpoint:

```bash
# Access metrics
kubectl port-forward deployment/evidenceos-backend 8000:8000 -n evidenceos
curl http://localhost:8000/metrics
```

## 💾 Storage

### Persistent Volumes

Three persistent volumes are created:
1. **Backend data** (100 GB) - Model registry, experiments
2. **Redis data** (10 GB) - Cache persistence
3. **PostgreSQL data** (50 GB) - Database storage

**Storage Class:** `fast-ssd` (configurable)

```bash
# Check PVCs
kubectl get pvc -n evidenceos-production

# Check PV usage
kubectl exec -it statefulset/postgres -n evidenceos-production -- \
  df -h /var/lib/postgresql/data
```

### Backup Strategy

#### PostgreSQL Backup

```bash
# Create backup
kubectl exec statefulset/postgres -n evidenceos-production -- \
  pg_dump -U evidenceos evidenceos > backup-$(date +%Y%m%d).sql

# Restore backup
kubectl exec -i statefulset/postgres -n evidenceos-production -- \
  psql -U evidenceos evidenceos < backup-20250105.sql
```

#### Redis Backup

Redis is configured with RDB persistence:
- Save every 900 seconds if ≥1 key changed
- Save every 300 seconds if ≥10 keys changed

## 🔒 Security

### Network Policies

Recommended network policies:

```yaml
# Allow only necessary traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: evidenceos-production
spec:
  podSelector:
    matchLabels:
      component: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: nginx-ingress
  egress:
  - to:
    - podSelector:
        matchLabels:
          component: redis
  - to:
    - podSelector:
        matchLabels:
          component: postgres
```

### RBAC

Create service account with minimal permissions:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: evidenceos-sa
  namespace: evidenceos-production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: evidenceos-role
  namespace: evidenceos-production
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: evidenceos-rolebinding
  namespace: evidenceos-production
subjects:
- kind: ServiceAccount
  name: evidenceos-sa
roleRef:
  kind: Role
  name: evidenceos-role
  apiGroup: rbac.authorization.k8s.io
```

## 🌐 Ingress & TLS

### cert-manager Setup

Install cert-manager for automatic TLS certificates:

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@evidenceos.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### Custom Domain

Update ingress host in overlays:

```yaml
# k8s/overlays/production/kustomization.yaml
patches:
  - patch: |-
      - op: replace
        path: /spec/rules/0/host
        value: your-domain.com
    target:
      kind: Ingress
      name: evidenceos-ingress
```

## 🔄 Updates & Rollbacks

### Rolling Update

```bash
# Update image tag
kubectl set image deployment/evidenceos-backend \
  backend=ghcr.io/your-org/evidenceos-backend:v2.0.1 \
  -n evidenceos-production

# Watch rollout
kubectl rollout status deployment/evidenceos-backend -n evidenceos-production
```

### Rollback

```bash
# Check rollout history
kubectl rollout history deployment/evidenceos-backend -n evidenceos-production

# Rollback to previous version
kubectl rollout undo deployment/evidenceos-backend -n evidenceos-production

# Rollback to specific revision
kubectl rollout undo deployment/evidenceos-backend --to-revision=2 \
  -n evidenceos-production
```

## 🧹 Cleanup

### Remove Staging

```bash
kubectl delete -k k8s/overlays/staging/
```

### Remove Production

```bash
# ⚠️ WARNING: This will delete all data!
kubectl delete -k k8s/overlays/production/
```

## 📝 Troubleshooting

### Pod Not Starting

```bash
# Describe pod for events
kubectl describe pod <pod-name> -n evidenceos-production

# Check logs
kubectl logs <pod-name> -n evidenceos-production

# Check previous container logs (if crashed)
kubectl logs <pod-name> --previous -n evidenceos-production
```

### Database Connection Issues

```bash
# Test database connectivity from backend pod
kubectl exec -it deployment/evidenceos-backend -n evidenceos-production -- \
  python -c "from database.database import engine; engine.connect()"

# Check PostgreSQL logs
kubectl logs statefulset/postgres -n evidenceos-production
```

### Ingress Not Working

```bash
# Check ingress configuration
kubectl describe ingress evidenceos-ingress -n evidenceos-production

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Verify cert-manager issued certificate
kubectl describe certificate evidenceos-tls -n evidenceos-production
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Guide](https://kustomize.io/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

---

**Last Updated:** 2025-01-05
**Version:** 2.0

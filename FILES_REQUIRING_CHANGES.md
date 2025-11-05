# FILES REQUIRING CHANGES - BY PRIORITY

## CRITICAL (Security - Fix Immediately)

### 1. Kubernetes Configuration
- **File**: `k8s/base/configmap.yaml`
  - **Lines**: 41-52
  - **Issue**: Hardcoded passwords with "CHANGE_ME_IN_PRODUCTION"
  - **Fix**: Remove all secrets; use external secret manager
  - **Effort**: 2 hours

- **File**: `k8s/base/backend-deployment.yaml`
  - **Lines**: 43-47, 32
  - **Issue**: DATABASE_URL in env vars; imagePullPolicy issues
  - **Fix**: Use secretKeyRef; add imagePullSecrets
  - **Effort**: 1 hour

- **File**: `k8s/base/redis-deployment.yaml`
  - **Lines**: 27-34
  - **Issue**: No password authentication
  - **Fix**: Add --requirepass argument
  - **Effort**: 30 minutes

- **File**: `k8s/base/ingress.yaml`
  - **Lines**: 41-47
  - **Issue**: /docs publicly accessible
  - **Fix**: Add nginx auth annotations
  - **Effort**: 1 hour

- **MISSING**: `k8s/base/rbac.yaml` (doesn't exist)
  - **Issue**: No RBAC defined
  - **Fix**: Create with ServiceAccounts, Roles, RoleBindings
  - **Effort**: 3 hours

- **MISSING**: `k8s/base/network-policies.yaml` (doesn't exist)
  - **Issue**: No network segmentation
  - **Fix**: Create with ingress/egress rules
  - **Effort**: 2 hours

### 2. Frontend
- **File**: `frontend/modules/client_portal.R`
  - **Lines**: 180-181
  - **Issue**: Plaintext password storage
  - **Fix**: Use bcrypt hashing
  - **Effort**: 1.5 hours

- **File**: `frontend/modules/data_import.R`
  - **Lines**: (throughout)
  - **Issue**: No CSV formula injection protection
  - **Fix**: Add sanitization checks
  - **Effort**: 1 hour

### 3. Backend API
- **File**: `backend/api/nlq.py`
  - **Lines**: 30
  - **Issue**: CORS allow_origins=["*"]
  - **Fix**: Restrict to specific domains
  - **Effort**: 30 minutes

- **File**: `backend/api/main.py` and `main_enhanced.py`
  - **Lines**: Throughout
  - **Issue**: Missing input validation for some endpoints
  - **Fix**: Add request/response schema validation
  - **Effort**: 2 hours

### 4. CI/CD
- **File**: `.github/workflows/deploy.yml`
  - **Lines**: 123-127, 247-253
  - **Issue**: Placeholder deployment commands
  - **Fix**: Implement actual kubectl/docker-compose deployment
  - **Effort**: 5 hours

- **File**: `.github/workflows/ci-cd.yml`
  - **Lines**: 5
  - **Issue**: Permissive branch filter (claude/**)
  - **Fix**: Restrict to protected branches
  - **Effort**: 30 minutes

- **MISSING**: `.github/workflows/security-scan.yml`
  - **Issue**: No secrets scanning
  - **Fix**: Add TruffleHog or detect-secrets job
  - **Effort**: 1 hour

---

## HIGH PRIORITY (Before Production)

### 5. Docker Configuration
- **File**: `frontend/Dockerfile`
  - **Lines**: 22-43
  - **Issue**: No R package version pinning
  - **Fix**: Use renv or MRAN snapshot date
  - **Effort**: 2 hours

- **File**: `docker-compose.yml`
  - **Lines**: Throughout
  - **Issue**: No Docker secrets; uses :latest tags
  - **Fix**: Add secrets section; pin all image versions
  - **Effort**: 1.5 hours

### 6. Dependencies
- **File**: `backend/requirements.txt`
  - **Lines**: Throughout
  - **Issue**: Outdated versions; no security scanning
  - **Fix**: Run pip-audit; update vulnerable packages
  - **Effort**: 2 hours

- **File**: `load-testing/requirements.txt`
  - **Lines**: 1-10
  - **Issue**: Needs security audit
  - **Fix**: Run safety check
  - **Effort**: 30 minutes

### 7. Environment Configuration
- **File**: `.env.example`
  - **Lines**: 62, 67, 82
  - **Issue**: Example values too specific
  - **Fix**: Use generic placeholders
  - **Effort**: 30 minutes

- **MISSING**: `.env.production.example`
  - **Issue**: No production template
  - **Fix**: Create with production defaults
  - **Effort**: 30 minutes

### 8. Documentation
- **MISSING**: `SECURITY_HARDENING_GUIDE.md`
  - **Issue**: No security deployment guide
  - **Fix**: Create comprehensive guide
  - **Effort**: 3 hours

- **MISSING**: `PRODUCTION_RUNBOOK.md`
  - **Issue**: No ops procedures
  - **Fix**: Create deployment, monitoring, troubleshooting procedures
  - **Effort**: 3 hours

- **MISSING**: `TROUBLESHOOTING_GUIDE.md`
  - **Issue**: No user troubleshooting help
  - **Fix**: Create common problems/solutions
  - **Effort**: 2 hours

- **File**: `monitoring/README.md`
  - **Lines**: 18-19
  - **Issue**: Hardcoded default credentials
  - **Fix**: Remove; document secure setup
  - **Effort**: 30 minutes

- **File**: `DEPLOYMENT_GUIDE.md`
  - **Lines**: Throughout
  - **Issue**: Missing Kubernetes specifics
  - **Fix**: Add K8s deployment section
  - **Effort**: 2 hours

---

## MEDIUM PRIORITY (Next Sprint)

### 9. Frontend
- **File**: `frontend/app.R`
  - **Lines**: Throughout
  - **Issue**: Missing debouncing on expensive operations
  - **Fix**: Add rate limiting to sensitivity analysis, ML operations
  - **Effort**: 2 hours

- **File**: `frontend/modules/ai_copilot.R`
  - **Lines**: 113-120
  - **Issue**: Insufficient response validation
  - **Fix**: Add schema validation before rendering
  - **Effort**: 1.5 hours

### 10. Monitoring
- **File**: `monitoring/prometheus/prometheus.yml`
  - **Lines**: Throughout
  - **Issue**: Missing custom application metrics
  - **Fix**: Add scrape config for app metrics endpoints
  - **Effort**: 1 hour

- **File**: `monitoring/prometheus/rules/evidenceos-alerts.yml`
  - **Lines**: 22, 113
  - **Issue**: Alert thresholds not calibrated
  - **Fix**: Adjust based on baseline tests
  - **Effort**: 2 hours

- **MISSING**: Alert rules for backup failures, data loss
  - **Issue**: No alerts for critical failure modes
  - **Fix**: Add database connectivity, backup status alerts
  - **Effort**: 1 hour

### 11. Load Testing
- **File**: `load-testing/locustfile.py`
  - **Lines**: 234-254
  - **Issue**: Test data not realistic
  - **Fix**: Use actual sample data structure
  - **Effort**: 1 hour

- **File**: `.github/workflows/ci-cd.yml`
  - **Lines**: Throughout
  - **Issue**: No load test in CI/CD
  - **Fix**: Add staging deployment load test job
  - **Effort**: 2 hours

---

## SUMMARY TABLE

| File | Issue Type | Priority | Effort | Status |
|------|-----------|----------|--------|--------|
| k8s/base/configmap.yaml | Security | CRITICAL | 2h | Not Started |
| k8s/base/backend-deployment.yaml | Security | CRITICAL | 1h | Not Started |
| k8s/base/redis-deployment.yaml | Security | CRITICAL | 0.5h | Not Started |
| k8s/base/ingress.yaml | Security | CRITICAL | 1h | Not Started |
| k8s/base/rbac.yaml | MISSING | CRITICAL | 3h | Not Started |
| k8s/base/network-policies.yaml | MISSING | CRITICAL | 2h | Not Started |
| frontend/modules/client_portal.R | Security | CRITICAL | 1.5h | Not Started |
| backend/api/nlq.py | Security | CRITICAL | 0.5h | Not Started |
| .github/workflows/deploy.yml | CI/CD | CRITICAL | 5h | Not Started |
| .github/workflows/ci-cd.yml | CI/CD | CRITICAL | 0.5h | Not Started |
| .github/workflows/security-scan.yml | MISSING | CRITICAL | 1h | Not Started |
| frontend/Dockerfile | Dependencies | HIGH | 2h | Not Started |
| docker-compose.yml | Config | HIGH | 1.5h | Not Started |
| backend/requirements.txt | Dependencies | HIGH | 2h | Not Started |
| SECURITY_HARDENING_GUIDE.md | MISSING | HIGH | 3h | Not Started |
| PRODUCTION_RUNBOOK.md | MISSING | HIGH | 3h | Not Started |
| TROUBLESHOOTING_GUIDE.md | MISSING | HIGH | 2h | Not Started |
| frontend/app.R | UX | MEDIUM | 2h | Not Started |
| monitoring/prometheus.yml | Monitoring | MEDIUM | 1h | Not Started |
| load-testing/locustfile.py | Testing | MEDIUM | 1h | Not Started |

**Total Effort: 45-65 hours**
**Critical Path: 12-15 hours (K8s + CI/CD + secrets)**

---

## RECOMMENDED FIX ORDER

1. **Week 1 - Security Foundation (20 hours)**
   - Implement Sealed Secrets for K8s
   - Add RBAC and Network Policies
   - Fix CORS configuration
   - Hash client portal passwords
   - Create security documentation

2. **Week 2 - Deployment & Testing (25 hours)**
   - Implement CI/CD deployment
   - Add load testing to CI
   - Pin R and Python dependencies
   - Create production runbook
   - Security audit of dependencies

3. **Week 3 - Validation (10 hours)**
   - Test in staging environment
   - Conduct security review
   - Performance baseline testing
   - Production readiness checklist

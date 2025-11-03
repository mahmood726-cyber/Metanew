# Phase 2 + v2 Combined Implementation Plan
## EvidenceOS PRIME - Strategic Feature Roadmap

**Date**: November 3, 2025
**Timeline**: 3-4 months
**Investment**: $80K-120K
**Current Version**: 2.1.0 (Post-Phase 1)

---

## 🎯 Strategic Approach

This plan **combines**:
1. **My Phase 2 UX Enhancements** (from usability reviews)
2. **User's v2 "Operate & Scale" Features** (founder roadmap)

**Philosophy**: Implement high-value features that:
- ✅ Require NO infrastructure changes (stay single Docker)
- ✅ Leverage existing R + Python stack
- ✅ Deliver immediate user value
- ✅ Maintain backward compatibility
- ✅ Keep all 234 tests passing

---

## 📋 Combined Feature Matrix

| Feature | Source | Priority | Effort | Value | Implement Now? |
|---------|--------|----------|--------|-------|----------------|
| **Scenario Compare** | v2 | P0 | 2w | Very High | ✅ YES |
| **PRISMA Counters** | v2 | P0 | 1w | High | ✅ YES |
| **Method Guardrails** | v2 | P0 | 2w | High | ✅ YES |
| **Protocol Snapshots** | v2 | P1 | 1w | Medium | ✅ YES |
| **Budget Impact v1** | v2 | P1 | 2w | High | ✅ YES |
| **Column Mapping** | Phase 2 | P1 | 3w | High | ✅ YES |
| **Video Tutorials** | Phase 2 | P1 | 4w | High | ⏸️ LATER (production) |
| **Enhanced Tooltips** | Phase 2 | P1 | 1w | Medium | ✅ YES (quick) |
| **Partitioned Survival** | v2 | P2 | 3w | Medium | ⏸️ PHASE 3 |
| **Bayesian NMA** | v3 | P3 | 6w | Medium | ❌ NO (Phase 3) |
| **Multi-user Auth** | v2 | P3 | 8w | Low | ❌ NO (infrastructure) |
| **Living MA Scheduler** | v2 | P3 | 4w | Low | ❌ NO (infrastructure) |

---

## ✅ IMPLEMENT NOW (Next 4-6 Weeks)

### 1. **Scenario Compare Module** ⭐ HIGHEST PRIORITY
**Effort**: 2 weeks | **Value**: Very High | **Source**: v2

**Problem**: Users want to compare different analysis scenarios side-by-side
- Base case vs. sensitivity analysis
- Including vs. excluding high RoB studies
- Different effect measures (OR vs. RR)
- Different methods (REML vs. DL)

**Implementation**: `frontend/modules/scenario_compare.R`

**Features**:
- Select 2 saved analyses from history
- Side-by-side comparison table:
  * Pooled effects with CIs
  * Heterogeneity (I², τ²)
  * Publication bias tests
  * Number of studies
  * Quality scores
- Difference calculations (Δ effect, Δ I²)
- Visual comparison (dual forest plots)
- Export to Word/PowerPoint
- Highlight significant differences

**UI Design**:
```
┌─────────────────────────────────────────────┐
│ Scenario Comparison                          │
├─────────────────────────────────────────────┤
│ Scenario 1: [Dropdown: All Studies]         │
│ Scenario 2: [Dropdown: Excluding High RoB]  │
│ [Compare]                                    │
├─────────────────────────────────────────────┤
│ Metric          │ Scenario 1 │ Scenario 2 │ Δ│
│─────────────────┼────────────┼────────────┼──│
│ Pooled Effect   │ 0.75       │ 0.68       │-0.07│
│ 95% CI          │ 0.62-0.91  │ 0.54-0.85  │   │
│ I²              │ 65%        │ 42%        │-23%│
│ Studies         │ 12         │ 9          │-3 │
│ Egger p         │ 0.08       │ 0.15       │   │
└─────────────────────────────────────────────┘
```

**Impact**:
- Addresses reviewer "What if?" questions instantly
- Required for NICE sensitivity analysis reporting
- Time savings: 30-60 min per scenario comparison

---

### 2. **PRISMA Flow Diagram** ⭐ HIGH PRIORITY
**Effort**: 1 week | **Value**: High | **Source**: v2

**Problem**: Every systematic review needs PRISMA flowchart, currently manual

**Implementation**: `frontend/modules/prisma.R`

**Features**:
- Manual input fields for key counts:
  * Records identified (databases)
  * Records removed (duplicates)
  * Records screened
  * Records excluded
  * Full-text assessed
  * Full-text excluded (with reasons)
  * Studies included in MA
- Auto-tally from uploaded data (studies count)
- Generate PRISMA 2020 diagram (ggplot2)
- Export as PNG/PDF (high-res)
- Save counts with protocol

**PRISMA 2020 Template**:
```
┌──────────────────┐
│ Identification   │
├──────────────────┤
│ Records: 1,234   │
│ Duplicates: -234 │
└────────┬─────────┘
         ↓
┌──────────────────┐
│ Screening        │
├──────────────────┤
│ Screened: 1,000  │
│ Excluded: -900   │
└────────┬─────────┘
         ↓
┌──────────────────┐
│ Included         │
├──────────────────┤
│ Studies: 12      │
└──────────────────┘
```

**Impact**:
- Saves 20-30 min per review
- Professional appearance
- Compliance with PRISMA 2020 guidelines

---

### 3. **Method Guardrails & Auto-Checks** ⭐ HIGH PRIORITY
**Effort**: 2 weeks | **Value**: High | **Source**: v2 + my Phase 1

**Problem**: Data errors slip through, causing invalid analyses

**Implementation**: Enhanced `backend/etl/validate.py` + new `frontend/modules/qa_checks.R`

**Auto-Checks** (Python backend):
1. **Impossible SEs**: SE > effect size for binary data
2. **Duplicate study IDs**: Same ID with different data
3. **Data clashes**: Arms don't match (2-arm vs 3-arm)
4. **Extreme values**: Effect sizes > 10 SD from mean
5. **Inconsistent counts**: events > n, negative values
6. **Zero-cell studies**: Warn if >50% have zero cells
7. **Small sample sizes**: Flag if median n < 20
8. **High heterogeneity**: I² > 75% suggests data issues

**QA Dashboard** (R frontend):
```
┌──────────────────────────────────────┐
│ Data Quality Report                   │
├──────────────────────────────────────┤
│ ✅ Passed: 8/10 checks                │
│ ⚠️  Warnings: 2 checks                │
│ ❌ Failed: 0 checks                   │
├──────────────────────────────────────┤
│ ⚠️  Warning: High heterogeneity       │
│    I² = 78% suggests potential        │
│    outliers or data errors            │
│    → Run leave-one-out to identify    │
├──────────────────────────────────────┤
│ ⚠️  Warning: Small samples            │
│    5 studies with n < 20              │
│    → Consider sensitivity excluding   │
└──────────────────────────────────────┘
```

**Blocking Rules**:
- Block analysis if: duplicate IDs, impossible values
- Warn but allow: high heterogeneity, small samples
- Info only: zero cells (auto-corrected)

**Impact**:
- Prevents 90% of common data errors
- Saves 1-2 hours debugging per project
- Builds user confidence in results

---

### 4. **Protocol Snapshot & Versioning**
**Effort**: 1 week | **Value**: Medium | **Source**: v2

**Problem**: Protocol changes during project, need audit trail

**Implementation**: `frontend/modules/protocol.R` enhancement

**Features**:
- "Lock Protocol" button → creates snapshot
- Snapshot includes:
  * PICO elements
  * Eligibility criteria
  * Planned analyses
  * Statistical methods
  * Timestamp + hash
- Protocol vs. Execution diff report:
  * What changed?
  * Deviation justifications
  * Reviewer notes
- Version history sidebar
- Restore previous version

**Diff Report Example**:
```
Protocol Deviations Report
==========================

PLANNED (Protocol v1.0, 2025-01-15):
- Effect measure: OR
- Method: DerSimonian-Laird
- Subgroups: Age, Region

EXECUTED (Analysis, 2025-02-20):
- Effect measure: OR ✓
- Method: REML ← CHANGED
  Justification: REML more appropriate for small k
- Subgroups: Age ✓, Region ✓, + RoB ← ADDED
  Justification: Reviewer request
```

**Impact**:
- Transparency for reviewers/regulators
- Audit trail compliance
- Prevents protocol drift

---

### 5. **Budget Impact Analysis Module v1**
**Effort**: 2 weeks | **Value**: High | **Source**: v2

**Problem**: NICE/HTA submissions require BIA, currently external spreadsheet

**Implementation**: `frontend/modules/bia.R` (new)

**Features**:
- Eligible population input
- Current treatment mix (%)
- New treatment uptake curve (linear/sigmoid)
- Unit costs per treatment
- Time horizon (1-5 years)
- Price erosion (optional)
- Line extensions (optional)

**Outputs**:
- Annual budget impact table
- Cumulative budget impact
- Per-patient cost difference
- Tornado diagram (sensitivity)
- Export to Excel template

**Calculation**:
```
BIA = Σ (Population × Uptake × Cost_new) -
      Σ (Population × Displaced × Cost_old)
```

**Impact**:
- Completes NICE submission package
- Saves 2-3 hours per BIA
- No need for separate Excel model

---

### 6. **Column Mapping Wizard**
**Effort**: 3 weeks | **Value**: High | **Source**: My Phase 2

**Problem**: Users must rename columns to match expected names

**Implementation**: `frontend/modules/column_mapper.R` (new)

**Features**:
- Drag-and-drop mapping interface
- Smart auto-detection:
  ```
  Detected:           Maps to:
  events_intervention → events_exp
  total_intervention  → n_exp
  events_control      → events_ctrl
  total_control       → n_ctrl
  ```
- Supported patterns:
  * Covidence exports
  * RevMan exports
  * DistillerSR exports
  * Generic patterns
- Save mapping templates
- Template library (common formats)
- Preview mapped data before import

**UI Flow**:
```
Step 1: Upload CSV
Step 2: Auto-detect columns (preview)
Step 3: Adjust mapping (drag-and-drop)
Step 4: Confirm and import
```

**Impact**:
- Eliminates 10-15 min preprocessing
- Reduces errors from manual renaming
- Lower barrier to entry

---

### 7. **Enhanced Tooltips with "Learn More"**
**Effort**: 1 week | **Value**: Medium | **Source**: My Phase 2

**Problem**: Current tooltips too brief, users want depth

**Implementation**: Upgrade existing tooltips

**Enhancement**:
```
REML Estimation [?]
  ↓ Hover: Brief explanation
  ↓ Click "Learn More":
    ┌────────────────────────────────┐
    │ REML Estimation                 │
    ├────────────────────────────────┤
    │ What: Restricted Maximum        │
    │       Likelihood                │
    │ When: Recommended for most      │
    │       meta-analyses             │
    │ Why:  Less biased than DL       │
    │ Alternatives: DL, ML, EB        │
    │                                 │
    │ Example: For k=10 studies,      │
    │ REML typically estimates τ²     │
    │ 15-20% lower than DL.          │
    │                                 │
    │ 📖 Read more in Glossary        │
    │ 💡 See Quick Start Guide        │
    └────────────────────────────────┘
```

**Features**:
- Expandable tooltips
- Code examples
- Links to documentation
- Interactive demos (where appropriate)

**Impact**:
- Deeper understanding
- Pedagogical value
- Less documentation lookups

---

## ⏸️ DEFER TO LATER

### 8. **Video Tutorials** (Phase 2)
**Defer Reason**: Production quality requires external videographer
**Timeline**: Hire contractor after Phase 2 features complete
**Cost**: $10K for 5 videos

### 9. **Partitioned Survival Models** (v2)
**Defer Reason**: Complex implementation, smaller user base
**Timeline**: Phase 3 (after BIA v1 proven)
**Complexity**: High - requires flexsurv integration, survival modeling

### 10. **Bayesian NMA** (v3)
**Defer Reason**: Complex, requires PyMC/JAGS/Stan
**Timeline**: Phase 3 (advanced users only)
**Complexity**: Very High

### 11. **Multi-User Authentication** (v2)
**Defer Reason**: Requires infrastructure (auth server, DB)
**Timeline**: Phase 5 (Enterprise features)
**Complexity**: High

### 12. **Living MA Scheduler** (v2)
**Defer Reason**: Requires job scheduler, email system
**Timeline**: Phase 3 (after basic Living MA proven)
**Complexity**: High

---

## 📅 Implementation Timeline (12 Weeks)

### **Weeks 1-2**: Foundation
- ✅ Method Guardrails (auto-checks)
- ✅ Enhanced Tooltips
- ✅ PRISMA Module

### **Weeks 3-4**: Comparison & Versioning
- ✅ Scenario Compare Module
- ✅ Protocol Snapshots

### **Weeks 5-7**: Data Import
- ✅ Column Mapping Wizard (largest feature)

### **Weeks 8-9**: Health Economics
- ✅ Budget Impact Analysis v1

### **Weeks 10-11**: Testing & Documentation
- ✅ Integration testing
- ✅ User documentation updates
- ✅ Video script preparation

### **Week 12**: Release & Handoff
- ✅ Deploy v2.2.0
- ✅ Release notes
- ✅ Contract videographer for tutorials

---

## 💰 Budget Allocation

| Feature | Developer Time | Cost Estimate |
|---------|---------------|---------------|
| Method Guardrails | 80 hours | $12K |
| PRISMA Module | 40 hours | $6K |
| Scenario Compare | 80 hours | $12K |
| Protocol Snapshots | 40 hours | $6K |
| Column Mapping | 120 hours | $18K |
| Budget Impact v1 | 80 hours | $12K |
| Enhanced Tooltips | 40 hours | $6K |
| Testing & Docs | 80 hours | $12K |
| **Total** | **560 hours** | **$84K** |

---

## 🎯 Success Criteria

### Acceptance Tests:

1. **Scenario Compare**
   - ✅ Side-by-side comparison renders correctly
   - ✅ Differences calculated accurately
   - ✅ Export to Word works
   - ✅ Handles missing scenarios gracefully

2. **PRISMA Module**
   - ✅ Diagram matches PRISMA 2020 template
   - ✅ Auto-tally from data works
   - ✅ Export to PNG/PDF high-resolution
   - ✅ Saves with protocol

3. **Method Guardrails**
   - ✅ Detects all 8 data quality issues
   - ✅ Blocks analysis for critical errors
   - ✅ Warns for non-critical issues
   - ✅ QA dashboard displays correctly

4. **Protocol Snapshots**
   - ✅ Lock protocol creates immutable snapshot
   - ✅ Diff report shows all changes
   - ✅ Version history accessible
   - ✅ Restore previous version works

5. **Budget Impact**
   - ✅ BIA calculations match Excel reference
   - ✅ Uptake curves render correctly
   - ✅ Export to Excel template works
   - ✅ Tornado diagram sensitivity correct

6. **Column Mapping**
   - ✅ Auto-detects 80%+ of common patterns
   - ✅ Drag-and-drop interface works smoothly
   - ✅ Template save/load works
   - ✅ Preview shows correct mapping

7. **Enhanced Tooltips**
   - ✅ Expandable "Learn More" works
   - ✅ Links to documentation correct
   - ✅ Examples display properly
   - ✅ All 50+ tooltips upgraded

---

## 📊 Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Scope creep | High | High | Strict feature freeze after Week 1 |
| Column mapping complexity | Medium | Medium | Start with 3 common formats only |
| BIA validation | Medium | High | Reference check vs. Excel model |
| Testing time underestimated | High | Medium | Allocate 2 full weeks for testing |
| User adoption | Low | High | Excellent documentation + examples |

---

## 🚀 Launch Plan (v2.2.0)

### Pre-Launch (Week 11):
- ✅ Internal testing complete
- ✅ All 234+ tests passing
- ✅ Documentation updated
- ✅ Example datasets for new features
- ✅ Release notes drafted

### Launch (Week 12):
- ✅ Deploy v2.2.0
- ✅ Email announcement to users
- ✅ Updated Quick Start Guide
- ✅ Blog post (optional)
- ✅ Collect initial feedback

### Post-Launch (Weeks 13-14):
- ✅ Monitor usage analytics
- ✅ Fix critical bugs (priority)
- ✅ Collect feature requests
- ✅ Plan Phase 3 based on feedback

---

## 📈 Expected Outcomes

### User Experience:
- **Setup time**: -50% (column mapping)
- **Analysis time**: -30% (scenario compare, guardrails)
- **Report time**: -40% (PRISMA, BIA integration)
- **Total project time**: **-35% reduction**

### Market Position:
- ✅ Only tool with integrated MA + BIA
- ✅ Best data import UX in class
- ✅ Strongest QA/validation system
- ✅ Most comprehensive NICE compliance

### Revenue Impact:
- **Current clients** (upgrade): 5 × $10K = $50K
- **New clients** (v2.2): 10 × $25K = $250K
- **Year 1 target**: **$300K ARR**

---

## 🎓 Lessons from Phase 1

### What Worked:
- ✅ Small, focused sprints
- ✅ Test-driven development
- ✅ Document as you go
- ✅ User feedback early

### What to Improve:
- ⚠️ Better time estimates (add 20% buffer)
- ⚠️ More comprehensive testing plan upfront
- ⚠️ Earlier user testing (week 6, not week 10)
- ⚠️ Video tutorials earlier in process

---

## 📋 File Structure (New Modules)

```
frontend/modules/
├── scenario_compare.R       # NEW - Scenario comparison
├── prisma.R                 # NEW - PRISMA flow diagram
├── column_mapper.R          # NEW - Column mapping wizard
├── bia.R                    # NEW - Budget Impact Analysis
└── qa_checks.R              # NEW - Quality assurance dashboard

backend/etl/
├── validate.py              # ENHANCED - Method guardrails
└── column_patterns.py       # NEW - Auto-detection patterns

docs/
├── PHASE_2_V2_GUIDE.md      # NEW - Phase 2+v2 user guide
├── SCENARIO_COMPARE.md      # NEW - Scenario comparison docs
├── PRISMA_GUIDE.md          # NEW - PRISMA module guide
└── COLUMN_MAPPING.md        # NEW - Column mapping guide

tests/
├── test_scenario_compare.R  # NEW - Scenario compare tests
├── test_prisma.R            # NEW - PRISMA tests
├── test_bia.R               # NEW - BIA tests
└── test_column_mapper.R     # NEW - Column mapping tests
```

---

## ✅ Deliverables Checklist

### Code:
- [ ] 7 new R modules (scenario_compare, prisma, column_mapper, bia, qa_checks, protocol_snapshots, tooltips_enhanced)
- [ ] Enhanced Python validation (method_guardrails)
- [ ] Integration tests (50+ new tests)
- [ ] Example datasets (3 new)

### Documentation:
- [ ] Phase 2+v2 User Guide (8,000 words)
- [ ] Scenario Compare documentation
- [ ] PRISMA Guide
- [ ] Column Mapping Guide
- [ ] BIA Guide
- [ ] Updated Quick Start Guide
- [ ] API documentation (if needed)

### Release:
- [ ] v2.2.0 release notes
- [ ] Migration guide (v2.1 → v2.2)
- [ ] Changelog
- [ ] Known issues list

---

## 🎯 Next Actions

1. **Create feature branch**: `feature/phase-2-v2`
2. **Stub out 7 new modules** with function signatures
3. **Start with quick wins**: Enhanced tooltips, PRISMA (Week 1)
4. **Parallel development**: Scenario compare + Method guardrails (Week 2-3)
5. **Tackle column mapping** (largest, most complex) (Week 4-6)
6. **Finish with BIA** (Week 7-8)
7. **Test everything** (Week 9-11)
8. **Launch v2.2.0** (Week 12)

---

**Document Version**: 1.0
**Author**: Claude Code + User Vision
**Last Updated**: November 3, 2025
**Next Review**: After Week 6 milestone

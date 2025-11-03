# EvidenceOS PRIME - Quick Start Guide
## Get Started in 5 Minutes

**Version**: 2.0.0
**Last Updated**: November 3, 2025

---

## 🚀 Your First Meta-Analysis in 15 Minutes

This guide walks you through a complete meta-analysis workflow from data upload to final report.

---

### Step 1: Launch the Application (1 minute)

**Docker (Recommended)**:
```bash
cd docker
docker-compose up
# Open browser to: http://localhost:3838
```

**Local R**:
```R
setwd("frontend")
shiny::runApp()
```

✅ **Success Check**: You should see the EvidenceOS PRIME interface with tabs for Data, Protocol, Quality, Analysis, etc.

---

### Step 2: Upload Your Data (2 minutes)

1. **Navigate to "Data" tab** (first tab)

2. **Prepare your data file** (CSV or Excel):

   **For Binary Outcomes** (e.g., mortality, adverse events):
   ```
   study_id, events_exp, n_exp, events_ctrl, n_ctrl
   Smith2020, 15, 100, 25, 100
   Jones2021, 8, 50, 12, 50
   ```

   **For Continuous Outcomes** (e.g., blood pressure, weight):
   ```
   study_id, mean_exp, sd_exp, n_exp, mean_ctrl, sd_ctrl, n_ctrl
   Trial_A, 120, 15, 45, 130, 18, 43
   Trial_B, 118, 14, 60, 128, 16, 58
   ```

   **For Effect Sizes** (already calculated):
   ```
   study_id, yi, sei
   Study1, 0.45, 0.12
   Study2, 0.38, 0.15
   ```

3. **Click "Browse" and select your file**

4. **Select data type** (Binary, Continuous, or Effect Size)

5. **Click "Upload & Validate"**

✅ **Success Check**: You'll see a data preview table and validation results. Green checkmarks mean you're good to go!

📌 **Common Issues**:
- ❌ "Missing required column": Check column names match the format above
- ❌ "Events exceed sample size": Fix data entry errors (events > n)
- ❌ "Negative values": Standard deviations and sample sizes must be positive

💡 **Tip**: Click "Download Template" to get a pre-formatted Excel file with the correct column names.

---

### Step 3: Enter Study Protocol (Optional, 3 minutes)

**Why?** Documents your research question and creates an audit trail.

1. **Navigate to "Protocol" tab**

2. **Fill in PICO**:
   - **Population**: "Adults with Type 2 Diabetes"
   - **Intervention**: "GLP-1 agonists"
   - **Comparator**: "Placebo or standard care"
   - **Outcome**: "HbA1c reduction at 12-24 weeks"

3. **Add inclusion criteria**:
   - "Randomized controlled trials"
   - "Adults ≥18 years"
   - "Minimum 12 weeks follow-up"

4. **Click "Save Protocol"**

✅ **Success Check**: Protocol is saved and timestamp appears.

💡 **Tip**: You can skip this for quick analyses, but it's recommended for formal reviews.

---

### Step 4: Assess Risk of Bias (5 minutes)

**NEW FEATURE!** Cochrane RoB 2.0 tool now integrated.

1. **Navigate to "Quality" tab**

2. **Click "Create Assessment Template"**
   - Downloads a CSV file with all your studies

3. **Option A: Fill out in app**:
   - Select a study from dropdown
   - Rate each of 5 domains (Low / Some concerns / High)
   - Add notes
   - Click "Save Assessment"

4. **Option B: Fill out in Excel**:
   - Open downloaded template
   - Fill in ratings for all studies
   - Upload via "Upload Completed Assessments"

5. **View Results**:
   - **Summary Table**: Overall risk per study
   - **Traffic Light Plot**: Visual summary (green/yellow/red)

✅ **Success Check**: Traffic light plot shows all your studies with color-coded risk ratings.

💡 **Tip**: You can run sensitivity analysis later to see if results change when excluding high-risk studies.

---

### Step 5: Run Meta-Analysis (2 minutes)

1. **Navigate to "Analysis" tab → "Pairwise MA"**

2. **Configure analysis**:
   - **Outcome**: Select from dropdown (if you have multiple outcomes)
   - **Method**: REML (recommended - best for most meta-analyses)
   - **Model**: Random Effects (recommended - accounts for study differences)

3. **Click "Run Analysis"**

4. **View Results Tabs**:
   - **Summary**: Pooled effect, confidence interval, heterogeneity (I², τ²)
   - **Forest Plot**: Visual of all studies + pooled estimate
   - **Funnel Plot**: Check for publication bias (asymmetry)
   - **Heterogeneity**: Detailed stats (Q test, prediction interval)
   - **Publication Bias**: Egger's test, PET-PEESE correction

✅ **Success Check**: Forest plot appears with your studies and a diamond showing the pooled effect.

**Understanding Results**:
```
Pooled Effect: 0.72 (95% CI: 0.58 to 0.91)
```
- **OR = 0.72**: Treatment reduces odds by 28%
- **95% CI excludes 1.0**: Statistically significant
- **I² = 45%**: Moderate heterogeneity

📌 **Statistical Terms Explained**:
- **REML**: Restricted Maximum Likelihood - best method for estimating between-study variance
- **τ² (tau-squared)**: Between-study variance - how much studies differ
- **I²**: Percentage of variation due to heterogeneity (not chance)
  - 0-40%: Low heterogeneity
  - 30-60%: Moderate heterogeneity
  - 50-90%: Substantial heterogeneity
  - 75-100%: Considerable heterogeneity
- **Prediction Interval**: Where we expect 95% of future study results to fall

---

### Step 6: Check Publication Bias (1 minute)

1. **Still in "Analysis" tab → "Publication Bias" sub-tab**

2. **Review Funnel Plot**:
   - Symmetric = good (no obvious bias)
   - Asymmetric = concern (may be publication bias)

3. **Check Egger's Test**:
   - p > 0.10: No strong evidence of bias
   - p < 0.10: Possible bias

4. **Use PET-PEESE** (if bias suspected):
   - Provides bias-adjusted effect estimate
   - Compare to conventional pooled effect

✅ **Success Check**: You have a publication bias assessment with multiple methods.

💡 **Interpretation**:
- If Egger p < 0.10 AND funnel plot asymmetric → bias likely
- PET-PEESE estimate < conventional estimate → bias inflated effect
- Always report both conventional and bias-adjusted estimates

---

### Step 7: Generate Report (1 minute)

1. **Navigate to "Reports" tab → "Generate Reports"**

2. **Select format**:
   - Word (.docx) - for manuscripts
   - PDF - for stakeholders
   - PowerPoint - for presentations

3. **Choose sections**:
   - ✅ Methods
   - ✅ Results
   - ✅ Forest plots
   - ✅ Tables
   - ✅ References

4. **Click "Generate Report"**

5. **Download** from outputs folder

✅ **Success Check**: Report includes formatted methods text, results table, embedded forest plot, and citations.

💡 **What's Included**:
- **Methods**: Auto-generated based on your analysis choices
  - "Meta-analysis performed using random-effects model with REML estimator..."
  - Proper citations (DerSimonian & Laird 1986, Hartung & Knapp 2001, Riley et al. 2011)
- **Results**: Publication-ready tables
- **Figures**: High-resolution forest and funnel plots
- **Interpretation**: Heterogeneity assessment, bias assessment

---

## 🎯 Common Workflows

### Workflow A: Simple Pairwise Meta-Analysis

**Time**: 10-15 minutes
**Use Case**: Comparing treatment A vs. control

```
1. Data → Upload CSV with events/n
2. Analysis → Pairwise MA → Run
3. Check heterogeneity (I²)
4. Check publication bias (Egger, funnel plot)
5. Reports → Generate Word document
```

**Key Decision Points**:
- I² > 50%? → Use random effects (already default)
- Egger p < 0.10? → Report PET-PEESE adjusted estimate
- High risk of bias in most studies? → Run sensitivity analysis

---

### Workflow B: Network Meta-Analysis (NMA)

**Time**: 20-30 minutes
**Use Case**: Comparing multiple treatments (A vs. B vs. C vs. Placebo)

```
1. Data → Upload with treatment pairs (treatment1, treatment2, effect)
2. Analysis → Network MA → Create network diagram
3. Check transitivity (Effect modifiers similar across comparisons?)
4. Run consistency model
5. Check inconsistency (Node-splitting)
6. View league table (all pairwise comparisons)
7. Treatment rankings (SUCRA)
8. Reports → Generate
```

**Key Decision Points**:
- Transitivity violated? → Consider meta-regression or subgroups
- Inconsistency detected? → Investigate sources, sensitivity analysis
- Star network with few studies? → Interpret with caution

---

### Workflow C: Meta-Analysis + Health Economics

**Time**: 45-60 minutes
**Use Case**: NICE submission with cost-effectiveness analysis

```
1. Data → Upload meta-analysis data
2. Analysis → Pairwise MA → Get hazard ratios
3. Economics → Parameters → Enter costs, utilities
4. Economics → Model → Run Markov model with PSA
5. Economics → Results → ICER, CEAC, EVPI
6. Reports → Generate HTA dossier
```

**Key Outputs**:
- Meta-analysis: Pooled hazard ratio with CI
- Cost-effectiveness: ICER (£/QALY)
- Uncertainty: CEAC showing probability cost-effective
- Value of research: EVPI (£ value of eliminating uncertainty)

---

## 📊 Example Datasets

We've included example datasets for you to explore:

### Example 1: Binary Outcome (Mortality)
**File**: `data/examples/mortality_trials.csv`
**Description**: 12 RCTs comparing beta-blockers vs. placebo for heart failure
**Load**: Data tab → "Load Example" button → Select "Mortality (Binary)"

### Example 2: Continuous Outcome (Blood Pressure)
**File**: `data/examples/blood_pressure.csv`
**Description**: 15 trials of antihypertensive drugs
**Load**: Data tab → "Load Example" button → Select "Blood Pressure (Continuous)"

### Example 3: Network Meta-Analysis
**File**: `data/examples/smoking_cessation_network.csv`
**Description**: Network of smoking cessation interventions (Senn2013 dataset)
**Load**: Analysis → Network MA → "Load Example Network"

---

## ❓ Frequently Asked Questions

### Data Import

**Q: What column names should I use?**

A: **Binary data**: `study_id, events_exp, n_exp, events_ctrl, n_ctrl`
   **Continuous data**: `study_id, mean_exp, sd_exp, n_exp, mean_ctrl, sd_ctrl, n_ctrl`
   **Effect sizes**: `study_id, yi, sei`

**Q: My Excel file has multiple sheets. Will it work?**

A: No, export to CSV first or use only the first sheet.

**Q: Can I use OR/RR with confidence intervals instead of raw events?**

A: Yes! Format: `study_id, yi (log OR/RR), sei (SE of log OR/RR)`
   To convert: `yi = log(OR)`, `sei = (log(CI_upper) - log(CI_lower)) / (2 * 1.96)`

**Q: I get "Validation failed" but no details. What's wrong?**

A: Check for:
- Missing study_id column
- Negative values in n, events, or SD
- Events > sample size (e.g., events_exp = 50, n_exp = 40)
- Special characters in study IDs (use letters, numbers, underscore only)

---

### Analysis

**Q: Should I use fixed or random effects?**

A: **Random effects** (default) is recommended for most meta-analyses because:
- Assumes studies differ (more realistic)
- Gives conservative (wider) confidence intervals
- Appropriate even if I² = 0%

Use **fixed effect** only if you're sure all studies estimate the same underlying effect (rare).

**Q: What method should I choose? (REML, DL, ML...)**

A: **REML** (default) is best for most situations:
- Less biased than DerSimonian-Laird (DL)
- Better with small number of studies
- Recommended by Cochrane

Only change if you have a specific reason (e.g., ML for sensitivity).

**Q: My I² is 85%. Is that a problem?**

A: High heterogeneity isn't always a problem, but investigate:
- Look for outliers (forest plot)
- Check if studies are clinically similar
- Consider subgroup analysis
- Use prediction interval (shows range of true effects)

Don't just report pooled effect - explain the heterogeneity!

**Q: What's the difference between confidence interval and prediction interval?**

A: **Confidence interval**: Where the *average* true effect likely is
   **Prediction interval**: Where *individual study* effects likely are

Example:
- CI: 0.6 to 0.9 (we're 95% sure the average effect is here)
- PI: 0.4 to 1.2 (95% of future studies will fall in this range)

PI is more useful for clinical decision-making!

---

### Risk of Bias

**Q: Do I have to assess risk of bias?**

A: Not mandatory for quick analyses, but **strongly recommended** for:
- Cochrane reviews (required)
- Journal publications (most require it)
- NICE submissions (required)

**Q: What's the difference between RoB 2.0 and the original RoB tool?**

A: RoB 2.0 (2019) is the updated version:
- More specific signaling questions
- Algorithmic overall rating (not subjective)
- Five domains instead of six
- Better inter-rater reliability

**Q: Can I import my robvis assessments?**

A: Yes! Export from robvis as CSV and upload via "Upload Completed Assessments"

---

### Publication Bias

**Q: My funnel plot is asymmetric. Does that mean publication bias?**

A: Not necessarily! Asymmetry can be caused by:
- Publication bias (yes, the concerning one)
- Heterogeneity (different study designs)
- Small-study effects (smaller studies more variable)
- Chance (with few studies)

Use multiple methods: Egger's test + PET-PEESE + visual inspection.

**Q: When should I use PET-PEESE?**

A: Use PET-PEESE when:
- Egger's test p < 0.10 (suggests bias)
- Funnel plot visually asymmetric
- You have at least 10 studies

PET-PEESE gives bias-corrected effect estimate.

**Q: Trim-and-fill vs. PET-PEESE - which is better?**

A: **PET-PEESE** (available in platform):
- More modern method (Stanley & Doucouliagos 2014)
- Better statistical properties
- Automatic PET vs. PEESE selection

Trim-and-fill is also available but less recommended.

---

### Network Meta-Analysis

**Q: What's transitivity and why does it matter?**

A: **Transitivity** = studies comparing different treatments are similar in terms of effect modifiers (age, severity, etc.)

**Why it matters**: If transitivity violated, indirect comparisons are invalid.

**Example**:
- Studies of A vs. B include young, healthy patients
- Studies of B vs. C include elderly, sick patients
- Indirect comparison A vs. C is biased!

**How to assess**: Use "Quality" tab → Transitivity assessment (automatic)

**Q: What's inconsistency in NMA?**

A: **Inconsistency** = disagreement between direct and indirect evidence

**Example**:
- Direct evidence: A vs. B shows OR = 0.8
- Indirect evidence (via C): A vs. B shows OR = 1.2
- Inconsistency p < 0.05 → Problem!

**How to detect**: Node-splitting (automatic in platform)

---

### Health Economics

**Q: Can I use this for FDA submissions?**

A: Platform is designed for **HTA submissions** (NICE, CADTH, PBAC), not FDA regulatory submissions.

For FDA: Focus on meta-analysis component only, not health economics.

**Q: What discount rate should I use?**

A: Depends on country:
- **UK (NICE)**: 3.5% for costs and QALYs
- **US**: 3% typically
- **Canada (CADTH)**: 1.5%

Select country-specific parameters in Economics → Parameters.

**Q: What's EVPI and do I need it?**

A: **EVPI** = Expected Value of Perfect Information
- Maximum amount worth paying to eliminate all uncertainty
- Required by NICE for high-cost interventions
- Helps prioritize future research

**Example**: EVPI = £2 million → conducting a new RCT (£5M) not worthwhile

---

### Reporting

**Q: Can I customize the report template?**

A: Currently templates are fixed, but you can:
- Edit generated Word document
- Copy plots and tables to your own template
- Export raw results to Excel

Customizable templates are in development (v2.1).

**Q: How do I cite the platform?**

A: Suggested citation:
```
EvidenceOS PRIME (Version 2.0.0). [Software]. (2025).
Available from: https://github.com/evidenceos/prime
```

Also cite the statistical methods used (auto-generated in reports).

**Q: Plots are too small in the report. Can I increase resolution?**

A: Plots are generated at 300 DPI (publication-quality).
For presentations, export plots separately from Analysis tab (right-click → Save).

---

## 🆘 Troubleshooting

### "API Unavailable" Error

**Symptoms**: Sidebar shows "✗ API Unavailable"

**Solutions**:
1. Check Python backend is running:
   ```bash
   cd backend/api
   python main.py
   ```
2. Check API URL in config (should be http://localhost:8000)
3. Check firewall not blocking port 8000

**Impact**: Data validation and some computations won't work. Analysis will still run (uses R directly).

---

### "Analysis Failed" Error

**Symptoms**: Click "Run Analysis" → Error message

**Common Causes**:
1. **No data uploaded**: Upload data first!
2. **Insufficient studies**: Need at least 2 studies for meta-analysis
3. **All studies have same effect**: Can't estimate τ² (use fixed effect)
4. **Zero cells in all studies**: Add continuity correction

**Debug Steps**:
1. Check data preview table for issues
2. Look at Validation tab for warnings
3. Try with example dataset to rule out software issue
4. Check R console for detailed error messages

---

### Plots Not Displaying

**Symptoms**: Gray box instead of plot

**Solutions**:
1. **Wait**: Large datasets take 10-30 seconds to plot
2. **Check browser console**: F12 → Console tab for JavaScript errors
3. **Update browser**: Chrome/Firefox/Edge latest version
4. **Disable ad blockers**: Sometimes block plotly graphics

---

### Session Crashed / Lost Data

**Symptoms**: "Disconnected from server" message

**Prevention**:
- Click "Save Session" regularly (sidebar)
- Enable auto-save (Settings → Auto-save every 5 min)

**Recovery**:
- Click "Load Session" and select latest .json file from outputs/
- All analyses, plots, and data will be restored

---

## 📚 Next Steps

### Beginner → Intermediate
1. ✅ Complete your first meta-analysis (this guide)
2. 📖 Read the **Standard Operating Procedures** (`docs/STANDARD_OPERATING_PROCEDURES.md`)
3. 🎓 Take online course: "Meta-Analysis in Practice" (link)
4. 🔬 Try sensitivity analyses (leave-one-out, subgroups)

### Intermediate → Advanced
1. 📖 Read **Cochrane Handbook** Chapter 10 (meta-analysis)
2. 🌐 Learn network meta-analysis (NICE DSU TSDs)
3. 💰 Explore health economics (NICE reference case)
4. 📊 Master publication bias methods (PET-PEESE, selection models)

### Advanced → Expert
1. 📖 Read **NICE DSU Technical Support Documents** (all 5)
2. 📄 Read original methods papers:
   - Riley et al. (2011) - Prediction intervals
   - Stanley & Doucouliagos (2014) - PET-PEESE
   - Dias et al. (2010) - NMA inconsistency
   - Sterne et al. (2019) - RoB 2.0
3. 🛠️ Contribute to platform development (GitHub)

---

## 📞 Getting Help

### Documentation
- **This guide**: Quick start and workflows
- **SOPs**: `docs/STANDARD_OPERATING_PROCEDURES.md` - detailed procedures
- **Validation Protocol**: `docs/VALIDATION_PROTOCOL.md` - for regulatory use
- **Usability Review**: `docs/USABILITY_REVIEW_THREE_PERSPECTIVES.md` - user feedback

### Community
- **GitHub Issues**: https://github.com/evidenceos/prime/issues
- **Discussions**: https://github.com/evidenceos/prime/discussions
- **Email Support**: support@evidenceos.com

### Training
- **Webinars**: Monthly live training sessions (register on website)
- **Video Tutorials**: YouTube channel (5-10 minute walkthroughs)
- **Consulting**: Custom training for teams (contact sales)

---

## ✨ Pro Tips

1. **Use example datasets first**: Before uploading your data, try an example to learn the interface

2. **Save early, save often**: Click "Save Session" after each major step

3. **Check validation warnings**: Yellow warnings won't stop analysis but may affect results

4. **Use prediction intervals**: More informative than confidence intervals for heterogeneous meta-analyses

5. **Run sensitivity analyses**: Always check if results are robust (leave-one-out, RoB)

6. **Document your choices**: Use Protocol tab to record decisions (helps with reproducibility)

7. **Export Evidence Object**: Downloadable JSON contains everything for complete reproducibility

8. **Read the SOPs**: Comprehensive procedures with code examples and QC checklists

9. **Join the community**: GitHub Discussions for tips, troubleshooting, and feature requests

10. **Give feedback**: Your input shapes future development!

---

## 🎉 You're Ready!

You now have everything you need to run your first meta-analysis in EvidenceOS PRIME.

**Remember**:
- Start with the example datasets
- Follow the workflows step-by-step
- Check the FAQ when you get stuck
- Save your sessions regularly

**Happy meta-analyzing!** 📊✨

---

**Version History**:
- v2.0.0 (2025-11-03): Added RoB 2.0 tool, simplified navigation, improved tooltips
- v1.0.0 (2024-12-01): Initial release

**Feedback**: Found this guide helpful? Have suggestions? Open an issue on GitHub!

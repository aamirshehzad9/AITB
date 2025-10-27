---
name: Pull Request
about: Submit changes to AITB codebase
title: "[COMPONENT] Brief description of changes"
labels: ["needs-review"]
assignees: []
---

## ⚠️ Mandatory Pre-Submission Checklist

- [ ] **I have read `/context/project_manifest.yaml` before making any changes**
- [ ] **I understand the project structure, services, and volume mappings**
- [ ] **I have verified mockable status in manifest before adding any mocks**

## 📋 Change Summary

### What does this PR do?
<!-- Provide a clear, concise description of the changes -->

### Which components are affected?
<!-- Check all that apply -->
- [ ] **Core Services** (bot, inference, webapp, dashboard)
- [ ] **Data Pipeline** (influxdb, telegraf, grafana)
- [ ] **Infrastructure** (docker-compose, volumes, networks)
- [ ] **Scripts** (PowerShell automation scripts)
- [ ] **Documentation** (README, API contracts, manifests)
- [ ] **Configuration** (environment, settings, secrets)

### Type of Change
<!-- Check all that apply -->
- [ ] 🐛 **Bug Fix** (fixes an issue without breaking existing functionality)
- [ ] ✨ **New Feature** (adds new functionality without breaking existing)
- [ ] 💥 **Breaking Change** (causes existing functionality to stop working)
- [ ] 📚 **Documentation** (updates to docs, README, comments)
- [ ] 🔧 **Configuration** (environment, docker, settings changes)
- [ ] 🧪 **Testing** (adds or updates tests, no production code changes)
- [ ] ♻️ **Refactoring** (code changes that don't fix bugs or add features)

## 🚫 Mock Policy Compliance

**Current `mockable` status in manifest:** `false` (mocks forbidden)

- [ ] **No mocks added** (mockable: false in manifest)
- [ ] **Mocks required** (changed manifest to mockable: true with justification)
- [ ] **Mock removal** (removing existing mocks to improve reliability)

### Mock Justification (if applicable)
<!-- Only fill if adding mocks when mockable: true -->
```
Reason for enabling mocks:
- [ ] Development/testing phase only
- [ ] External service unavailable
- [ ] Performance testing requirements
- [ ] Other: _______________

Rollback plan: _______________
```

## 🔄 Service Impact Assessment

### Services Requiring Restart
<!-- Check services that need restart after this change -->
- [ ] **aitb-bot** (trading engine)
- [ ] **aitb-inference** (ML inference)
- [ ] **aitb-webapp** (ASP.NET dashboard)
- [ ] **aitb-dashboard** (Streamlit interface)
- [ ] **aitb-influxdb** (time-series database)
- [ ] **aitb-telegraf** (metrics collector)
- [ ] **aitb-grafana** (visualization)
- [ ] **aitb-notifier** (Telegram alerts)
- [ ] **aitb-watchtower** (container updates)

### Volume/Data Impact
<!-- Check if changes affect persistent data -->
- [ ] **Database Schema** (affects stored data structure)
- [ ] **Volume Mappings** (changes D:\docker\* bind mounts)
- [ ] **Configuration Files** (updates configs requiring restart)
- [ ] **Log Rotation** (affects logging configuration)

## 🧪 Testing

### Pre-Submission Testing
- [ ] **Local Docker Build** (`docker-compose build`)
- [ ] **Service Health Checks** (all services start successfully)
- [ ] **Integration Testing** (services communicate properly)
- [ ] **Volume Persistence** (data survives container restart)

### Health Validation
- [ ] **Bot heartbeat logs** appearing every ≤60s
- [ ] **Grafana-InfluxDB** connection working
- [ ] **Webapp** renders at :5000
- [ ] **API endpoints** return expected responses

### Test Evidence
<!-- Paste command outputs or screenshots showing successful testing -->
```bash
# Example: docker-compose logs output showing successful startup
```

## 📁 Files Changed

### Critical Files (require extra review)
<!-- List any changes to these critical files -->
- [ ] `context/project_manifest.yaml`
- [ ] `docker-compose.yml`
- [ ] `AITB.env` or environment variables
- [ ] Database schemas or migration scripts
- [ ] API contracts in `contracts/`

### Configuration Changes
<!-- List configuration files modified -->
- [ ] Service configurations (appsettings.json, etc.)
- [ ] Volume mount paths
- [ ] Network definitions
- [ ] Environment variable requirements

## 🔐 Security Review

- [ ] **No secrets** committed to repository
- [ ] **Environment variables** properly externalized
- [ ] **API keys** referenced from `D:\Myenv.txt`
- [ ] **Network exposure** minimized and intentional
- [ ] **Container permissions** follow least-privilege

## 📝 Documentation Updates

- [ ] **README.md** updated if user-facing changes
- [ ] **API contracts** updated if endpoints changed
- [ ] **Project manifest** updated if services/volumes changed
- [ ] **Inline comments** added for complex logic
- [ ] **Breaking changes** documented with migration guide

## 🎯 Episode Compliance

**If this PR is part of an Episode:**

### Episode Number: ___
### Episode Objective: _______________

- [ ] **Episode requirements** fully satisfied
- [ ] **Acceptance criteria** met and tested
- [ ] **Agent logs** updated with completion status
- [ ] **Project manifest** reflects episode changes

## 🔄 Rollback Plan

**In case this PR causes issues:**

1. **Immediate rollback steps:**
   ```bash
   # Commands to quickly revert changes
   ```

2. **Data recovery plan** (if applicable):
   ```
   # Steps to restore data from backups
   ```

3. **Service restoration priority:**
   1. _______________
   2. _______________
   3. _______________

## 👥 Review Requirements

### Mandatory Reviewers
- [ ] **Technical Lead** (for architecture changes)
- [ ] **DevOps** (for infrastructure changes)
- [ ] **Security** (for security-sensitive changes)

### Review Focus Areas
<!-- Guide reviewers on what to focus on -->
- [ ] **Manifest compliance** - verify adherence to project manifest
- [ ] **Service integration** - check inter-service communication
- [ ] **Volume persistence** - validate data storage approach
- [ ] **Mock policy** - ensure no unauthorized mocks
- [ ] **Episode alignment** - confirm episode objectives met

## 📞 Additional Context

### Related Issues
<!-- Link to GitHub issues this PR addresses -->
- Closes #___
- Related to #___

### Dependencies
<!-- List any dependent PRs or external requirements -->
- Depends on: _______________
- Blocks: _______________

### Performance Impact
<!-- Describe any performance implications -->
- [ ] **Improved performance**
- [ ] **Neutral impact**
- [ ] **Temporary performance reduction** (with mitigation plan)

---

## ⚡ Quick Reviewer Checklist

**For reviewers - quick validation:**

1. ✅ **Manifest read?** - Agent referenced project manifest
2. ✅ **Mock policy?** - No unauthorized mocks added
3. ✅ **Service impact?** - Restart requirements documented
4. ✅ **Testing done?** - Health checks passed
5. ✅ **Documentation?** - Changes documented appropriately

**🚀 Ready for review!**
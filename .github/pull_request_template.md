---
name: Pull Request
about: Submit changes to AITB codebase
title: "[COMPONENT] Brief description of changes"
labels: ["needs-review"]
assignees: []
---

# Pull Request

> **⚠️ MANDATORY: Agents MUST read `/context/project_manifest.yaml` before any action. Do not modify runtime or secrets in staging/prod. Run ACCEPTANCE.md before merge.**

## Problem
<!-- What specific issue does this PR solve? Include relevant context, error messages, or user stories. -->


## Change
<!-- What changes were made to address the problem? -->

### Summary
<!-- Brief description of the solution -->

### Technical Details
<!-- Implementation specifics, algorithms, design decisions -->

### Files Modified
<!-- List key files changed and why -->
- [ ] 
- [ ] 
- [ ] 

## Acceptance
<!-- How will we verify this change works correctly? -->

### Testing Checklist
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Manual testing completed
- [ ] Integration tests pass
- [ ] **ACCEPTANCE.md validation completed**

### Deployment Checklist
- [ ] No breaking changes to existing APIs
- [ ] Database migrations tested (if applicable)
- [ ] Environment variables documented
- [ ] Configuration changes documented
- [ ] Security review completed (if applicable)

### Quality Assurance
- [ ] Code follows project style guidelines
- [ ] Documentation updated
- [ ] Error handling implemented
- [ ] Performance impact assessed
- [ ] Resource usage validated

## Impact
<!-- What are the expected effects of this change? -->

### User Impact
<!-- How will this affect end users? -->

### System Impact
<!-- How will this affect system performance, reliability, security? -->

### Risk Assessment
<!-- What could go wrong? Mitigation strategies? -->

### Rollback Plan
<!-- How can this change be safely reverted if needed? -->

---

## Labels
<!-- Add appropriate labels from: infra, contracts, api, webapp, bot, data, docs, ops -->

## Additional Notes
<!-- Any other relevant information, dependencies, or future considerations -->

## Related Issues
<!-- Link to related issues or previous PRs -->
Closes #
Relates to #

---

**Pre-Merge Checklist:**
- [ ] Project manifest checked: `/context/project_manifest.yaml`
- [ ] Acceptance criteria validated: `ACCEPTANCE.md`
- [ ] No runtime or secrets modified in staging/prod
- [ ] All CI checks passing
- [ ] Code review completed
- [ ] Merge conflicts resolved
# GitHub Labels Configuration for AITB

> **⚠️ MANDATORY: Agents MUST read `/context/project_manifest.yaml` before any action. Do not modify runtime or secrets in staging/prod. Run ACCEPTANCE.md before merge.**

## Component Labels (Episode 10)
infra           | #FF6B6B | Infrastructure, Docker, deployment, CI/CD, DevOps changes
contracts       | #4ECDC4 | API contracts, schemas, TradingView broker specifications  
api             | #45B7D1 | REST API implementation, endpoints, controllers
webapp          | #96CEB4 | ASP.NET webapp, frontend, UI/UX changes
bot             | #FFEAA7 | Trading logic, algorithms, bot services
data            | #DDA0DD | Database, data processing, storage, analytics
docs            | #98D8C8 | Documentation updates, README changes, guides
ops             | #F7DC6F | Monitoring, logging, alerts, operational tools

## 🎯 Episode Labels
episode-0       | #0052CC | Episode 0 - Load context
episode-1       | #1f77b4 | Episode 1 - Fix containers that crash  
episode-2       | #ff7f0e | Episode 2 - Pin runtime & paths
episode-3       | #2ca02c | Episode 3 - Health & readiness
episode-4       | #d62728 | Episode 4 - Contracts (TV-aligned)
episode-5       | #9467bd | Episode 5 - Acceptance run
episode-6       | #8c564b | Episode 6 - DB universals (contract-first)
episode-7       | #e377c2 | Episode 7 - README + guardrails

## 🏗️ Component Labels
component:bot           | #FFA500 | Trading bot engine
component:inference     | #FF6347 | ML inference service
component:webapp        | #4169E1 | ASP.NET web application
component:dashboard     | #32CD32 | Streamlit dashboard
component:database      | #8B4513 | Database (InfluxDB/PostgreSQL)
component:monitoring    | #FF1493 | Grafana/Telegraf monitoring
component:infrastructure| #708090 | Docker/compose/networking
component:scripts       | #DDA0DD | PowerShell automation scripts
component:docs          | #20B2AA | Documentation and guides
component:contracts     | #F0E68C | API contracts and schemas

## 🔧 Type Labels
type:bug               | #d73a4a | Something isn't working
type:feature           | #a2eeef | New feature or request
type:enhancement       | #0075ca | Improvement to existing feature
type:documentation     | #0052cc | Documentation updates
type:configuration     | #fbca04 | Configuration changes
type:testing          | #d4c5f9 | Testing related changes
type:refactor         | #5319e7 | Code refactoring
type:hotfix           | #B60205 | Critical fix for production

## 🚨 Priority Labels
priority:critical     | #B60205 | Critical priority - fix immediately
priority:high         | #d93f0b | High priority - fix soon
priority:medium       | #fbca04 | Medium priority - normal timeline
priority:low          | #0e8a16 | Low priority - when time permits

## 🔍 Status Labels
status:needs-review   | #fbca04 | Awaiting code review
status:in-progress    | #0075ca | Currently being worked on
status:blocked        | #d73a4a | Blocked by external dependency
status:ready-to-merge | #0e8a16 | Approved and ready for merge
status:on-hold        | #6f42c1 | Temporarily paused
status:duplicate      | #cfd3d7 | Duplicate of another issue/PR

## 🎪 Special Labels
breaking-change       | #B60205 | Contains breaking changes
manifest-compliance   | #0e8a16 | Adheres to project manifest
mock-required         | #d93f0b | Requires mock validation
security-sensitive    | #d73a4a | Security implications
performance-impact    | #fbca04 | May affect system performance
volume-changes        | #8B4513 | Affects volume mappings
service-restart       | #FF6347 | Requires service restart

## 🚫 Guardrail Labels
no-mocks-added        | #0e8a16 | Confirms no unauthorized mocks
manifest-read         | #0052cc | Agent read project manifest
health-checks-passed  | #0e8a16 | All health validations passed
episode-complete      | #6f42c1 | Episode fully completed
contract-first        | #20B2AA | Follows contract-first approach

## 🔄 Workflow Labels
needs:testing         | #fbca04 | Requires additional testing
needs:documentation   | #0052cc | Documentation needed
needs:security-review | #d73a4a | Security review required
needs:performance-test| #ff7f0e | Performance testing needed
ready-for-production  | #0e8a16 | Ready for production deployment

## 📊 Size Labels
size:XS              | #c5def5 | Extra small change
size:S               | #a2eeef | Small change
size:M               | #7057ff | Medium change  
size:L               | #d4c5f9 | Large change
size:XL              | #b60205 | Extra large change

## 🎨 Service Health Labels
service:healthy       | #0e8a16 | Service running normally
service:degraded      | #fbca04 | Service partially functional
service:down          | #d73a4a | Service not responding
service:restarting    | #ff7f0e | Service in restart loop

---

## 📋 Label Usage Guidelines

### For Pull Requests:
1. **Always include:** Component + Type + Priority
2. **Episode work:** Add episode-X label
3. **Breaking changes:** Add breaking-change label
4. **Mock validation:** Add no-mocks-added or mock-required
5. **Manifest compliance:** Add manifest-read label

### For Issues:
1. **Bug reports:** type:bug + component + priority
2. **Feature requests:** type:feature + component + priority  
3. **Episode tracking:** episode-X + status labels
4. **Service issues:** component + service health labels

### Automation Triggers:
- `ready-to-merge` → Auto-deploy to staging
- `episode-complete` → Update project manifest
- `breaking-change` → Require additional approvals
- `security-sensitive` → Require security team review

### Label Combinations:
```
✅ GOOD: component:bot + type:bug + priority:high + manifest-read
✅ GOOD: episode-5 + component:monitoring + status:in-progress
❌ BAD: No component label
❌ BAD: Mock changes without mock validation labels
```

---

*Use these labels to maintain consistency across AITB project management*
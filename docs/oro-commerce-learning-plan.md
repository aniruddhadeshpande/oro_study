# OroCommerce Solution Architect — Learning Plan

**Target audience:** Senior/Technical Architect, 13+ years IT, Magento/Adobe Commerce background.
**Target version:** OroCommerce **7.0 LTS** (released March 2026, supported to March 2030).
**Progression:** Install → Architecture discovery → HLD → OroCloud → Enterprise scenarios → LLD.

---

## Version orientation (read this first)

| Fact | Value | Source |
|---|---|---|
| Latest LTS | 7.0 (March 2026) | https://doc.oroinc.com/community/release-process/ |
| Previous LTS | 6.1 (March 2025), supported to March 2029 | same |
| Release cadence | One LTS per year, every March | same |
| EE support window | 48 months, +24 months Extended Coverage | same |
| CE patch window | 12 months after release | same |
| Dev branch | 7.1 (`master`) | https://github.com/oroinc/orocommerce-application |
| PHP | >= 8.4 | https://doc.oroinc.com/backend/setup/system-requirements/ |
| Symfony | 7.4 component line (per `oro/commerce` 7.0.0 requirements) | packagist `oro/commerce` |

**Doc URL convention.** `https://doc.oroinc.com/<path>/` with no version prefix resolves to the current LTS (7.0). Pinned versions use `https://doc.oroinc.com/6.1/<path>/`. The dev branch is `/master/`. Always confirm which version a page is showing — the banner at the top of each page tells you.

**Editions matter architecturally.** Several components you will assume are present are **Enterprise Edition only**. This is the single biggest trap coming from Magento, where Commerce vs Open Source differences are mostly functional:

| Component | CE | EE |
|---|---|---|
| Message queue transport | DBAL (database table) | **RabbitMQ** |
| Search engine | ORM (EAV tables in Postgres) | **Elasticsearch** |
| Redis cache config (`oro/redis-config`) | Not bundled | **Yes** |
| Multi-host / multi-org extras | No | Yes |

So a CE Docker install will *not* show you RabbitMQ or Elasticsearch. Plan for that in Stage 1.

---

## Stage 1 — Installation & Environment

**Estimated study time:** 8–12 hours.

### Topics
- Linux + Docker Engine + Compose v2 prerequisites
- Oro's three official local setup paths and when each applies
- Container topology of a running Oro application
- The `oro:install` lifecycle
- Post-install services: consumers, cron, websocket

### The three official setup paths — pick deliberately

| Path | Doc | What it gives you | Use when |
|---|---|---|---|
| **Docker demo** | https://doc.oroinc.com/backend/setup/demo-environment/docker/ | Fully containerised CE app, predefined config, `oro.demo` domain | Fastest route to a running system for architecture discovery. **Start here.** |
| **Docker + Symfony Server** | https://doc.oroinc.com/backend/setup/dev-environment/docker-and-symfony/ | Services (Postgres, Elasticsearch, RabbitMQ, Redis, MailCatcher) in Docker; PHP/Node on host | Real development, and the only easy way to see ES + RabbitMQ locally |
| **Native (Ubuntu/macOS/Windows)** | https://doc.oroinc.com/backend/setup/dev-environment/ | Everything on host | Rarely worth it now |

### Hands-on exercises

**1.1 — Stand up the Docker demo**
```bash
git clone https://github.com/oroinc/docker-demo.git
cd docker-demo
echo "ORO_APP_DOMAIN=oro.demo" > .env      # optional; oro.demo is the default
docker compose up restore                   # restores a pre-built DB dump (fast)
# or: docker compose up install             # installs from scratch (slow, more instructive)
docker compose up application
echo "127.0.0.1 oro.demo" | sudo tee -a /etc/hosts
```
Then open `http://oro.demo` (storefront) and `http://oro.demo/admin` (back-office).

**1.2 — Inventory the topology.** Before reading any architecture doc, derive it yourself:
```bash
docker compose ps
docker compose config --services
docker compose logs -f php-fpm-app
```
Write down every container, its role, and its ports. Compare against your mental model of a Magento stack. Note what is *missing* versus what you expected.

**1.3 — Run the install by hand at least once.** The `restore` path hides the interesting part. Run `docker compose up install` on a second checkout and read the log. You are looking for the ordered phases: schema creation → migrations → fixtures/demo data → assets build → search reindex → cache warmup.

**1.4 — Second environment with EE-shaped services.** Follow the Docker + Symfony Server guide so you have Elasticsearch and RabbitMQ containers to inspect in later stages, even if the CE app doesn't use them.

### Learning objectives
- Explain every container in a running Oro stack and what breaks if it stops.
- Explain what `oro:install` does, phase by phase, and why it is not idempotent in the way `bin/magento setup:install` is.
- Explain why consumers and cron are *not optional* for a functioning Oro application.

### Expected outcome
A running storefront + back-office, and a hand-drawn container topology diagram you produced from `docker compose ps`, not from documentation.

---

## Stage 2 — Oro Fundamentals (platform concepts)

**Estimated study time:** 10–14 hours.

### Topics
- OroPlatform vs OroCRM vs OroCommerce — the three-layer product stack
- Bundles, and how they differ from Magento modules
- Organization / Business Unit / User — the ownership tree
- Website / Localization / Customer / Customer Group — the scope tree
- Hierarchical system configuration
- Entity system: regular, extended, and custom entities
- Workflows, Processes, Operations (Actions)
- Datagrids

### Documentation
- https://doc.oroinc.com/user/solution-architect/concepts/ — start here; it is written for your role
- https://doc.oroinc.com/backend/architecture/structure/
- https://doc.oroinc.com/backend/architecture/framework/architecture-principles/
- https://doc.oroinc.com/backend/architecture/differences/ — **read this one twice**; it is the "why is this not just Symfony" page
- https://doc.oroinc.com/backend/entities/
- https://doc.oroinc.com/backend/scopes/
- https://doc.oroinc.com/user/glossary/

### The conceptual mapping that will trip you up

Magento's `website → store → store view` is a *content and pricing* hierarchy. Oro has **two orthogonal trees**, and conflating them is the classic Magento-architect mistake:

- **Ownership tree** — Organization → Business Unit → User. Drives ACL access levels (`User / Business Unit / Division / Organization / System`). Magento has no equivalent; its ACL is role→resource, with no record-level ownership.
- **Scope tree** — Website, Customer, Customer Group, Localization, Customer User. Drives configuration, visibility, pricing, web catalogs, menus.

Multi-organization in Oro EE is closer to *multi-tenant within one installation* than to Magento's multi-website.

### Hands-on exercises
```bash
# Inside the app container
php bin/console debug:container --show-private | wc -l     # service count — compare to Magento's DI graph
php bin/console debug:router | grep oro_product            # storefront vs back-office route naming
php bin/console oro:entity-config:debug --help
php bin/console oro:workflow:definitions:load --help
```
In the back-office, walk: System → User Management → Organizations / Business Units; System → Websites; System → Configuration and observe the scope selector at the top of the configuration page.

### Learning objectives
- Draw the ownership tree and the scope tree separately, and state which features read from which.
- Explain what an *extended entity* is and why Oro generates entity classes into `var/cache`.
- Explain the difference between a Workflow, a Process, and an Operation.

---

## Stage 3 — Architecture (reverse-engineered from the running system)

**Estimated study time:** 16–20 hours.

### Topics
- Application layer: Symfony kernel → Oro bundles → services → controllers
- Storefront layout engine vs back-office Twig rendering
- Doctrine ORM, migrations, extended-entity generation
- Cache layers: Symfony cache, Doctrine cache, Oro layout cache, HTTP cache
- Search: standard (back-office) index vs website (storefront) index
- Message queue: producer → transport → consumer → processor
- Cron / scheduled tasks
- WebSocket notifications
- File storage (Gaufrette abstraction)
- REST API (JSON:API), OAuth2, OpenAPI specs

### Documentation
| Topic | URL |
|---|---|
| Technology stack index | https://doc.oroinc.com/backend/architecture/tech-stack/ |
| Database | https://doc.oroinc.com/backend/architecture/tech-stack/database/ |
| File storage | https://doc.oroinc.com/backend/architecture/tech-stack/file-storage/ |
| Session storage | https://doc.oroinc.com/backend/architecture/tech-stack/session-storage/ |
| Message queue (tech stack) | https://doc.oroinc.com/backend/architecture/tech-stack/message-queue/ |
| Search index | https://doc.oroinc.com/backend/architecture/tech-stack/search/ |
| Message queue (developer) | https://doc.oroinc.com/backend/mq/ |
| Consumer | https://doc.oroinc.com/backend/mq/consumer/ |
| RabbitMQ (EE only) | https://doc.oroinc.com/backend/mq/rabbit-mq/ |
| Supervisord | https://doc.oroinc.com/backend/mq/supervisord/ |
| Cron | https://doc.oroinc.com/backend/cron/ |
| WebSockets | https://doc.oroinc.com/backend/websockets/ |
| Security / ACL | https://doc.oroinc.com/backend/security/acl/ |
| API guide | https://doc.oroinc.com/api/ and https://doc.oroinc.com/backend/api/ |
| Storefront REST API | https://doc.oroinc.com/backend/api/storefront/ |

### Official diagrams available at this stage
- Search index structure — https://doc.oroinc.com/_images/op_search_diag.png
- ORM search data structure — https://doc.oroinc.com/_images/op_structure_search_orm.png
- Elasticsearch data structure — https://doc.oroinc.com/_images/op_structure_search_elastic.png
- Search query object model — https://doc.oroinc.com/_images/op_structure_search_index_object_representation.png

> No official end-to-end request-flow diagram, messaging-architecture diagram, or caching-architecture diagram was found on doc.oroinc.com. Conceptual diagrams in the runbook are provided for learning and are explicitly marked as such.

### Hands-on exercises
```bash
php bin/console debug:event-dispatcher | head -50
php bin/console oro:message-queue:consume -vvv           # watch a message get processed
php bin/console oro:cron:definitions:load --dry-run
php bin/console oro:search:reindex --scheduled
php bin/console oro:website-search:reindex --scheduled
php bin/console cache:pool:list
```
Then: add a product in the back-office with consumers **stopped**, and observe that it does not appear on the storefront. Start a consumer and watch it appear. That single experiment teaches you more about Oro's architecture than any diagram.

### Learning objectives
- Trace a storefront product-listing request end to end, naming the component at each hop.
- Explain why Oro has two search indexes and what each is optimised for.
- Explain the consequence of stopping consumers, precisely, for each affected feature.

---

## Stage 4 — HLD

**Estimated study time:** 14–18 hours.

### Topics
- Logical architecture and component responsibilities
- Single-node vs multi-node deployment topologies
- Load balancing, web nodes, worker nodes, shared storage
- High availability per tier
- Horizontal and vertical scaling levers
- Performance: PHP-FPM, OPcache, Nginx, Redis, Postgres, ES, CDN
- Security: authentication, ACL, API security, network segmentation, WAF, headers

### Documentation
- https://doc.oroinc.com/user/solution-architect/cloud-infrastructure/ — deployment architecture, network segmentation, deployment types
- https://doc.oroinc.com/backend/setup/system-requirements/performance-optimization/
- https://doc.oroinc.com/backend/security/
- https://doc.oroinc.com/backend/security/security-headers/
- https://doc.oroinc.com/backend/mq/rabbit-mq/rabbit-mq-in-production/

### Official diagram
- Deployment / VM overview — https://doc.oroinc.com/_images/15-environment-diagram.png (on the Cloud and Infrastructure page)

### Architect questions to answer in writing
For each of: web node, consumer node, Postgres, Redis, RabbitMQ, Elasticsearch, shared file storage —
1. What is its failure mode and blast radius?
2. Is it a SPOF in a single-node topology? In a multi-node one?
3. What is the scaling lever, and what is the *next* bottleneck once you pull it?
4. What do you monitor, and what is the alert threshold?
5. What happens to it during a deployment?

### Expected outcome
A one-page HLD for a production OroCommerce EE deployment: components, redundancy, scaling strategy, and a stated RTO/RPO.

---

## Stage 5 — OroCloud

**Estimated study time:** 8–10 hours.

### Topics
- IaaS model (GCP or OCI), regions and zones
- Redundancy per tier
- Environment types and their intended data policies
- Network segmentation: application subnet, maintenance DMZ, NAT, bridge host, OpenVPN
- Backups, RPO/RTO, disaster recovery flow
- Maintenance tooling and deployment workflow
- Monitoring and support SLAs

### Documentation
| Topic | URL |
|---|---|
| OroCloud architecture | https://doc.oroinc.com/cloud/architecture/ |
| MessageQueue config on OroCloud | https://doc.oroinc.com/cloud/architecture/mq/ |
| Environment types | https://doc.oroinc.com/cloud/environments/ |
| Security | https://doc.oroinc.com/cloud/security/ |
| Shared responsibility (PCI DSS 4.0.1) | https://doc.oroinc.com/cloud/security/shared-responsibility-model/ |
| Monitoring | https://doc.oroinc.com/cloud/monitoring/ |
| Onboarding | https://doc.oroinc.com/cloud/onboarding/ |
| Maintenance commands | https://doc.oroinc.com/cloud/maintenance/basic-use/ |
| Deploy with pre-built assets | https://doc.oroinc.com/cloud/maintenance/deploy-pre-built-assets/ |
| Apply patches | https://doc.oroinc.com/cloud/maintenance/patches/ |
| Scheduled tasks | https://doc.oroinc.com/cloud/maintenance/scheduled-tasks/ |
| Environment variables | https://doc.oroinc.com/cloud/maintenance/env-vars/ |

### Official diagram
- OroCloud standard environment schema — https://doc.oroinc.com/_images/standard_average_environment_schema.png

### Key facts to internalise
- **Single-tenant.** Each OroCloud environment is an isolated GCP project or OCI tenancy. This is not a shared-tenancy SaaS.
- **Cold DR.** No DR resources are allocated or billed until DR is invoked. Minimum recovery time is 60 minutes *after approval*; the recovery point is the last daily backup. Compare that to what your stakeholders assume when they hear "managed cloud".
- **Backups:** hourly (7 days), weekly (4 weeks), monthly (12 months), AES-256 encrypted. RTO 30 min to a few hours.
- **Config as code** via Puppet, managed by Oro — not by you.
- **Two ingress paths only:** load balancer / Cloudflare tunnel, or the OpenVPN bridge. With Cloudflare Zero Trust there is *no* public entry point; `cloudflared` on the web node dials out over QUIC.

### Self-hosted vs OroCloud — fill this in yourself, then check against the docs

| Area | Self-hosted | OroCloud |
|---|---|---|
| Infrastructure | You provision and own everything | Oro-managed GCP project or OCI tenancy, single-tenant |
| Deployment | Your CI/CD, your release process | Oro maintenance tooling; deploy, patch, pre-built assets |
| Scaling | You size and scale every tier | Oro scales resources; tier changes are billed separately |
| Database | Your Postgres, your HA design | Postgres with a secondary-zone instance and automatic failover |
| Search | ORM (CE) or your own ES cluster (EE) | Elasticsearch cluster |
| Messaging | DBAL (CE) or your RabbitMQ (EE) | RabbitMQ cluster + scalable consumer service |
| Cache | Your Redis | Redis cluster with Sentinel failover |
| File storage | Local FS or your object store via Gaufrette | GridFS clustered filesystem |
| Monitoring | Yours to build | Oro 24/7 monitoring and incident handling |
| Security | Yours end to end | Segmented subnets, NAT, VPN bridge, WAF, PCI DSS / SOC 2 posture |
| Operations | Your team | Oro team, with maintenance windows |
| Upgrades | You plan and execute | Oro-assisted; you still own custom-code compatibility |
| Disaster Recovery | Yours to design and rehearse | Cold DR, designated DR region, customer approval required |

---

## Stage 6 — Enterprise Architecture Scenarios

**Estimated study time:** 12–16 hours.

Work each scenario as a written HLD, not a discussion. One page each, with a diagram.

**6.1 — High-traffic B2B, 10M+ SKUs, multiple organizations.**
Focus: website search index sizing and shard strategy; combined price list recalculation as the dominant async workload; product visibility resolution; datagrid performance; consumer fleet sizing; Postgres read scaling.

**6.2 — ERP integration (SAP / JD Edwards / Epicor).**
Focus: Oro's integration bundle vs plain API; sync vs async; idempotency keys; retry and dead-lettering; the import/export batch pipeline; back-pressure when the ERP is slow; reconciliation and monitoring. Note that pre-built connectors exist — https://doc.oroinc.com/user/integrations/pre-built/erp/ — and decide when to use one vs build.

**6.3 — Multi-region deployment.**
Focus: OroCloud keeps resources in a single region by design, across zones. So multi-region is an *architecture decision you must justify*, not a config toggle. Address traffic routing, write locality, search index placement, queue locality, and what DR actually buys you.

**6.4 — Migration to OroCloud.**
Focus: data migration and delta strategy, media/GridFS migration, cutover sequencing, DNS and whitelist changes (Oro provides both primary and DR IPs), rollback plan, validation checklist, downtime budget.

---

## Stage 7 — LLD

**Estimated study time:** 25–35 hours.

Only start once Stages 3–4 are solid.

### Topics and documentation
| Topic | URL |
|---|---|
| Create a bundle | https://doc.oroinc.com/backend/extension/create-bundle/ |
| Bundle-less structure | https://doc.oroinc.com/backend/architecture/bundle-less-structure/ |
| Create entities | https://doc.oroinc.com/backend/entities/create-entities/ |
| Migrations | https://doc.oroinc.com/backend/entities/migration/ |
| Extend entities | https://doc.oroinc.com/backend/entities/extend-entities/ |
| Repositories as services | https://doc.oroinc.com/backend/entities/repositories-as-a-service/ |
| Datagrids | https://doc.oroinc.com/backend/entities/data-grids/ |
| ACLs on entities | https://doc.oroinc.com/backend/entities/acls/ |
| Data fixtures | https://doc.oroinc.com/backend/entities-data-management/data-fixtures/ |
| Workflows | https://doc.oroinc.com/backend/entities-data-management/workflows/ |
| Operations (Actions) | https://doc.oroinc.com/backend/entities-data-management/actions/ |
| Message queue topics | https://doc.oroinc.com/backend/mq/message-queue-topics/ |
| MQ jobs | https://doc.oroinc.com/backend/mq/message-queue-jobs/ |
| Custom permissions | https://doc.oroinc.com/backend/security/permissions/ |
| Field ACL | https://doc.oroinc.com/backend/security/field-acl/ |
| Access rules | https://doc.oroinc.com/backend/security/access-rules/ |
| Feature toggle | https://doc.oroinc.com/backend/feature-toggle/ |
| System configuration | https://doc.oroinc.com/backend/system-configuration/ |
| API processors | https://doc.oroinc.com/backend/api/processors/ |
| Payment integrations | https://doc.oroinc.com/backend/extend-commerce/payment/ |
| Shipping integrations | https://doc.oroinc.com/backend/extend-commerce/shipping/ |
| Checkout customization | https://doc.oroinc.com/backend/extend-commerce/checkout-customization-methods/ |
| Automated tests | https://doc.oroinc.com/backend/automated-tests/ |

### The LLD concepts with no clean Magento equivalent
Spend disproportionate time on these four, because your Magento instincts will actively mislead you:
1. **The API processor chain.** Oro's REST API is built as an ordered processor pipeline, not controllers. Customising the API means registering processors into a chain, not overriding a controller.
2. **Extended entities.** Fields added through the UI or through migrations generate real PHP classes into the cache. Static analysis will not see them (a known friction point).
3. **The layout engine.** Storefront rendering uses layout YAML + block hierarchies, not Magento's layout XML + blocks, and not plain Twig templating either.
4. **Operations / Action Groups / Workflows** as a declarative YAML business-logic layer. Magento has nothing comparable; the closest analogue is a state machine you would have hand-rolled.

---

## Stage 8 — Hands-on Architecture Projects

**Estimated study time:** 30–40 hours.

**8.1 — Failure injection lab.** On the Docker environment, kill each service in turn (`docker compose stop <svc>`). Document the exact user-visible symptom, the log signature, and the recovery procedure. This is the single highest-value exercise for interviews and for real incident work.

**8.2 — Consumer scaling experiment.** Bulk-import 50k products. Measure indexing lag with 1, 2, 4, 8 consumers. Find where the bottleneck moves from consumers to Postgres.

**8.3 — Custom bundle end to end.** One entity, one migration, one datagrid, one ACL, one async message processor, one API resource, one workflow transition. Small scope, full vertical slice.

**8.4 — Write the HLD.** Take scenario 6.1 and produce a real deliverable: component diagram, deployment diagram, sequence diagram for checkout, capacity model, HA/DR section, monitoring plan, risk register.

**8.5 — Certification.** Oro runs a certification programme at https://hive.oroinc.com/certifications/ — worth checking as a scope-and-syllabus reference even if you don't sit it.

---

## Interview questions to be able to answer cold

1. Why does Oro use two separate search indexes, and what would break if you merged them?
2. What is the practical consequence of RabbitMQ being Enterprise-only? How does CE behave under load without it?
3. Explain Oro's ACL access levels. How does record-level ownership change your data model versus Magento?
4. A customer reports that price changes take 20 minutes to appear on the storefront. Walk through your diagnosis.
5. Where is the SPOF in a default OroCloud production environment, and what is Oro's answer to it?
6. OroCloud DR is cold with a daily recovery point. How do you set stakeholder expectations, and what would you do differently if the business demands a 15-minute RPO?
7. How do you make an ERP order-sync integration idempotent in Oro?
8. Oro ships no GraphQL API. How does that change your headless/frontend architecture versus an Adobe Commerce project?
9. What happens to in-flight messages during a deployment, and how do you make deployments safe for consumers?
10. Explain extended entities and why they complicate static analysis, CI, and upgrade planning.

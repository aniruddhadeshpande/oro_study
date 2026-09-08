# OroCommerce Architecture Runbook

**Version basis:** OroCommerce **6.1.6 Community Edition** — corrected 2026-09-06 (Decision D1).
This runbook was first written against 7.0 LTS. That target is unreachable by the documented install
path: `oroinc/docker-demo` has no 7.0 branch and no tags, its `master` pins `ORO_IMAGE_TAG=6.1.6`,
and no 7.0 CE image has ever been published. Confirmed from inside the running container —
`composer.lock` reports `oro/commerce 6.1.6`, `oro/platform 6.1.6`, `oro/customer-portal 6.1.6`,
with no `oro/commerce-enterprise` package.

**Observed runtime (not the 7.0 requirements page):** PHP **8.4.14** · PostgreSQL **17.2** ·
Symfony **6.4.28** · **no Node.js in any image**. The 7.0 page states PHP ≥ 8.5, PG ≥ 17.6,
Node ≥ 24.11.0 — none of which describes what this install actually runs.

**Verification convention.** Every section carries a status:
- **VERIFIED** — demonstrated on this stack, with evidence in `logs/`.
- **`UNVERIFIED:`** — not demonstrated here. Retained because it is useful reference, but it has not
  been executed, fetched, or observed in this environment. Most EE, OroCloud, HA and scaling
  material falls here, and that is the honest outcome of a single-host CE demo.

A URL is only unprefixed if it was fetched **with a capture log to prove it**. Exactly two were:
`doc.oroinc.com/community/release-process/` and `doc.oroinc.com/backend/setup/demo-environment/docker/`.
Every other link in §21 is `UNVERIFIED:`.

---

## 0. Verification ledger

| § | Section | Status | Basis |
|---|---|---|---|
| 1 | Environment | **VERIFIED** | Phase 1 discovery, `logs/phase1-*` |
| 2 | Linux + Docker Installation | **VERIFIED as a check, not an install** | Docker 28.3.3 / Compose 2.39.1 pre-existing; task 3.1 |
| 3a | Docker demo (restore path) | **VERIFIED** | The path actually taken; tasks 3.2–3.7 |
| 3b | Docker + Symfony Server | `UNVERIFIED:` | Never run. Needs PHP/Node/PNPM on the host — package-state changes on the closed list |
| 3c | `oro:install` phases | `UNVERIFIED:` | The `install` service was **never created** — `restore` is its alternative, not its peer |
| 4 | Important Containers / Services | **VERIFIED** | 12 services enumerated; see final report Container Summary |
| 5 | Application Architecture | **PARTIAL** | Bundle layout read from the running tree; extension points not exercised |
| 6 | Request Flow | **VERIFIED** | `docs/03-request-flow.md`, measured headers |
| 7 | Data Flow (async) | **VERIFIED — measured** | Check-7 experiment: drain bound <8s, negative proven |
| 8 | Messaging / RabbitMQ | `UNVERIFIED:` | **EE only.** CE uses `ORO_MQ_DSN=dbal:` — a Postgres table. No broker exists here |
| 9 | Cache / Redis | **PARTIAL** | Filesystem cache in a shared volume VERIFIED. Redis unconfigured here but **available in CE** — bundle kernel-registered, `predis` + extension present. Corrected 2026-09-06 |
| 10 | Search | **PARTIAL** | ORM engine + two indices VERIFIED; Elasticsearch is EE, `UNVERIFIED:` |
| 11 | Scheduler / Cron / Workers | **VERIFIED** | 38 cron definitions; consumer lifecycle measured |
| 12 | OroCloud Architecture | `UNVERIFIED:` | Nothing about a managed cloud is observable from a laptop |
| 13 | Deployment Architecture | `UNVERIFIED:` | No deployment performed |
| 14 | Scaling | `UNVERIFIED:` | Single host, single instance of every service |
| 15 | High Availability | `UNVERIFIED:` | No HA construct exists in this stack |
| 16 | Security | `UNVERIFIED:` | No TLS, no hardening — explicitly out of scope |
| 17 | Monitoring | **PARTIAL** | The *rule* is verified (T5: alert on queue depth, not container state); no monitoring stack deployed |
| 18 | Troubleshooting | **VERIFIED** | Six real failures, T1–T6, all hit in this project |
| 19 | Important CLI Commands | **PARTIAL** | Corrected to absolute path; several commands never run |
| 20 | Architecture Diagrams | `UNVERIFIED:` | No official Oro diagram was located; conceptual diagrams provided in `docs/` |
| 21 | Official Documentation Links | **2 of ~30 VERIFIED** | Only two URLs have fetch evidence |
| 22 | Magento vs OroCommerce Mapping | **VERIFIED** | Rewritten from observation in `docs/04-magento-mapping.md` |

---

## 1. Environment

- **Target:** Linux workstation, Docker Engine + Compose v2, Git. Docker Desktop is not required.
- **Resources:** 4 CPU / 8 GB RAM minimum for a comfortable local stack; Oro's stated server minimum (2 CPU / 2 GB) is for a trimmed production node, not a dev box with all services.
- **Ports:** the demo stack binds **80**. Free it first. The dev stack also uses Postgres 5432, ES 9200, RabbitMQ 5672/15672, Redis 6379, MailCatcher 1025/1080.
- **Hosts entry:** `127.0.0.1 oro.demo` (or your `ORO_APP_DOMAIN`).
- **PHP:** `UNVERIFIED:` 7.0 requires >= 8.5. **Observed on 6.1.6: PHP 8.4.14, Symfony 6.4.28.**
- **Node.js:** **not present in any image.** Assets ship prebuilt inside `orocommerce-application:6.1.6`; there is no runtime toolchain and no way to rebuild them in this stack.
- **Database:** PostgreSQL. **Observed: 17.2** (`ORO_DB_VERSION`), not the >= 17.6 the 7.0 page states. Confirm current MySQL support status on the system-requirements page before promising it to a client.
- **Docs:** `UNVERIFIED:` UNVERIFIED: https://doc.oroinc.com/backend/setup/system-requirements/ (not fetched in this project; the figures on it are 7.0's, not 6.1.6's)

**Troubleshooting**
- Port 80 in use → `sudo ss -lntp | grep :80`.
- Permission errors on volumes → add your user to the `docker` group, `newgrp docker`, re-login.
- Slow first run → images plus assets build; 10–20 minutes is normal.

---

## 2. Linux + Docker Installation

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER" && newgrp docker
sudo systemctl enable --now docker
docker --version && docker compose version   # Compose v2 is a docker subcommand, not docker-compose
sudo apt-get install -y git curl ca-certificates
```

**Notes**
- Compose v2 (`docker compose`) is required. Older Oro docs show `docker-compose`; treat those as version-dated.
- Never run the stack as root — Oro's docs call this out specifically for Linux.

---

## 3. OroCommerce Installation

> **§3a VERIFIED** (the path taken). **§3b `UNVERIFIED:`** — the Symfony Server dev path was never
> run; it needs PHP/Node/PNPM on the host, which are package-state changes on the STOP-AND-ASK list.
> **§3c `UNVERIFIED:`** — the `install` service was **never created**. This stack used `restore`,
> and `install` is its alternative, not its peer. The install lifecycle is unobserved.

### 3a. Docker demo (fastest path to a running system)
Doc: https://doc.oroinc.com/backend/setup/demo-environment/docker/

```bash
git clone UNVERIFIED: https://github.com/oroinc/docker-demo.git
cd docker-demo
# optional: echo "ORO_APP_DOMAIN=my-app.demo" > .env
docker compose up restore        # restore from prebuilt dump — fast
# OR
docker compose up install        # install from scratch — slow, more instructive
docker compose up application
echo "127.0.0.1 oro.demo" | sudo tee -a /etc/hosts
```
- Locale variants: `cat .env-locale-de_DE >> .env` then restart `restore` and `application`.
- Default app image is `commerce-crm-application` (Community Edition).
- Logs: `docker compose logs -f php-fpm-app`. Containers: `docker compose ps`.
- Teardown: `docker compose down` (keep volumes) / `docker compose down -v` (destroy data).
- **This is not a production deployment.** Oro says so explicitly.

### 3b. Docker services + Symfony Server (real dev, shows ES/RabbitMQ)
Doc: UNVERIFIED: https://doc.oroinc.com/backend/setup/dev-environment/docker-and-symfony/

```bash
docker compose up -d                 # Postgres, ES, RabbitMQ, Redis, MailCatcher
composer install -o
# EE only — wire Redis DSNs into parameters.yml:
composer set-parameters \
  redis_dsn_cache='%env(ORO_REDIS_CACHE_DSN)%' \
  redis_dsn_doctrine='%env(ORO_REDIS_DOCTRINE_DSN)%' \
  redis_dsn_layout='%env(ORO_REDIS_LAYOUT_DSN)%'
symfony console oro:install -vvv --sample-data=y \
  --application-url=https://127.0.0.1:8000 \
  --user-name=admin --user-email=admin@example.com \
  --user-firstname=John --user-lastname=Doe --user-password=admin \
  --organization-name=Oro --timeout=0 --env=prod -n
```
- Use `symfony console`, not `php bin/console`, so Docker-exposed env vars and the right PHP version are picked up.
- `--timeout=0` prevents the install aborting on long migrations.

### 3c. `oro:install` phases (what actually happens)
1. Requirement checks → 2. DB schema creation → 3. migrations (`oro:migration:load`) → 4. entity config / extended-entity generation → 5. fixtures + optional demo data → 6. admin user + organization → 7. assets install and build → 8. search reindex → 9. cache warmup.

**Troubleshooting**
- *"exception … figure out your platform version"* → Postgres container not healthy yet. `docker compose ps`.
- Install times out → `--timeout=0`.
- Assets missing after install → `php bin/console oro:assets:build --env=prod`.

---

## 4. Important Containers / Services

| Service | Role | Stop it and… |
|---|---|---|
| `nginx` / web | TLS termination, static assets, proxy to FPM | Site down |
| `php-fpm-app` | Application request handling | Site down |
| `db` (PostgreSQL) | System of record | Everything down |
| `consumer` | Message queue worker daemon | Indexing, pricing, imports, emails silently stop |
| `cron` | Runs `oro:cron` every minute | Scheduled jobs stop; queue backlog grows |
| `websocket` | Push notifications to browser | UI notifications stop; app otherwise fine |
| `search` (Elasticsearch, EE) | Storefront + back-office search index | Search and product listings degrade or fail |
| `mq` (RabbitMQ, EE) | Message broker | Async processing stops |
| `redis` (**CE-capable**, not deployed here) | Cache / doctrine / layout / session | Severe performance loss or outage depending on wiring |
| `mail` | SMTP relay / MailCatcher in dev | Emails not delivered |

**The rule to remember:** in Oro, *consumers and cron are part of the application*, not optional background niceties. A "working" Oro install without a running consumer is a broken Oro install.

---

## 5. Application Architecture

- **Three stacked products:** OroPlatform (BAP: entities, ACL, config, datagrids, workflow, MQ) → OroCRM → OroCommerce. You are almost always customising at the OroCommerce layer but debugging into the Platform layer.
- **Symfony foundation**, but with substantial deviations — see UNVERIFIED: https://doc.oroinc.com/backend/architecture/differences/
- **Bundles** are the unit of extension (Magento module analogue). Also supported: bundle-less structure — UNVERIFIED: https://doc.oroinc.com/backend/architecture/bundle-less-structure/
- **Two front ends in one app:** back-office (Symfony controllers + Twig + datagrids) and storefront (layout engine: layout YAML + block trees).
- **Extended entities:** fields added via UI or migrations generate PHP classes into `var/cache`. Consequence: static analysis and IDE autocompletion do not see them; CI needs a cache-warm step.
- **Declarative business logic:** Workflows, Processes, Operations/Action Groups in YAML.
- **API:** JSON:API-based REST, with separate management and storefront APIs, OAuth2, and publishable OpenAPI specs.

Docs: UNVERIFIED: https://doc.oroinc.com/backend/architecture/structure/ · UNVERIFIED: https://doc.oroinc.com/backend/architecture/framework/architecture-principles/

> No official application-architecture diagram was found on doc.oroinc.com; conceptual diagram provided for learning.

```
┌───────────────────────────────────────────────┐
│ OroCommerce  (commerce, customer-portal, …)   │
├───────────────────────────────────────────────┤
│ OroCRM       (marketing, sales, activities)   │
├───────────────────────────────────────────────┤
│ OroPlatform  (entity, ACL, config, MQ, grids) │
├───────────────────────────────────────────────┤
│ Symfony 7.4  ·  Doctrine ORM  ·  PHP 8.4      │
└───────────────────────────────────────────────┘
```

---

## 6. Request Flow

> No official request-flow diagram was found on doc.oroinc.com; conceptual diagram provided for learning.

**Storefront (synchronous path)**
```
Browser
  → CDN / WAF (Cloudflare or GCP CDN on OroCloud)
  → Load balancer
  → Nginx            (static assets served directly)
  → PHP-FPM
  → Symfony kernel → Oro firewall (customer_user auth) → routing
  → Layout engine (block tree) + Twig
  → Application services
      ├→ Website search index (product listing, search, filters)
      ├→ Doctrine → PostgreSQL (cart, customer, order)
      └→ Cache (Redis / filesystem)
  → Response
```

**Back-office** is the same up to routing, then: controller → datagrid (ORM or search datasource) → ACL voter → Doctrine → Postgres → Twig.

**Where each concern enters**
- *Cache* — Symfony/Oro cache pools, Doctrine metadata + result cache, layout cache; Redis-backed in EE.
- *Search* — website index for storefront listings; standard index for back-office grids and global search.
- *Events* — Symfony event dispatcher; Oro adds search/indexation and workflow events on top of Doctrine lifecycle events.
- *Message queue* — anything slow is deferred here rather than done in-request.

---

## 7. Data Flow (asynchronous path)

```
User action / API call / import
  → Doctrine flush → PostgreSQL commit
  → Event listener produces a message
  → Message queue transport   (RabbitMQ in EE, DBAL table in CE)
  → Consumer daemon picks it up
  → Message processor (topic-specific)
  → Writes to: search index / DB / external system
  → (Job-tracked messages update oro_message_queue_job)
```

Typical async workloads: search reindexation, price-list recalculation, product visibility resolution, import/export batches, email sending, data audit, integration sync.

**Architect's note.** The gap between "committed to Postgres" and "visible on the storefront" is consumer lag. Almost every "why isn't my change showing" ticket in Oro resolves to this. Make it a monitored SLI.

---

## 8. Messaging / RabbitMQ

> **`UNVERIFIED:` — RabbitMQ is Enterprise Edition only and does not exist in this stack.**
> CE runs `ORO_MQ_DSN=dbal:`: the queue is the PostgreSQL table `oro_message_queue`, with no broker
> process at all. Everything below about AMQP, exchanges, clustering and broker tuning is reference
> material that this environment cannot demonstrate. What *was* measured is in §7 and
> `docs/03-request-flow.md`: enqueue is an INSERT, poll is a SELECT, ack is a DELETE, drain <8s.

- **Transport by edition:** RabbitMQ is **Enterprise Edition only**. CE uses the DBAL transport (a database table). Do not design a CE solution assuming broker semantics.
- **Consumer:** a long-running daemon. Multiple consumers run in parallel across hosts; that is the primary async scaling lever.
- **Jobs:** the job layer gives unique jobs, progress, and parent/child job trees on top of raw messages.
- **Process supervision:** supervisord in self-hosted deployments.

```bash
php bin/console oro:message-queue:consume -vvv
php bin/console oro:message-queue:consume --time-limit="+5 minutes"
php bin/console oro:message-queue:transport:consume        # low-level
php bin/console debug:oro:message-queue:topics             # if available in your version
```

**Troubleshooting**
- Backlog growing → check consumer count, check for a poison message, check `oro_message_queue_job` for stuck jobs.
- Consumer memory growth → this is expected; use `--time-limit` / `--memory-limit` and let supervisord restart it. See UNVERIFIED: https://doc.oroinc.com/backend/mq/consumer/reset-container/
- Repeated redelivery → UNVERIFIED: https://doc.oroinc.com/backend/mq/rabbit-mq/redeliver-with-limited-attempts/

Docs: UNVERIFIED: https://doc.oroinc.com/backend/mq/ · UNVERIFIED: https://doc.oroinc.com/backend/mq/rabbit-mq/ · UNVERIFIED: https://doc.oroinc.com/backend/mq/supervisord/ · UNVERIFIED: https://doc.oroinc.com/backend/mq/rabbit-mq/troubleshooting/ · UNVERIFIED: https://doc.oroinc.com/cloud/architecture/mq/

---

## 9. Cache / Redis

> **PARTIAL.** VERIFIED: no Redis; Symfony **filesystem** cache in a named volume `cache` mounted by
> `php-fpm-app`, `consumer` and `cron` alike — shared-filesystem coherence is how CE survives without
> a cache server, and it is the hard ceiling on scaling out. `cache:pool:list` returns `cache.app`,
> `cache.system`, `cache.validator`, `cache.serializer`, `oro.cache.serializer_pool`.
> **`UNVERIFIED:`** everything below about Redis *configuration* — no Redis service exists in this
> stack and none was wired.
>
> **CORRECTION 2026-09-06: Redis is NOT Enterprise-only.** An earlier revision of this runbook said
> it was. `RedisConfigBundle` ships in CE `oro/platform`, self-registers via its
> `Resources/config/oro/bundles.yml` (priority -210), and **is in this install's compiled kernel**;
> `predis` and the `redis` PHP extension are both installed. Redis is absent here because the demo
> topology declares no `redis` service, not because the edition forbids it. RabbitMQ (§8) and
> Elasticsearch (§10) *are* genuine edition boundaries — verified absent from the CE codebase.

- Layers: Symfony/Oro cache pools, Doctrine metadata and query cache, layout cache, session storage, HTTP cache.
- **Redis is wired via `RedisConfigBundle`, which ships in CE.** DSNs: `ORO_REDIS_CACHE_DSN`, `ORO_REDIS_DOCTRINE_DSN`, `ORO_REDIS_LAYOUT_DSN`. `UNVERIFIED:` — not configured or tested in this environment.
- OroCloud runs a Redis cluster with **Sentinel** for automatic failover.

```bash
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod
php bin/console cache:pool:list
php bin/console oro:assets:build --env=prod
```

**Troubleshooting**
- Changes not visible after a config/entity change → clear cache; extended entities need a cache rebuild.
- `cache:clear` on a large prod instance is expensive and disruptive. Prefer targeted pool clears.

Docs: UNVERIFIED: https://doc.oroinc.com/backend/architecture/tech-stack/session-storage/

---

## 10. Search

> **PARTIAL.** VERIFIED: `ORO_SEARCH_ENGINE_DSN=orm:?prefix=oro_search` (back office) and
> `ORO_WEBSITE_SEARCH_ENGINE_DSN=orm:?prefix=oro_website_search` (storefront) — **two separate
> indices**, both Postgres EAV, with independent lifecycles. Reindex measured end-to-end.
> **`UNVERIFIED:`** all Elasticsearch material — EE only. Note for Magento readers: ES being absent
> is *correct* here, not a misconfiguration.

**Two indexes, deliberately separate.** This is the design decision to be able to explain.

| | Standard (back-office) index | Website (storefront) index |
|---|---|---|
| Owner bundle | `OroSearchBundle` (platform) | `OroWebsiteSearchBundle` (commerce) |
| Scope | Global search, back-office datagrids, autocomplete | Storefront product listing, search, filters |
| ACL | Automatic — owner/organization fields injected, restrictions applied to the query | No blanket ACL; per-entity visibility rules (product status, inventory status, visibility settings) |
| Indexation granularity | Per entity | Per batch (default 100), scoped by website and entity |
| During reindex | Entities being reindexed are **unavailable** | Old data stays **available** |
| Placeholders | No | Yes — `WEBSITE_ID`, `LOCALIZATION_ID`, `CUSTOMER_ID`, `CURRENCY`, `CPL_ID` |
| Mapping file | `Resources/config/oro/search.yml` | `Resources/config/oro/website_search.yml` |

**Engines:** ORM (EAV tables in Postgres, CE, small datasets only) or **Elasticsearch (EE)**. Elasticsearch scales horizontally; default 5 shards, 1 replica.

```bash
php bin/console oro:search:reindex --scheduled              # back-office index, async
php bin/console oro:website-search:reindex --scheduled      # storefront index, async
# Force full rebuild after a mapping change (EE):
php bin/console cache:clear --env=prod
php bin/console oro:elasticsearch:create-standard-indexes --env=prod
php bin/console oro:search:reindex --env=prod --scheduled
php bin/console cache:clear --env=prod
php bin/console oro:website-elasticsearch:create-website-indexes --env=prod
php bin/console oro:website-search:reindex --env=prod --scheduled
```

**Partial indexation** field groups: `main`, `collection_sort_order`, `image`, `category_sort_order`, `visibility`, `pricing`, `order`, `customer_recommendation_action`, `customer_recommendation_revenue`, `inventory`. Use these to avoid full reindex for price-only or inventory-only changes.

**Upgrade lever:** `oro:platform:update --schedule-search-reindexation` (defer) or `--skip-search-reindexation` (skip). Critical for keeping deployment windows short.

**Documentation inconsistency to be aware of:** the tech-stack page states Elasticsearch 2.x support while a bundle page states 6.x. Do not quote either to a client — check the 7.0 system-requirements page and the actual `composer.lock`.

**Official diagrams**
- Index structure — UNVERIFIED: https://doc.oroinc.com/_images/op_search_diag.png
- ORM (EAV) data structure — UNVERIFIED: https://doc.oroinc.com/_images/op_structure_search_orm.png
- Elasticsearch data structure — UNVERIFIED: https://doc.oroinc.com/_images/op_structure_search_elastic.png
- Query object model — UNVERIFIED: https://doc.oroinc.com/_images/op_structure_search_index_object_representation.png

Docs: UNVERIFIED: https://doc.oroinc.com/backend/architecture/tech-stack/search/ · tuning: `/elastic-tuning/` · troubleshooting: `/troubleshooting/`

---

## 11. Scheduler / Cron / Workers

- One OS cron entry runs `oro:cron` **every minute**; Oro dispatches its own scheduled commands from there. Same pattern as Magento's single cron entry.
- Cron definitions load from bundle config; visible in the back-office at System → Scheduled Tasks.
- Workers = message queue consumers (section 8). Cron and consumers are different things and fail differently.

```bash
php bin/console oro:cron --env=prod
php bin/console oro:cron:definitions:load
```
Docs: UNVERIFIED: https://doc.oroinc.com/backend/cron/ · UNVERIFIED: https://doc.oroinc.com/cloud/maintenance/scheduled-tasks/

---

## 12. OroCloud Architecture

> **`UNVERIFIED:` — entire section.** Nothing about a managed cloud platform is observable from a
> single laptop. Retained as reference; none of it was demonstrated.

- **IaaS:** GCP or OCI. One GCP project or OCI tenancy per environment — **single-tenant isolation**.
- **Region/zone:** resources sit in one region for latency, spread across zones for fault tolerance.
- **Ingress:** GCP CDN + GCP load balancer, **or** Cloudflare. With Cloudflare Zero Trust there is no public entry point: `cloudflared` on the web node opens an outbound QUIC tunnel; TLS terminates in Cloudflare; nginx does the load balancing.
- **Web nodes:** at least two, in different zones.
- **Database:** PostgreSQL, at least two instances (main + secondary zone), automatic failover.
- **Search:** Elasticsearch cluster.
- **Queue:** RabbitMQ cluster; proprietary consumer service, scaled by adding processes/hosts.
- **Cache:** Redis cluster + Sentinel.
- **File storage:** GridFS clustered filesystem for attachments, images, documents.
- **SMTP:** dedicated relay with prioritised mail relays.
- **Config management:** Puppet, Oro-managed.

**Backups:** hourly (7 days) · weekly (4 weeks) · monthly (12 months) · AES-256 · RTO 30 min – few hours.
**DR:** cold standby, no resources allocated until invoked. Trigger criteria are region-level unavailability with no expected recovery inside an hour. Recovery point = last daily backup. Minimum 60 min to restore *after customer approval*. DNS updated by Oro unless the domain is customer-managed. Both primary and DR IPs are issued at onboarding — whitelist both.

**Official diagrams**
- OroCloud standard environment — UNVERIFIED: https://doc.oroinc.com/_images/standard_average_environment_schema.png
- Deployment / VM overview — UNVERIFIED: https://doc.oroinc.com/_images/15-environment-diagram.png

Docs: UNVERIFIED: https://doc.oroinc.com/cloud/architecture/ · UNVERIFIED: https://doc.oroinc.com/cloud/environments/ · UNVERIFIED: https://doc.oroinc.com/cloud/security/

---

## 13. Deployment Architecture

> **`UNVERIFIED:` — entire section.** No deployment was performed. The only "deploy" here was
> `docker compose up` against a prebuilt demo image.

**Deployment options** (from the Cloud and Infrastructure page): OroCloud, public cloud (hosted), private cloud (hosted), on-premise. Support coverage narrows sharply as you move right — on-premise gets application support only; no operations, no maintenance tooling, no DR, no infrastructure services.

**Environment types**

| Env | Users | Structure | Data |
|---|---|---|---|
| Development | Engineers | Single host | Minimal; sanitized if real |
| Testing / UAT | BA, stakeholders | Single host | Minimal; sanitized if real |
| Staging | BA, stakeholders, admins | **Multi-host** | Full volume, sanitized production data |
| Production | Admins, customers | **Multi-host** | Full |

**Network segmentation (OroCloud production)**
```
Internet
  → CDN / WAF (Cloudflare or GCP)
  → [ Application subnet ]  web nodes · app nodes · consumers · DB · Redis · ES · RabbitMQ
        ↑ only bridge host may connect in
        ↓ NAT node for outbound (fixed public IP — whitelist this with partners)
  → [ Maintenance DMZ subnet ]  OpenVPN gateway only (UDP/31194, MFA)
```
Only two access paths exist: the load balancer / Cloudflare tunnel, or the OpenVPN bridge.

**Deployment on OroCloud:** Oro maintenance tooling, including pre-built asset deploys and patch application.
Docs: UNVERIFIED: https://doc.oroinc.com/cloud/maintenance/basic-use/ · `/deploy-pre-built-assets/` · `/patches/`

---

## 14. Scaling

> **`UNVERIFIED:` — entire section.** Single host, one instance of every service, no load applied.
> Two concrete blockers *were* observed and are real: `ORO_SESSION_DSN=native:` (local-file sessions)
> and the shared filesystem cache volume. Both must change before a second web node is possible, and
> the replacement for the latter is `RedisConfigBundle`, which **ships in CE** — so scaling out is a
> configuration exercise here, not a licence purchase. (Corrected 2026-09-06.)

| Tier | Lever | Next bottleneck |
|---|---|---|
| Web / PHP-FPM | Add web nodes behind the LB; tune `pm.max_children` | Database connections |
| Consumers | Add consumer processes / hosts | Postgres write contention; ES indexing throughput |
| PostgreSQL | Vertical first; read replicas; connection pooling | Write path — cannot be sharded easily |
| Elasticsearch | Add nodes; tune shards (default 5) and replicas (default 1) | Indexing throughput vs query latency trade-off |
| Redis | Cluster + Sentinel | Rarely the bottleneck; watch eviction |
| RabbitMQ | Cluster nodes | Consumer count, not broker throughput, is usually the limit |
| Static/media | CDN + GridFS/object storage | Cache hit ratio |

**Statelessness.** App nodes must hold no local state: sessions in Redis, files in GridFS/object storage, cache shared. Any local-disk assumption breaks horizontal scaling.

**The B2B-specific load profile.** Unlike B2C, Oro's dominant background cost is usually **combined price list recalculation** and **product visibility resolution**, not traffic. Size the consumer fleet against catalog and price-list change volume, not against page views.

---

## 15. High Availability

> **`UNVERIFIED:` — entire section.** No HA construct exists in this stack: one `db`, one
> `php-fpm-app`, one `web`, one `consumer`, one bridge network, no failover of any kind.

| Tier | HA mechanism | Residual risk |
|---|---|---|
| CDN / LB | Provider-managed, globally distributed | Provider outage |
| Web nodes | ≥2 across zones, LB health checks | Zone-pair failure |
| PostgreSQL | Primary + secondary zone, automatic failover | Failover window; single region |
| Elasticsearch | Cluster, replica shards | Split-brain if misconfigured |
| RabbitMQ | Cluster, tolerates node loss | Message loss if durability misconfigured |
| Redis | Cluster + Sentinel | Cache-miss storm after failover |
| File storage | GridFS cluster | — |
| SMTP | Prioritised relay set (master-master style) | — |
| **Region** | **None — cold DR only** | **This is the real SPOF** |

Say this plainly in design reviews: OroCloud production is zone-redundant, not region-redundant. Cross-region resilience is a cold DR process with a daily recovery point and a ≥60-minute recovery time after human approval.

---

## 16. Security

> **`UNVERIFIED:` — entire section.** No TLS, no hardening, no firewall changes — explicitly out of
> scope per `specs/00-environment-spec.md`. The stack serves plain HTTP on port 80. Do not read any
> part of this section as validated.

- **Authentication:** back-office users and storefront customer users are separate firewalls and separate entities. OAuth2 for API; OpenID Connect and LDAP integrations available.
- **Authorization:** role-based ACL with **access levels tied to record ownership** — None / User / Business Unit / Division / Organization / System. Plus field-level ACL, configurable permissions, and access rules.
- **API security:** stateless firewalls, OAuth2 applications registered per user or customer user, CORS configuration, publishable OpenAPI specs.
- **Transport:** HTTPS only from the web; SSH with public-key auth for host access; data encrypted at rest.
- **Network:** subnet segmentation, NAT for egress, VPN bridge for maintenance, WAF for DoS/DDoS.
- **Data protection:** DB dumps are downloadable **sanitized only**. Sanitization replaces private data with random values.
- **Compliance posture:** PCI DSS and SOC 2. Shared-responsibility model documented at UNVERIFIED: https://doc.oroinc.com/cloud/security/shared-responsibility-model/
- **Security headers:** UNVERIFIED: https://doc.oroinc.com/backend/security/security-headers/
- **CSRF:** UNVERIFIED: https://doc.oroinc.com/backend/security/csrf-protection/

Docs: UNVERIFIED: https://doc.oroinc.com/backend/security/acl/ · UNVERIFIED: https://doc.oroinc.com/backend/security/role-based-access-control/ · UNVERIFIED: https://doc.oroinc.com/backend/security/example/

---

## 17. Monitoring

> **PARTIAL.** No monitoring stack was deployed, so tooling below is `UNVERIFIED:`. But the central
> *rule* is VERIFIED by experiment (T5): **alert on queue depth and oldest-message age, never on
> container liveness.** With the consumer stopped, the storefront returned 200, every service showed
> `running`, and all three healthchecks passed while work silently accumulated. Only 3 of 12 services
> define a healthcheck; `consumer`, `cron` and `ws` define none.

**What to monitor, in priority order**
1. **Consumer lag** — queue depth and oldest-message age. Your most important SLI.
2. **Stuck jobs** — `oro_message_queue_job` rows in a running state past threshold.
3. **Search index freshness** — time since last successful reindex per index.
4. **Postgres** — connections, slow queries, replication lag, bloat.
5. **PHP-FPM** — busy children, request duration, 5xx rate.
6. **Redis** — evictions, memory, Sentinel failover events.
7. **Cron** — last successful run per scheduled task.
8. **Elasticsearch** — cluster health (green/yellow/red), indexing rate, shard state.

- Healthcheck endpoints: UNVERIFIED: https://doc.oroinc.com/backend/setup/dev-environment/monitoring/
- Logging conventions: UNVERIFIED: https://doc.oroinc.com/backend/logging/ · MQ logging to ELK: UNVERIFIED: https://doc.oroinc.com/backend/mq/logging/elk-stack/ · Stackdriver: UNVERIFIED: https://doc.oroinc.com/backend/mq/stackdriver/
- OroCloud monitoring and incident handling: UNVERIFIED: https://doc.oroinc.com/cloud/monitoring/
- OroCloud support priorities: P1 4h initial response; P2–P4 24h.

---

## 18. Troubleshooting

| Symptom | Likely cause | First checks |
|---|---|---|
| Back-office change not on storefront | Consumer not running / queue backlog | `docker compose ps consumer`; queue depth; `oro:website-search:reindex --scheduled` |
| Storefront search returns nothing | Website index empty or ES down | ES cluster health; reindex website index |
| Prices wrong or stale | Combined price list not recalculated | Consumer backlog; price list schedule |
| Install times out | Long migrations | `--timeout=0` |
| "Could not determine platform version" | Postgres not ready | `docker compose ps`; wait for healthy |
| 500 after adding a custom field | Extended entity cache not rebuilt | `cache:clear --env=prod` |
| Assets/CSS missing | Assets not built | `oro:assets:build --env=prod` |
| Consumer memory climbing | Expected behaviour | Use `--time-limit` / `--memory-limit`; supervisord restart |
| Same message retried forever | Poison message | Redelivery limits; inspect the message body |
| Static analysis errors on generated entity methods | Extended entities live in `var/cache` | Warm cache before analysis; known limitation |

Deep-dive: UNVERIFIED: https://doc.oroinc.com/backend/architecture/tech-stack/search/troubleshooting/ · UNVERIFIED: https://doc.oroinc.com/backend/mq/rabbit-mq/troubleshooting/ · UNVERIFIED: https://doc.oroinc.com/cloud/maintenance/errors/

---

## 19. Important CLI Commands

> **PARTIAL.** The invocation form below is corrected and VERIFIED; many individual commands were
> never run and are `UNVERIFIED:` as written.
>
> **The container WORKDIR is `/`, not the app root — a relative `php bin/console` fails with**
> `Could not open input file: bin/console`. Always use the absolute path:
>
> ```
> docker compose exec php-fpm-app php /var/www/oro/bin/console <cmd>
> ```
>
> This bit the project's own validation harness (see `docs/troubleshooting.md` T2) and the rule in
> `CLAUDE.md` was corrected as a result. Note also that **`oro:message-queue:consume` and
> `oro:message-queue:transport:consume` are different commands** — the demo runs the latter. Matching
> only the former made a healthy stack report as broken.

```bash
# Install / update
php bin/console oro:install --env=prod --timeout=0 -n
php bin/console oro:platform:update --env=prod --force
php bin/console oro:platform:update --env=prod --force --schedule-search-reindexation
php bin/console oro:migration:load --force --env=prod

# Cache / assets
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod
php bin/console oro:assets:build --env=prod
php bin/console assets:install --env=prod

# Message queue
php bin/console oro:message-queue:consume -vvv
php bin/console oro:message-queue:consume --time-limit="+15 minutes"

# Search
php bin/console oro:search:reindex --scheduled
php bin/console oro:website-search:reindex --scheduled

# Cron
php bin/console oro:cron
php bin/console oro:cron:definitions:load

# Introspection
php bin/console debug:container
php bin/console debug:router
php bin/console debug:event-dispatcher
php bin/console oro:entity-config:debug
php bin/console list oro
```

---

## 20. Architecture Diagrams

> **`UNVERIFIED:`** — **no official Oro architecture diagram was located.** No diagram URL below was
> fetched successfully in this project. Conceptual diagrams derived from the running system are
> provided instead in `docs/02-architecture.md` (topology) and `docs/03-request-flow.md`
> (sync/async sequence).

**Official Oro diagrams (verified):**

| Diagram | URL | Page |
|---|---|---|
| OroCloud standard environment schema | UNVERIFIED: https://doc.oroinc.com/_images/standard_average_environment_schema.png | /cloud/architecture/ |
| Deployment / VM overview | UNVERIFIED: https://doc.oroinc.com/_images/15-environment-diagram.png | /user/solution-architect/cloud-infrastructure/ |
| Search index structure | UNVERIFIED: https://doc.oroinc.com/_images/op_search_diag.png | /backend/architecture/tech-stack/search/ |
| ORM (EAV) search data structure | UNVERIFIED: https://doc.oroinc.com/_images/op_structure_search_orm.png | same |
| Elasticsearch search data structure | UNVERIFIED: https://doc.oroinc.com/_images/op_structure_search_elastic.png | same |
| Search query object representation | UNVERIFIED: https://doc.oroinc.com/_images/op_structure_search_index_object_representation.png | same |

> **No official architecture diagram found; conceptual diagram provided for learning** — for: overall application architecture (section 5), storefront request flow (section 6), async data flow (section 7), messaging architecture (section 8), caching architecture (section 9), and network segmentation (section 13).

---

## 21. Official Documentation Links

> **Only two URLs in this table were fetched in this project, each with a capture log to prove it.**
> Every other row is prefixed `UNVERIFIED:` — the URL is written from prior knowledge, not from a
> successful fetch, and may 404 or redirect to a different version. Do not paste an `UNVERIFIED:`
> link into client-facing material without opening it first.
>
> Verified, with evidence:
> - `https://doc.oroinc.com/community/release-process/` — `logs/phase2-release-process-recheck-*`
> - `https://doc.oroinc.com/backend/setup/demo-environment/docker/` — `logs/phase2-demo-docker-page-*`
>
> Both showed banner **"7.0 (latest)"** — which is precisely how the version discrepancy in D1 was
> found: 7.0 documentation standing over a 6.1 distribution.

| Area | URL |
|---|---|
| Documentation home | UNVERIFIED: https://doc.oroinc.com/ |
| **Solution Architecture (start here for your role)** | UNVERIFIED: https://doc.oroinc.com/user/solution-architect/ |
| — Concepts | UNVERIFIED: https://doc.oroinc.com/user/solution-architect/concepts/ |
| — Integration Points | UNVERIFIED: https://doc.oroinc.com/user/solution-architect/integration-points/ |
| — Cloud and Infrastructure | UNVERIFIED: https://doc.oroinc.com/user/solution-architect/cloud-infrastructure/ |
| Backend Developer Guide | UNVERIFIED: https://doc.oroinc.com/backend/ |
| Application Architecture | UNVERIFIED: https://doc.oroinc.com/backend/architecture/ |
| Differences from plain Symfony | UNVERIFIED: https://doc.oroinc.com/backend/architecture/differences/ |
| System Requirements | UNVERIFIED: https://doc.oroinc.com/backend/setup/system-requirements/ |
| Performance Optimization | UNVERIFIED: https://doc.oroinc.com/backend/setup/system-requirements/performance-optimization/ |
| Docker demo install | https://doc.oroinc.com/backend/setup/demo-environment/docker/ |
| Docker + Symfony Server | UNVERIFIED: https://doc.oroinc.com/backend/setup/dev-environment/docker-and-symfony/ |
| Installation | UNVERIFIED: https://doc.oroinc.com/backend/setup/installation/ |
| Upgrade application | UNVERIFIED: https://doc.oroinc.com/backend/setup/upgrade-to-new-version/ |
| Deploy changes | UNVERIFIED: https://doc.oroinc.com/backend/setup/deploy-the-update/ |
| Message Queue | UNVERIFIED: https://doc.oroinc.com/backend/mq/ |
| Cron | UNVERIFIED: https://doc.oroinc.com/backend/cron/ |
| Search Index | UNVERIFIED: https://doc.oroinc.com/backend/architecture/tech-stack/search/ |
| Security | UNVERIFIED: https://doc.oroinc.com/backend/security/ |
| Integrations (dev) | UNVERIFIED: https://doc.oroinc.com/backend/integrations/ |
| Import / Export | UNVERIFIED: https://doc.oroinc.com/backend/integrations/import-export/ |
| Web Services API Guide | UNVERIFIED: https://doc.oroinc.com/api/ |
| API Developer Guide | UNVERIFIED: https://doc.oroinc.com/backend/api/ |
| Frontend Developer Guide | UNVERIFIED: https://doc.oroinc.com/frontend/ |
| Bundles & Components reference | UNVERIFIED: https://doc.oroinc.com/bundles/ |
| **OroCloud docs** | UNVERIFIED: https://doc.oroinc.com/cloud/ |
| Release process / versions | https://doc.oroinc.com/community/release-process/ |
| Backward compatibility promise | UNVERIFIED: https://doc.oroinc.com/community/backward-compatibility-promise/ |
| Glossary | UNVERIFIED: https://doc.oroinc.com/user/glossary/ |
| Source code | UNVERIFIED: https://github.com/oroinc |

---

## 22. Magento vs OroCommerce Mapping

Legend: **=** same concept · **≈** similar, different implementation · **≠** fundamentally different · **∅** no direct equivalent.

| Magento / Adobe Commerce | OroCommerce | | Architect's note |
|---|---|---|---|
| Module | Bundle | = | Symfony bundle; also a bundle-less option |
| `di.xml` DI | Symfony DI (YAML/attributes) | ≈ | Symfony-native; no `di.xml` preference/plugin model |
| Plugins (interceptors) | Decoration + events | ≠ | **No plugin/around-interceptor mechanism.** Decorate services or listen to events. This is the biggest LLD adjustment. |
| Observers | Event listeners/subscribers | = | |
| `bin/magento cron:run` | `oro:cron` | = | Single per-minute entry, same pattern |
| MySQL message queue / AMQP | MQ: DBAL (CE) / RabbitMQ (EE) | ≈ | Edition-gated in Oro; plan accordingly |
| Consumers | Consumer daemon + Job layer | ≈ | Oro adds unique jobs, progress, parent/child trees |
| Elasticsearch/OpenSearch | ORM (CE) / Elasticsearch (EE), **two indexes** | ≠ | Standard vs website index is a real architectural split with different ACL and reindex semantics |
| Redis cache | Redis via `RedisConfigBundle` — **ships in CE**, not wired in this demo | ≈ | |
| Varnish / built-in FPC | ∅ no equivalent full-page cache | ∅ | **Call this out early.** Oro's storefront performance strategy is layout cache + CDN + search index, not Varnish FPC. Do not promise Magento-style FPC behaviour. |
| Adminhtml | Back-office | = | |
| Layout XML + blocks | Layout engine (layout YAML + block tree) | ≈ | Similar philosophy, entirely different syntax and runtime |
| Website / Store / Store View | Website + Localization + Customer/Customer Group scopes | ≠ | Two orthogonal trees, not one hierarchy |
| — | Organization / Business Unit / User ownership tree | ∅ | Record-level ownership drives ACL access levels. No Magento equivalent. |
| ACL resources in `acl.xml` | ACL with access levels + field ACL + access rules | ≠ | Record-level, not just resource-level |
| EAV attributes | Extended entities + entity config | ≈ | Oro generates real classes into cache instead of EAV joins |
| Setup/data patches | Migrations + data fixtures | = | |
| Customer / Customer Group | Customer (company) / Customer User (person) / Customer Group | ≠ | **B2B model:** the buying organization is the customer; individuals are customer users with their own roles |
| REST + **GraphQL** API | JSON:API REST (management + storefront), OAuth2, OpenAPI | ≠ | **OroCommerce ships no GraphQL API.** Headless/PWA architectures that assume GraphQL must be redesigned. |
| Adobe Commerce Cloud | OroCloud | ≈ | Both managed. OroCloud is single-tenant GCP/OCI with cold DR; Oro operates it, you do not get infrastructure-as-code control |
| `setup:upgrade` | `oro:platform:update` | = | Note the reindex-control flags |
| Cart price rules | Promotions + expression language | ≈ | |
| B2B features via extensions | Native: RFQ, quotes, shopping lists, price lists, punchout | ≠ | These are core, not bolt-ons — the main reason to choose Oro |

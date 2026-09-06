# 00 — Environment Specification

**Phase 0 deliverable.** Written before anything on the system changes. Nothing in this document is
a report of what exists; it is a statement of what must be true when the environment is done, and
how each claim will be proven.

Audience: solution architect, Magento/Adobe Commerce background. Status of the system at the time of
writing: no Oro stack exists, `docker/` holds only `.env.template`.

---

## 1. Target

**Amended 2026-09-06 (Decision D1).** This section originally targeted 7.0 LTS. Phase 2 proved that
target unreachable by the chosen install path and the user selected option A — build against 6.1.6.
The evidence and the three options are in `specs/01-implementation-plan.md` §0; the summary is that
`oroinc/docker-demo` has no 7.0 branch and no tags, its `master` pins `ORO_IMAGE_TAG=6.1.6`, and
Docker Hub has never carried a 7.0 `orocommerce-application` image. The 7.0 documentation page
(banner confirmed) instructs a bare clone of that same `master`.

| Item | Value |
|---|---|
| Product | OroCommerce |
| Version | **6.1.6** — pinned by `docker-demo` `master:.env` as `ORO_IMAGE_TAG` |
| Edition | **Community Edition** |
| Runtime baseline | `ORO_BASELINE_VERSION=6.1-latest` |
| PostgreSQL | `ORO_DB_VERSION=17.2` (image-supplied) |
| CE patch window | **closed March 2026** — accepted; local, HTTP-only, non-production |
| Current LTS (not used) | 7.0, released March 2026, supported to March 2030 (2032 Extended) |
| Dev branch | 7.1 |
| Release cadence | One LTS every March |

The release-process facts were confirmed this session against
`https://doc.oroinc.com/community/release-process/`. They are kept because they are the reason the
discrepancy is a documentation-versus-artefact gap rather than a mistake in this spec: Oro publishes
7.0 documentation over a 6.1 demo distribution.

**Why 6.1.6 does not weaken the learning objectives.** CE is CE across the line: the message queue
runs on the DBAL transport into the `oro_message_queue` table, search runs on the ORM engine into
Postgres EAV, Elasticsearch / RabbitMQ / `oro/redis-config` remain EE-only, and the twelve-service
topology and request path are unchanged. Every architectural claim this repo sets out to observe is
observable on 6.1.6. What is lost is the patch window, and on a box with no TLS, no inbound exposure
and no real data, that is a stated acceptance rather than a risk to manage.

### Platform requirements (fetched this session, `doc.oroinc.com/backend/setup/system-requirements/`)

| Component | Requirement | Note |
|---|---|---|
| PHP | >= 8.5, CLI required | |
| PostgreSQL | >= 17.6 (CE) · >= 18.3 (EE) | EE requires a *newer* major than CE |
| Node.js | >= 24.11.0 < 25 | asset build |
| PNPM | >= 10.7.0 | |
| Supervisor | required | process control — this is what keeps consumers alive |
| Gotenberg | >= 8.5.x, optional | PDF generation |
| Redis | >= 8.4, **optional** | "more efficient application caching" |
| Elasticsearch | >= 9.2 < 10.0 | **Enterprise Edition only** |
| RabbitMQ | >= 4.2 | **Enterprise Edition only** |

**These are 7.0's requirements, not 6.1.6's.** The page carries the 7.0 banner and the
no-version-prefix URL resolves to the current LTS. They are retained as the forward reference; the
figures that actually govern this build come from the images themselves, and where the two are known
to diverge the observed value wins — upstream `.env` pins PostgreSQL **17.2**, not 17.6.
`UNVERIFIED:` the 6.1 system-requirements page was not fetched; PHP and Node figures for 6.1.6 are
unconfirmed and will be read off the running containers in Phase 4.

These are satisfied inside the official images; none of them is installed on the host. They are
recorded because they define what the containers are, and because the PHP figure contradicts this
repo's own learning plan — see §9.

---

## 2. Chosen install path, and why

**Primary: the official Docker demo**, `https://doc.oroinc.com/backend/setup/demo-environment/docker/`,
from `https://github.com/oroinc/docker-demo`.

Two runs, in this order:

1. **`docker compose up restore`** — restores a pre-built database image. Fast, and it is the right
   first move because the goal of Phases 4–6 is *architecture discovery on a working system*. Time
   spent watching an install is time not spent tracing a request.
2. **`docker compose up install`, on a second checkout** — the documentation's own words are that
   install "will require more time and resources". That cost is the point: `restore` hides the
   phase ordering (schema → migrations → fixtures → assets → search reindex → cache warmup), and
   that ordering is the most instructive artefact of the whole exercise. Learning-plan exercise 1.3.

**Rejected: Docker services + Symfony Server.** It is the only easy way to see Elasticsearch and
RabbitMQ locally, but both are EE components; standing them up next to a CE application would
demonstrate the services without demonstrating Oro using them. Deferred to a later stage, not
folded into this environment, where it would blur what CE actually does.

**Rejected: native install.** No architectural insight per unit of pain.

---

## 3. Expected components

Twelve services, verified this session from the upstream `compose.yaml`. The split below is the
single most important thing in this document: **four of them are designed to exit**, and a reviewer
who reads `Exited` as a failure will file bugs against correct behaviour.

### 3a. Long-running (must be `Up` when the environment is done)

| Service | Image | Role | Acceptance criterion | Check |
|---|---|---|---|---|
| `db` | `oroinc/pgsql:$ORO_PG_VER` | PostgreSQL. Application data, **the search index, and the message queue** | `docker compose exec -T db pg_isready` → `accepting connections` | 4 |
| `php-fpm-app` | `$ORO_IMAGE_BASE_RUNTIME` | PHP-FPM, the application itself | container healthy via `php-fpm-healthcheck`; `bin/console cache:pool:list` lists pools without error | 1, 10 |
| `web` | `$ORO_IMAGE_BASE_RUNTIME` | nginx. **The only service with a host port binding** (`published: 80`) | `curl -sI -H 'Host: oro.demo' http://127.0.0.1/` → 200/302 | 2 |
| `ws` | `$ORO_IMAGE_BASE_RUNTIME` | WebSocket server, back-office push notifications | container running | 1 |
| `consumer` | `$ORO_IMAGE_BASE_RUNTIME` | Message queue consumer | an `oro:message-queue:consume` process alive in the container | 6 |
| `cron` | `$ORO_IMAGE_BASE_RUNTIME` | Scheduled tasks | >= 1 row in `oro_cron_schedule` **and** an active cron log | 8 |
| `mail` | `mailhog/mailhog` | Mail catcher, reachable through nginx at `/mailcatcher` | container running | 1 |

### 3b. One-shot — **expected to show `Exited`**

| Service | Role | Why it exits |
|---|---|---|
| `volume-init` | Populates the shared application volume | Runs `true` after the copy; other services gate on `service_completed_successfully` |
| `web-init` | Writes the nginx configuration | Same — a setup step, not a daemon |
| `install` | Runs `install $ORO_INSTALL_OPTIONS` | The install lifecycle, then done |
| `restore` | Restores the pre-built database | The restore, then done |
| `application` | **Aggregator, not a service.** Command is `true`; it depends on `web`, `consumer` and `cron` | This is why `docker compose up application` brings up the whole stack: the dependency graph does the work, then the container exits |

`application` exiting immediately is correct and is the mechanism by which the documented start
command works. It is the single most likely thing to be misreported as a broken install.

### 3c. Startup ordering

The compose file expresses real ordering constraints, not just `depends_on` name lists:

```
db ──(service_healthy: pg_isready)──┐
volume-init ─(completed)────────────┼──> php-fpm-app ─(service_healthy: php-fpm-healthcheck)─┐
mail ───────────────────────────────┘                                                        │
                                                             ┌───────────────────────────────┤
                                        ws  <────────────────┤                               │
                                        consumer <───────────┤                               │
                                        cron <───────────────┘                               │
                        web-init ─(needs php-fpm-app healthy + ws started)──(completed)──> web
                                                                 (healthcheck: curl -If /)
                                        application ──(depends: web, consumer, cron)──> exits
```

Two conditions are doing the work: `service_healthy` (gated on a real healthcheck — `pg_isready`,
`php-fpm-healthcheck`, `curl -If`) and `service_completed_successfully` (gated on a one-shot
finishing). Magento's compose stacks typically gate on `service_started`, which is why they race on
a cold boot and this one does not.

---

## 4. Expected absences — architectural findings, not gaps

Community Edition. The following **must not** be present, and their absence is a documented outcome:

| Component | CE reality | Check |
|---|---|---|
| Elasticsearch | ORM search engine — the index lives in PostgreSQL EAV tables | 13 |
| RabbitMQ | DBAL transport — the queue lives in the `oro_message_queue` table | 12 |
| Redis (`oro/redis-config`) | Not bundled in CE; Symfony filesystem cache instead | 11 |

If any of these turns up in `docker compose config --services`, the environment is not what this
spec describes and the discrepancy gets investigated before anything else.

This is the architectural centre of the exercise. Both of Oro's async subsystems collapse into
PostgreSQL in CE, which makes `db` a far more loaded single point of failure than a Magento
architect's instinct suggests — it is MySQL, OpenSearch and RabbitMQ in one container.

---

## 5. Acceptance criteria → validation mapping

Every criterion above maps to a numbered check in `scripts/validate.sh`. The environment is
**accepted** when: checks 1–6 and 8–10 PASS, check 7 is manually confirmed, and checks 11–13 report
`EXPECTED-ABSENT`.

| # | Check | Pass condition |
|---|---|---|
| 1 | Long-running services up | all of `db php-fpm-app web ws consumer cron mail` running |
| 2 | Storefront | HTTP 200/301/302 |
| 3 | Back-office `/admin` | HTTP 200/301/302 to login |
| 4 | Database | `pg_isready` → accepting connections |
| 5 | Schema | `select count(*) from oro_user` >= 1 |
| 6 | Consumer alive | >= 1 `oro:message-queue:consume` process |
| 7 | Queue round trip | **manual** — product created in `/admin` reaches the storefront within a bounded time |
| 8 | Cron | >= 1 row in `oro_cron_schedule`, cron log active |
| 9 | Storefront search | search endpoint answers 200 with a non-trivial body |
| 10 | Cache pools | `cache:pool:list` lists pools, no error |
| 11–13 | Redis / RabbitMQ / Elasticsearch | `EXPECTED-ABSENT (Community Edition)` |

**Check 6 is not a nice-to-have.** An Oro install whose consumer is not running is *broken*, not
partially working: price recalculation, search indexing and visibility resolution all stop, while
the storefront keeps serving stale data and looks healthy. Check 7 is the experiment that proves it
— run it once with the consumer stopped and once with it running.

**Check 9 is HTTP-level only.** It asserts the endpoint answers with a non-trivial body; it does not
assert relevance or result counts. Stated here so the final report does not overclaim.

---

## 6. Access

- Storefront: `http://oro.demo/`
- Back-office: `http://oro.demo/admin`
- Mail catcher: `http://oro.demo/mailcatcher`

`oro.demo` is the default `ORO_APP_DOMAIN` and requires the `/etc/hosts` entry (Phase 3, needs
explicit approval — it edits a system file).

The demo documentation publishes default back-office and storefront credentials. **Those values are
not reproduced in this repo**, per the secrets rule; they are on the demo page, and the variable is
`ORO_APP_DOMAIN`-scoped configuration, not a repo artefact.

---

## 7. Out of scope — explicit

- **No TLS.** HTTP only. The host's 443 is held by an unrelated stack.
- **No production hardening.** No security headers, no WAF, no firewall changes, no resource limits.
- **No Enterprise Edition components.** No Elasticsearch, no RabbitMQ, no Redis cache config.
- **No multi-node.** Single host, single instance of every service. No load balancer, no HA, no
  shared object storage.
- **No performance tuning or benchmarking.** Sizing is out of scope; consumer-scaling experiments
  belong to a later stage.
- **No custom bundles, entities, or code.** This environment is observed, not extended.
- **No changes to the co-resident `docker_magento` stack beyond `stop`/`start`.** Its volumes and
  data are never touched. `docker compose down -v` is not used anywhere in this project.
- **No host package installation.** Docker and Compose v2 are already present.

---

## 8. Risks accepted at specification time

| Risk | Detail | Mitigation |
|---|---|---|
| RAM | 15 GiB total, ~7.3 GiB free with the Magento stack up; Oro peaks ~5 GiB during install and reindex | `scripts/preflight.sh` gates every bring-up; `magento-stack.sh stop` frees the rest, reversibly |
| Image pull size | The Oro images are large and unmeasured at this point | 328 GiB free on `/`; measured in Phase 3 |
| `restore` hides the install lifecycle | The fast path skips what is most worth watching | Second checkout runs `install` (§2) |

---

## 9. Discrepancy found while writing this spec

`docs/oro-commerce-learning-plan.md` states **PHP >= 8.4**. The system-requirements page fetched
this session states **PHP >= 8.5**, and adds PostgreSQL >= 17.6 (CE) / >= 18.3 (EE), Node >= 24.11.0,
and PNPM >= 10.7.0 — none of which the learning plan records.

Not a blocker: the requirement is satisfied inside the official image either way, and nothing in
this environment installs PHP on the host. Recorded because the learning plan is a study artefact
that will be read later as if it were true. Correcting it belongs to Phase 6, not here.

---

## 10. `UNVERIFIED:` items

- `UNVERIFIED:` **version banner** on `doc.oroinc.com/backend/setup/system-requirements/` and
  `.../demo-environment/docker/`. Both pages were fetched successfully this session and their
  content is used above, but the fetched extract did not restate the banner, so the pages are not
  *proven* to be the 7.0 view. The no-version-prefix URL convention resolves to the current LTS,
  and the figures (PHP 8.5, PG 17.6) are consistent with 7.0 rather than an older line — but that
  is inference, not confirmation. Re-confirm when either page is opened again.
- `UNVERIFIED:` **image tags and digests.** `ORO_IMAGE`, `ORO_IMAGE_TAG`, `ORO_BASELINE_VERSION` and
  `ORO_PG_VER` resolve from upstream defaults not yet read. Recorded in Phase 3 (task 3.2) and
  Phase 5.
- `UNVERIFIED:` **`ORO_INSTALL_OPTIONS` contents** — the `install` service passes them; the value is
  read at Phase 3.

Everything else in this document was fetched or executed in the session that wrote it.

# 04 — Observed components, mapped to Magento / Adobe Commerce

Written for a reader who knows Magento well and Oro not at all. Every Oro-side statement is from the
running 6.1.6 CE stack, not from documentation. Magento-side statements are from the reader's own
domain and are not re-derived here.

**Marking:** `same` · `similar` · `different` · `no equivalent`. The last is used freely — forcing an
equivalence is the main way this kind of document misleads. Where the honest answer is "these look
alike and are not", it says so.

---

## 1. Infrastructure and topology

| Oro (observed) | Magento | Mark | Notes |
|---|---|---|---|
| `web` — nginx, only host binding `80→80` | nginx / Apache | **same** | No behavioural difference worth noting |
| `php-fpm-app` — php-fpm, PHP 8.4.14 | php-fpm | **same** | — |
| `db` — PostgreSQL 17.2 | MySQL / MariaDB | **different** | Not a swap. Oro is Postgres-first; the search index (§3) relies on Postgres EAV and the queue on Postgres row-locking |
| `mail` — MailHog | Mailhog / Mailcatcher in dev stacks | **same** | — |
| `ws` — long-lived WebSocket PHP process | **no equivalent** | **no equivalent** | Magento has no first-party persistent socket tier. Nearest analogue is a bolt-on for admin notifications, not a shipped component |
| `cron` — 38 definitions in-container | `bin/magento cron:run` via system crontab | **similar** | Same idea, but Oro's definitions are application-registered and enumerable (`38 definitions` observed), not crontab lines |
| `consumer` — `oro:message-queue:transport:consume` | `bin/magento queue:consumers:start` | **similar** | Both are supervised PHP workers. Difference is what they talk to — see §2 |
| Reverse proxy / FPC tier | Varnish | **no equivalent in this stack** | Nothing. Every storefront hit executes PHP; response is `Cache-Control: private`. Not an Oro limitation per se, but the demo topology has no proxy at all |
| One `default` bridge network, no tier segmentation | typically the same in dev compose | **same** | — |
| `oroinc/runtime:6.1-latest` serving **six** services by `command` | one PHP image reused across php-fpm/cron/consumer | **similar** | Oro goes further: `web` (nginx) is *also* this image. Application code is not in it at all |
| `oro_app` named volume holds the application code | code baked into the image, or bind-mounted in dev | **different** | Code arrives via `volume-init` from a *separate* image. Runtime and application are versioned independently — `6.1-latest` vs `6.1.6` |

**The one to internalise:** in Magento the image usually *is* the application. Here the runtime image
and the application image are different artefacts joined by a volume at boot.

---

## 2. Message queue

| Oro (observed) | Magento | Mark |
|---|---|---|
| `ORO_MQ_DSN=dbal:` → table `oro_message_queue` | MySQL `queue_message` tables (default) | **similar** |
| RabbitMQ | RabbitMQ (Adobe Commerce, optional but standard) | **different** — EE-only in Oro |

Both products default to a database-backed queue and both offer AMQP for the paid tier, so the shape
is familiar. Two differences matter operationally:

**The DBAL queue is genuinely just a table, and it is visible.** `select count(*) from
oro_message_queue` is the entire monitoring interface, and it is exact. The restored demo database
arrived carrying 50 queued messages — the dump carried queue state the way it carries any other
rows, which has no clean Magento analogue because you rarely restore a Magento DB and inherit a live
backlog you can watch drain.

**Consumer failure is equally silent in both, but Oro gives you less.** `consumer` has **no
healthcheck** in this compose file, and neither do `cron` or `ws`. Measured: with the consumer
stopped, the storefront returned 200 throughout, every healthcheck passed, and depth climbed 1 → 2
while nothing drained. Restarting drained it in **under 8 seconds**.

**`oro:search:reindex` returns "finished successfully" after merely enqueuing.** The Magento habit
of treating a reindex command's exit code as completion transfers badly. The trustworthy assertion
is queue depth returning to its prior value.

---

## 3. Search

| Oro (observed) | Magento | Mark |
|---|---|---|
| `ORO_SEARCH_ENGINE_DSN=orm:?prefix=oro_search` — Postgres EAV, back office | MySQL search (removed in 2.4) | **similar in spirit, different in life expectancy** |
| `ORO_WEBSITE_SEARCH_ENGINE_DSN=orm:?prefix=oro_website_search` — **a second index**, storefront | — | **no equivalent** |
| Elasticsearch | Elasticsearch / OpenSearch, **mandatory** since 2.4 | **different** — EE-only in Oro |

This is the sharpest divergence in the document.

**Magento 2.4 made Elasticsearch mandatory and deleted the MySQL engine.** Oro CE ships the
database-backed engine as a supported, permanent configuration, and puts Elasticsearch behind the
Enterprise licence. A Magento architect's instinct — "no Elasticsearch means someone misconfigured
this" — is wrong here. Validation checks 11–13 record `EXPECTED-ABSENT` for exactly this reason,
proven from `compose config --services` rather than from an unanswered port.

**Two indices, not one, is the concept with no Magento counterpart.** `oro_search` serves the back
office and `oro_website_search` serves the storefront. They are separate tables with separate
lifecycles: reindexing one does not touch the other. In Magento, admin grids and storefront search
are different query paths over shared index data. Here they are different indices. Any capacity or
reindex-duration estimate that treats Oro search as a single index will be wrong by roughly a
factor of two.

---

## 4. Cache and sessions

| Oro (observed) | Magento | Mark |
|---|---|---|
| Symfony filesystem cache in the **shared `cache` volume** | `var/cache` filesystem backend | **similar** |
| Redis | Redis, near-universal for cache + session | **similar — available, just not wired here** (see correction below) |
| `ORO_SESSION_DSN=native:` — PHP handler, local files | Redis or DB sessions, standard | **different** |
| `cache:pool:list` → `cache.app`, `cache.system`, `cache.validator`, `cache.serializer`, `oro.cache.serializer_pool` | `cache:clean` / cache types grid | **similar** |

**How CE gets away without Redis, and what it costs.** `php-fpm-app`, `consumer` and `cron` all
mount the same `cache` volume at `/var/www/oro/var/cache`. A cache entry invalidated by the consumer
is therefore visible to php-fpm — coherence via shared filesystem rather than a shared cache server.
It works precisely because every writer is on one host.

That is also the ceiling *as configured*. Scaling the web tier out requires a shared cache backend
and a shared session store (`native:` sessions are local files).

**Correction (2026-09-06).** An earlier draft listed Redis among the reasons to buy EE. **That was
wrong**, and it materially weakened the argument it was making. `RedisConfigBundle` ships in CE
`oro/platform`, auto-registers via `bundles.yml`, and is in this install's compiled kernel;
`predis` and the `redis` PHP extension are installed. The demo simply declares no `redis` service
and sets no DSN. A CE deployment can use Redis for cache and sessions.

The EE argument therefore rests on **RabbitMQ and Elasticsearch**, both of which are genuinely
absent from the CE codebase — no AMQP package or extension, no Elasticsearch client or bundle, only
`Transport/Dbal` in the message-queue tree. Those two are edition boundaries. Redis is not.

---

## 5. Application concepts

These are where "no equivalent" earns its place.

| Oro | Magento | Mark |
|---|---|---|
| **Organization / Business Unit / User ownership tree** | Website / Store / Store View scope | **no equivalent** | 
| **Workflows and Operations** (configurable state machines and UI actions) | — | **no equivalent** |
| **Customer / Customer User** split (a company, and people within it) | Customer, one flat entity | **different** |
| Entity management / custom fields at runtime | EAV plus code-defined attributes | **different** |
| Twig-based layout with layout updates | XML layout + blocks | **different** |
| API Platform-style REST/JSON:API processor chain | Webapi with service contracts | **different** |
| Doctrine ORM entities | Model / ResourceModel / Collection | **different** |
| Symfony DI container, bundles | Magento DI, modules, plugins/interceptors | **similar** |

**Ownership tree — the one that breaks the analogy hardest.** Magento's scope hierarchy answers
"which storefront is this configuration for". Oro's ownership tree answers "**who owns this record
and who may see it**" — a row-level access-control structure that follows the organizational chart.
There is no Magento structure that does this; multi-website scoping is not a permission model. Any
attempt to map Business Unit onto Store View will produce a design that fails the first time two
sales teams must not see each other's quotes.

**Workflows and Operations** are runtime-configurable state machines over entities, with UI buttons
bound to transitions. Magento has no first-party equivalent — the closest is writing a module. This
is B2B's core requirement (quote approval, order approval chains) and a large part of why Oro exists
as a separate product rather than a Magento theme.

**Customer vs Customer User** is not a naming difference. A `Customer` is a company account with
a price list, payment terms and an ownership position in the tree; a `Customer User` is a person
inside it with a role. The demo database's 53 `oro_user` rows are back-office users, a separate
table from customer users entirely.

**API processor chain** — Oro's REST layer is a pipeline of processors per action, not a service
contract per operation. Reasoning about it in service-contract terms is an unproductive path; it is
closer to a middleware stack.

---

## 6. Migration-relevant summary

If the question is "what transfers and what does not":

**Transfers cleanly.** nginx/php-fpm operational habits, compose ergonomics, worker supervision
concepts, the general shape of a DB-backed queue, Symfony DI if you know Magento DI.

**Transfers with a warning.**
- Reindexing: the command's success is *enqueue* success. Assert on queue depth.
- Cron: definitions are application-registered and enumerable, not crontab lines.
- Consumers: same idea, but nothing in the stack healthchecks them.

**Does not transfer.**
- MySQL habits — Postgres is load-bearing here, not a substitution.
- "Elasticsearch is mandatory" — false in Oro CE, and its absence is correct.
- "Redis for cache and sessions" — available in CE (bundle ships and is kernel-registered), but **not
  wired in this demo**, which falls back to a shared filesystem cache volume. Configure it before
  assuming it is there.
- One search index — there are two, with independent lifecycles.
- Scope-as-permissions — the ownership tree is a different axis from Magento's scope hierarchy, and
  conflating them is the most expensive mistake available in this list.

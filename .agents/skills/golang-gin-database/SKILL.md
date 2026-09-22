---
name: golang-gin-database
description: Integrate PostgreSQL databases with Go Gin APIs using GORM or sqlx. Covers repository pattern, connection retry with backoff, cursor keyset pagination, context-based transactions, TLS sslmode, migrations, and dependency injection. Use when adding database support, creating models, writing queries, implementing repositories, setting up migrations, or wiring database layers into a Go project. Also activate when the user mentions GORM, sqlx, database connection, SQL queries, repository pattern, or database migrations in a Go context.
---

# golang-gin-database

Integrate PostgreSQL-backed data access into a Go service using repository-oriented boundaries. Although the original community skill is framed around Gin, the patterns here are still applicable to layered Go services that need GORM or sqlx.

## When To Use

- adding PostgreSQL database support
- implementing repository interfaces and concrete data-layer implementations
- writing GORM or sqlx queries
- setting up connection pooling and startup retry
- adding migrations
- wiring repositories into service handlers or usecases
- implementing context-propagating transactions
- working on GORM-related changes

## Repository Boundary

Define repository interfaces in the consumer-facing domain or biz layer. Keep ORM-specific details in the data layer.

```go
type UserRepository interface {
	Create(ctx context.Context, user *User) error
	GetByID(ctx context.Context, id string) (*User, error)
	GetByEmail(ctx context.Context, email string) (*User, error)
	List(ctx context.Context, opts ListOptions) ([]User, int64, error)
	Update(ctx context.Context, user *User) error
	Delete(ctx context.Context, id string) error
}
```

Guidelines:

- domain or biz code should not import `gorm.io/gorm`
- data-layer implementations may use GORM or sqlx
- service or usecase code depends on the interface, not the ORM

## Database Connection Setup

Prefer an explicit constructor for DB initialization and pooling.

```go
type Config struct {
	DSN             string
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
}
```

Recommendations:

- validate connectivity during startup
- configure pool sizes explicitly
- wrap connection errors with `%w`
- use startup retry with exponential backoff when the database may not yet be ready

For production PostgreSQL, prefer secure TLS settings and avoid `sslmode=disable`.

## GORM Repository Pattern

Keep GORM models and persistence concerns in the data layer.

```go
type gormUserRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) domain.UserRepository {
	return &gormUserRepository{db: db}
}
```

Guidelines:

- call `WithContext(ctx)` on queries
- map `gorm.ErrRecordNotFound` to domain-level not-found errors
- keep transport tags out of domain entities
- isolate conversion between DB models and domain models

For deeper guidance, load [gorm-patterns.md](references/gorm-patterns.md).

## sqlx Repository Pattern

Use sqlx when you want more direct SQL control while preserving the same repository boundary.

Guidelines:

- use `GetContext` and `SelectContext`
- keep query text close to repository methods
- map `sql.ErrNoRows` to domain-level not-found errors
- use `sqlx.In` and rebind helpers for dynamic `IN` queries

For deeper guidance, load [sqlx-patterns.md](references/sqlx-patterns.md).

## Transaction Pattern

Let the service or usecase orchestrate the transaction. Repositories should consume a transaction from context or from an injected transaction boundary, rather than deciding transactional scope themselves.

```go
type txKey struct{}

func WithTx(ctx context.Context, tx *gorm.DB) context.Context {
	return context.WithValue(ctx, txKey{}, tx)
}
```

Guidelines:

- start transactions in service or usecase code
- pass transactional state downward
- keep repository methods transaction-aware but not transaction-owning

## Pagination

Prefer keyset or cursor pagination over large-offset pagination on growing tables.

Use offset pagination only when the data volume is small or the access pattern is administrative and infrequent.

## Dependency Injection

Wire dependencies explicitly:

- config -> db
- db -> repository
- repository -> usecase or service
- usecase or service -> handler or transport layer

Nothing should create its own database dependency implicitly.

## Migrations

Keep migrations as an explicit operational concern. Use tooling such as `golang-migrate` and separate schema rollout strategy from application request handling.

For deeper guidance, load [migrations.md](references/migrations.md).

## Official Docs

When the task is library-specific, consult current documentation for:

- GORM
- sqlx
- PostgreSQL

In this environment, use Context7 for current library documentation before relying on memory.

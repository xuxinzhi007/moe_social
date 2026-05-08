# GORM Patterns

Load this reference when the task is specifically about GORM usage.

Focus areas:

- model definition and mapping boundaries
- CRUD methods inside repository implementations
- `WithContext(ctx)` propagation
- soft deletes
- preloading associations
- scopes for reusable query fragments
- raw SQL where ORM composition becomes awkward
- batch operations
- transaction participation
- connection pooling
- PostgreSQL-specific concerns

Guidelines:

- keep GORM types out of domain and biz layers
- convert `gorm.ErrRecordNotFound` into domain-level errors
- isolate ORM models from API request and response structs
- prefer repository methods over scattering ad hoc queries across the codebase

When the user asks for syntax or API specifics, fetch current GORM docs with Context7.

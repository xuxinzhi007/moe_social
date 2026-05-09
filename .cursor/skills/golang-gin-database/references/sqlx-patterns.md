# sqlx Patterns

Load this reference when the task is specifically about sqlx.

Focus areas:

- connection setup and pool tuning
- struct scanning
- `GetContext` and `SelectContext`
- `NamedExec`
- safe dynamic SQL
- `sqlx.In`
- null handling
- transaction usage

Guidelines:

- keep SQL in repository implementations
- pass `context.Context` through every query
- map `sql.ErrNoRows` into domain-level errors
- prefer explicit query shape over over-abstracted SQL builders

When the user asks for syntax or API specifics, fetch current sqlx docs with Context7.

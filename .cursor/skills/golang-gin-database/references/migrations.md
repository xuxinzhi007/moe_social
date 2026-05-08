# Migrations

Load this reference when the task involves schema evolution or operational rollout.

Focus areas:

- `golang-migrate` CLI or library usage
- file naming conventions
- forward-only and rollback strategy
- zero-downtime migration planning
- startup migration versus CI/CD migration execution
- seed data boundaries

Guidelines:

- do not hide schema changes inside request handling paths
- separate migration execution from normal service startup when operationally necessary
- review locking and backward-compatibility risk before applying destructive changes

When the user asks for command syntax or library behavior, fetch current migration tool docs with Context7.

# db-migrator

Dead simple tool for managing database schema migrations.

## Configuration

See header in `migrator.sh`.

## Instalation

`db-migrator` is self-contained script, so you only need to copy `migrator.sh`
and version it together with your application.

## Can't you support some higher level abstractions?

Short answer: no.

If you need higher level abstractions I encourage you to use more sophisticated
tools like [SQLAlchemy](https://www.sqlalchemy.org/),
[Liquibase](https://www.liquibase.org/) or [Flyway](https://flywaydb.org/).
`db-migrator` is supposed to be as simple as possible and let you mess directly
with SQL. It's solely your responsibility to keep you scripts manageable and
idempotent - `db-migrator` provides you only the lightweight framework for
executing them.

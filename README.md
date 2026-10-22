# Local APEX

[![Installation smoke test](https://github.com/silas229/local-apex/actions/workflows/installation-smoke-test.yml/badge.svg)](https://github.com/silas229/local-apex/actions/workflows/installation-smoke-test.yml)

This Compose project runs Oracle Database Free,
ORDS, APEX, and Mailpit locally. The first installation can take 20-30 minutes.

## Prerequisites

- Docker Engine with the Docker Compose plugin
- Host resources for local development: at least 4 GiB of memory available to Docker, and 35 GB of free disk space
- An Oracle account with access to the Oracle Container Registry
- The APEX 26.2 installation archive

This project is currently configured for APEX 26.2.0. Other releases are
listed in the [Oracle APEX archive downloads](https://www.oracle.com/tools/downloads/apex-all-archives-downloads/),
but are not drop-in replacements: the German translation startup hook uses
version-specific scripts and schema names.

## 1. Sign in to Oracle Container Registry

The Oracle Database Free and ORDS images are hosted in Oracle Container
Registry. An Oracle account is required to access them.

1. Sign in to or create an Oracle account.
2. Open the [Oracle Container Registry image catalog](https://container-registry.oracle.com/ords/f?p=113:1:118372291051041:::::#report_opensource).
3. Review and accept the applicable terms for the Oracle Database Free and
	ORDS images.
4. While signed in, create an authentication token on the
	[Oracle Container Registry Auth Token page](https://container-registry.oracle.com/ords/f?p=113:11:118372291051041:::::).
5. Log in to the registry:

	```sh
	docker login container-registry.oracle.com
	```

	Enter your Oracle account username/email when prompted. Use the authentication
	token as the password, not your Oracle account password. Do not put the
	token in this repository or in a command-line argument.

6. From this directory, pull the Oracle images:

	```sh
	docker compose pull oraclefree ords
	```

## 2. Install APEX files

Download the official [APEX 26.2 archive](https://download.oracle.com/otn_software/apex/apex_26.2.zip),
then verify its SHA256 checksum before extracting it:

```text
50e27e5451435aa79205acbcd22ee44353d36d96768634695eb01b93fa02d782
```

Extract the archive so that files such as `apexins.sql` are directly under
`setup/apex` (for example, `setup/apex/apexins.sql`). The directory must be
readable and writable by the ORDS user (UID/GID 54321), because the Oracle
installer writes logs there. Compose intentionally does not create this bind
mount source directory automatically.

## 3. Configure passwords

Review `setup/ords.env` and set the database, service, and APEX administrator
passwords required by this stack. Keep this file local and never commit it; it
contains secrets. The checked-in `setup/ords.env.example` contains example-only
passwords; copy it to `setup/ords.env` for a local test, then replace those
values. The initial APEX administrator is `ADMIN` in the `INTERNAL` workspace.
Its initial password is the value of `APEX_ADMIN_PASSWORD`.

The German APEX translation is enabled by default. To skip its installation,
add this setting to `setup/ords.env`:

```env
APEX_INSTALL_GERMAN=false
```
The setting also accepts `true` (the default), `1`, `yes`, `0`, and `no`.
Disabling the import does not remove German translations already installed in
the database. After changing this setting on a running stack, recreate ORDS to
apply the updated environment:

```sh
docker compose up -d --force-recreate ords
```

## 4. Start the stack

From this directory, run:

```sh
docker compose up -d
```

Useful URLs:

- APEX: <http://localhost:8080/ords/>
- APEX administration: <http://localhost:8080/ords/apex_admin>
- Database service: `localhost:1521/FREEPDB1`
- SQL Developer Web: <http://localhost:8080/ords/sql-developer>
- Mailpit inbox: <http://localhost:8025>

Check startup and installation progress:

```sh
docker compose ps
docker compose logs -f ords
docker compose exec ords tail -40 /tmp/install_logs/apex_install.log
```

ORDS waits for Oracle Database to become healthy, installs or recognizes APEX
from `setup/apex` in `FREEPDB1`, and serves APEX static files under `/i/`. The
startup hook installs the German translation from the official
`/opt/oracle/apex/builder/de/load_de.sql` script. It verifies APEX schema
`APEX_260200` and all 16 German applications; completed translations persist
in the database volume. The installation log is available at:

```sh
docker compose exec ords tail -40 /etc/ords/config/apex-de-26.2.0-install.log
```

ORDS is reported healthy after the German translation step (if enabled), SMTP
setup, and HTTP port check are complete. When installed, select **Deutsch** on
the APEX sign-in page to use the German interface. This does not translate your
own applications.

## Mailpit and SMTP

Mailpit captures test email locally and does not deliver messages to the
internet. Its web UI is bound to the loopback interface at
<http://localhost:8025>. The SMTP port is not published on the host; services
in the Compose network reach it at `mailpit:1025`.

On every ORDS start, `setup/ords-entrypoint.d/30-apex-smtp.sh` configures the
APEX instance with these settings:

| Setting | Value |
|---|---|
| SMTP host | `mailpit` |
| SMTP port | `1025` |
| TLS | Disabled |
| Authentication | None |
| Instance sender | `apex@example.test` |

The hook grants the current APEX schema network access to `mailpit:1025` and
validates the SMTP connection. Manual changes to these instance parameters
are overwritten on the next ORDS start. Applications can pass their own
sender address to `APEX_MAIL.SEND`. Sending email requires an APEX workspace
context and a subsequent `COMMIT`.

Mailpit retains its data in a Docker volume and is configured to keep at most
the latest 1,000 messages.

## GitHub Actions installation test

The installation smoke test runs on pushes, same-repository pull requests,
and manual dispatch. Add these repository Actions secrets before running it:

- `ORACLE_REGISTRY_USERNAME`: Oracle account username or email
- `ORACLE_REGISTRY_AUTH_TOKEN`: token created in Oracle Container Registry

The workflow uses these secrets only for registry login. It downloads and
verifies APEX, creates `setup/ords.env` from the example file, starts the full
stack, waits for all services to become healthy, and checks the ORDS endpoint.
Fork pull requests skip this job because GitHub does not provide repository
secrets to them.

## License

Oracle Database Free, ORDS, and APEX are subject to the applicable
[Oracle Free Use Terms](https://www.oracle.com/downloads/licenses/oracle-free-license.html)
and any separate notices in the distributions; accept the Oracle Container
Registry terms before pulling the images.

Database Free is limited to 2 CPU threads, 2 GB of database RAM, and 12 GB of user data.
Oracle allows deployment in production environments, but Database Free is unsupported and
receives no patches, including security patches. Redistribution of Oracle programs is
subject to the license conditions.

Mailpit is licensed under the [MIT License](https://github.com/axllent/mailpit/blob/develop/LICENSE).
Retain its copyright and license notice. Review the full terms for your intended use

This summary is not legal advice.

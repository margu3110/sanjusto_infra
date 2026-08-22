# San Justo Infrastructure

Infrastructure and server configuration for the San Justo LAMP environment.

This repository contains reproducible configuration and installation scripts for services running on the San Justo application server.

The initial scope of this repository is the automated backup of the `sanjustodb` MySQL database running in Docker.

## Repository structure

```text
sanjusto_infra/
├── README.md
├── backup/
│   ├── backup-sanjustodb
│   ├── sanjustodb-backup.service
│   └── sanjustodb-backup.timer
└── scripts/
    └── install-mysql-backup.sh


backup/

Contains the actual backup configuration:

backup-sanjustodb — MySQL backup script.
sanjustodb-backup.service — systemd service used to execute the backup.
sanjustodb-backup.timer — systemd timer that schedules the backup.
scripts/

Contains scripts used to install and configure the infrastructure.

install-mysql-backup.sh — installs and configures the MySQL backup infrastructure on the server.
MySQL Backup
Overview

The San Justo application uses MySQL 5.7 running in a Docker container:

Container: sanjusto_mysql
Database:  sanjustodb

The backup process uses mysqldump from inside the MySQL container and stores compressed SQL dumps on the server.

sanjusto_mysql
      │
      │ mysqldump
      ▼
   SQL dump
      │
      │ gzip
      ▼
/backups/mysql/
      │
      └── sanjustodb-YYYYMMDD-HHMMSS.sql.gz
Backup location

Backups are stored in:

/backups/mysql

The directory is owned by:

root:backup-readers

with permissions:

750

Backup files are created with:

root:backup-readers

and permissions:

640

This prevents unauthorized users from reading the database dumps.

Administrators who need to read backups can be added to the backup-readers group.

For example:

sudo usermod -aG backup-readers <username>

The user must log out and log back in before the new group membership becomes active.

Backup configuration
Backup script

The installed backup script is:

/usr/local/sbin/backup-sanjustodb

The script:

Verifies that the MySQL container is running.
Executes mysqldump.
Uses --single-transaction.
Includes stored routines.
Includes triggers.
Includes events.
Compresses the dump using gzip.
Verifies gzip integrity.
Creates a timestamped backup file.
Applies the configured retention policy.

The backup does not contain database credentials in this repository.

The MySQL root password is obtained from the MYSQL_ROOT_PASSWORD environment variable already configured inside the MySQL container.

Backup options

The dump uses:

--single-transaction
--routines
--triggers
--events

--single-transaction allows a consistent dump of transactional tables without locking the tables for the duration of the backup.

Retention

The current retention policy is:

14 days

Older backup files are automatically removed by the backup script.

Backup files follow this naming convention:

sanjustodb-YYYYMMDD-HHMMSS.sql.gz

Example:

sanjustodb-20260822-051612.sql.gz
Scheduling

The backup is managed by systemd.

Service:

sanjustodb-backup.service

Timer:

sanjustodb-backup.timer

The timer is configured to run once per day at approximately:

02:00

Server timezone:

America/Argentina/Buenos_Aires

A randomized delay of up to five minutes is configured to avoid depending on an exact execution second.

The timer is also configured with:

Persistent=true

This allows systemd to run a missed backup after the server comes back online.

Check timer status
systemctl status sanjustodb-backup.timer

or:

systemctl list-timers sanjustodb-backup.timer

Example:

NEXT                        LEFT   LAST   PASSED UNIT
Sun 2026-08-23 02:03:56 -03 ...    -      -      sanjustodb-backup.timer
Manual backup

The backup can be executed manually through systemd:

sudo systemctl start sanjustodb-backup.service

Check the service status:

sudo systemctl status sanjustodb-backup.service

View recent logs:

sudo journalctl -u sanjustodb-backup.service -n 50 --no-pager
Backup verification

Each backup is gzip-compressed.

Test the integrity of a backup:

gzip -t /backups/mysql/sanjustodb-YYYYMMDD-HHMMSS.sql.gz

A successful command produces no output and returns exit status 0.

Inspect the end of the SQL dump:

zcat /backups/mysql/sanjustodb-YYYYMMDD-HHMMSS.sql.gz | tail -20

A valid mysqldump should contain a footer similar to:

-- Dump completed on YYYY-MM-DD HH:MM:SS

List available backups:

ls -lh /backups/mysql/
Installation

The backup infrastructure can be installed using:

sudo ./scripts/install-mysql-backup.sh

The installer is designed to be idempotent.

Running it multiple times should result in the same configuration.

Prerequisites

The target server must have:

Ubuntu/Linux with systemd.
Docker.
A running Docker container named sanjusto_mysql.
A /backups directory.
A MySQL database named sanjustodb.

The installer does not create or configure the MySQL Docker container.

It only installs the backup infrastructure.

What the installer configures

The installer:

Verifies Docker.
Verifies the sanjusto_mysql container.
Verifies /backups.
Creates the backup-readers system group if necessary.
Creates /backups/mysql.
Configures ownership and permissions.
Installs the backup script.
Installs the systemd service.
Installs the systemd timer.
Reloads systemd.
Enables the backup timer.
Starts the backup timer.

The installer does not execute a database backup.

A backup can be tested separately with:

sudo systemctl start sanjustodb-backup.service
Troubleshooting
Check the Docker container
docker ps --filter name=sanjusto_mysql

The container should be running.

Check the backup service
sudo systemctl status sanjustodb-backup.service
Check service logs
sudo journalctl -u sanjustodb-backup.service --no-pager

For the most recent execution:

sudo journalctl -u sanjustodb-backup.service -n 50 --no-pager
Check the timer
systemctl status sanjustodb-backup.timer

and:

systemctl list-timers sanjustodb-backup.timer
Check backup permissions
ls -ld /backups/mysql
ls -lh /backups/mysql

Expected directory ownership:

root backup-readers

Expected backup file permissions:

-rw-r-----
Restore

A backup can be restored using zcat and the MySQL client.

Example:

zcat /backups/mysql/sanjustodb-YYYYMMDD-HHMMSS.sql.gz \
  | docker exec -i sanjusto_mysql \
      mysql -uroot -p sanjustodb

Do not execute a restore against the production database unless the consequences are understood.

A dedicated test MySQL 5.7 container should be used to validate backups before relying on them for disaster recovery.

A documented and tested restore procedure is part of the planned backup improvements.

Infrastructure roadmap

The repository will progressively contain additional San Justo server infrastructure and configuration.

Planned improvements include:

 Automated MySQL backup script.
 Compressed backup files.
 Backup integrity verification.
 Retention policy.
 systemd backup service.
 systemd backup timer.
 Reproducible backup installation script.
 Idempotent backup configuration.
 Test MySQL restore procedure.
 Off-server backup storage.
 Backup monitoring/alerting.
 Additional LAMP server configuration.
 Server recovery documentation.
Design principles

This repository follows a few basic principles:

Infrastructure should be reproducible

Server configuration should be represented in Git whenever practical.

Scripts should be idempotent

Running an installation/configuration script multiple times should not cause unexpected changes.

Secrets should not be stored in Git

Database passwords, API keys, tokens, and other credentials must never be committed to this repository.

Backups are operational data

Database backup files do not belong in Git.

Configuration and data are separate

The repository contains the configuration required to create the backup system, while the actual backups remain on the server under:

/backups/mysql
Recovery must be tested

A backup is only useful if it can actually be restored.

Server information

Current production server:

Hostname: munisanjusto
OS: Ubuntu 24.04
Timezone: America/Argentina/Buenos_Aires

Relevant Docker containers:

sanjusto_php72
sanjusto_mysql

MySQL:

Version: 5.7.44
Database: sanjustodb

The application container exposes HTTP on port 80 and the MySQL container exposes MySQL on port 3306.


After pasting it, run:

```bash
git diff -- README.md

and, assuming everything looks correct:

git add README.md
git commit -m "Document MySQL backup infrastructure"
git push
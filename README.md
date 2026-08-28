# San Justo Infrastructure

Infrastructure and server configuration for the San Justo LAMP environment.

This repository contains reproducible configuration, Terraform modules, and installation scripts for infrastructure and services running on the San Justo application server.

The current scope includes:

- Automated MySQL backups.
- Local backup retention.
- Off-server backup storage in AWS S3.
- Restricted backup upload credentials.
- S3-triggered backup replication to a private bucket.
- Infrastructure-as-code for the AWS backup storage architecture.

---

## Architecture

The current backup architecture is:

```text
                         munisanjusto
                              │
                              │ systemd timer
                              │ daily ~02:00
                              ▼
                     backup-sanjustodb
                              │
                              │ mysqldump
                              ▼
                     sanjusto_mysql
                              │
                              ▼
                    gzip-compressed dump
                              │
                              ▼
                       /backups/mysql/
                              │
                              │ s3:PutObject
                              │ restricted IAM user
                              ▼
              ┌──────────────────────────────┐
              │ S3 backup ingress bucket     │
              │                              │
              │ ...-backup-ingress/mysql/    │
              └──────────────┬───────────────┘
                             │
                             │ ObjectCreated
                             ▼
                  AWS Lambda sanjusto-backup-copy
                             │
                             │ s3:PutObject
                             ▼
              ┌──────────────────────────────┐
              │ S3 private backup bucket     │
              │                              │
              │ ...-backups-private/mysql/   │
              └──────────────────────────────┘
```

The server writes only to the **ingress bucket**.

The Lambda function copies successfully uploaded backups to the **private bucket**.

The private bucket is not directly writable by the server backup uploader.

This separation provides an additional protection layer between the production server and the long-term backup storage.

---

# Repository structure

```text
sanjusto_infra/
├── README.md
│
├── backup/
│   ├── backup-sanjustodb
│   ├── sanjustodb-backup.service
│   └── sanjustodb-backup.timer
│
├── scripts/
│   └── install-mysql-backup.sh
│
└── terraform/
    ├── modules/
    │   └── backup-storage/
    │       ├── main.tf
    │       ├── iam.tf
    │       ├── lifecycle.tf
    │       ├── lambda.tf
    │       ├── variables.tf
    │       ├── outputs.tf
    │       └── versions.tf
    │
    └── environments/
        └── prod/
            └── us-east-1/
                └── backup-storage/
                    └── terragrunt.hcl
```

## `backup/`

Contains the server-side MySQL backup configuration:

- `backup-sanjustodb` — MySQL backup script.
- `sanjustodb-backup.service` — systemd service used to execute the backup.
- `sanjustodb-backup.timer` — systemd timer that schedules the backup.

## `scripts/`

Contains installation scripts used to configure the server.

- `install-mysql-backup.sh` — installs and configures the local MySQL backup infrastructure.

## `terraform/`

Contains the AWS backup-storage infrastructure.

The Terraform module creates and manages:

- S3 buckets.
- S3 versioning.
- S3 encryption.
- S3 public access blocking.
- S3 lifecycle policies.
- Lambda backup-copy function.
- Lambda IAM role.
- Lambda permissions.
- Backup uploader IAM user.
- IAM policies.
- S3 → Lambda notification.

---

# MySQL Backup

## Overview

The San Justo application uses MySQL 5.7 running in Docker.

```text
Container: sanjusto_mysql
Database:  sanjustodb
```

The backup process executes `mysqldump` from inside the MySQL container and creates compressed SQL dumps on the server.

```text
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
```

After the local backup has been created and validated, the backup script uploads it to AWS S3.

---

# Local backup storage

Backups are stored in:

```text
/backups/mysql
```

The directory is owned by:

```text
root:backup-readers
```

with permissions:

```text
750
```

Backup files are created with:

```text
root:backup-readers
```

and permissions:

```text
640
```

This prevents unauthorized users from reading database dumps.

Administrators who need to read backups can be added to the `backup-readers` group:

```bash
sudo usermod -aG backup-readers <username>
```

The user must log out and log back in before the new group membership becomes active.

---

# Backup script

The installed backup script is:

```text
/usr/local/sbin/backup-sanjustodb
```

The script:

1. Verifies that the MySQL container is running.
2. Executes `mysqldump`.
3. Uses `--single-transaction`.
4. Includes stored routines.
5. Includes triggers.
6. Includes events.
7. Compresses the dump using gzip.
8. Verifies gzip integrity.
9. Creates a timestamped backup file.
10. Uploads the backup to the S3 ingress bucket.
11. Applies local retention cleanup.

The script does not contain the MySQL password.

The MySQL root password is obtained from the `MYSQL_ROOT_PASSWORD` environment variable configured inside the MySQL container.

---

# mysqldump options

The dump uses:

```text
--single-transaction
--routines
--triggers
--events
```

`--single-transaction` allows a consistent dump of transactional tables without locking the tables for the duration of the backup.

---

# Local retention

The local retention policy is:

```text
14 days
```

Older local backup files are automatically removed by the backup script.

Backup files follow this naming convention:

```text
sanjustodb-YYYYMMDD-HHMMSS.sql.gz
```

Example:

```text
sanjustodb-20260827-221353.sql.gz
```

---

# Scheduling

The backup is managed by systemd.

Service:

```text
sanjustodb-backup.service
```

Timer:

```text
sanjustodb-backup.timer
```

The timer is configured to run once per day at approximately:

```text
02:00
```

Server timezone:

```text
America/Argentina/Buenos_Aires
```

A randomized delay of up to five minutes is configured.

The timer also uses:

```text
Persistent=true
```

This allows systemd to run a missed backup after the server comes back online.

Check the timer:

```bash
systemctl status sanjustodb-backup.timer
```

or:

```bash
systemctl list-timers sanjustodb-backup.timer
```

---

# Manual backup

A backup can be executed manually:

```bash
sudo systemctl start sanjustodb-backup.service
```

Check the result:

```bash
sudo systemctl status sanjustodb-backup.service --no-pager
```

View recent logs:

```bash
sudo journalctl \
  -u sanjustodb-backup.service \
  -n 50 \
  --no-pager
```

A successful execution should end with messages similar to:

```text
Backup completed successfully
Uploading backup to S3
S3 upload completed successfully
Retention cleanup completed
Backup workflow completed successfully
```

---

# Backup verification

Each backup is gzip-compressed.

Test the integrity of a backup:

```bash
gzip -t /backups/mysql/sanjustodb-YYYYMMDD-HHMMSS.sql.gz
```

A successful command produces no output and returns exit status `0`.

Inspect the end of the SQL dump:

```bash
zcat /backups/mysql/sanjustodb-YYYYMMDD-HHMMSS.sql.gz | tail -20
```

A valid `mysqldump` should contain a footer similar to:

```text
-- Dump completed on YYYY-MM-DD HH:MM:SS
```

List available backups:

```bash
ls -lh /backups/mysql/
```

---

# AWS Off-Site Backup

The local backup is also stored outside the production server in AWS.

AWS account:

```text
945824236743
```

Region:

```text
us-east-1
```

The AWS environment is referred to as the **Lino** account in the infrastructure configuration.

## S3 buckets

Two S3 buckets are used.

### Ingress bucket

```text
sanjusto-945824236743-backup-ingress
```

Backups are uploaded under:

```text
mysql/
```

Full path:

```text
s3://sanjusto-945824236743-backup-ingress/mysql/
```

### Private bucket

```text
sanjusto-945824236743-backups-private
```

Backups copied by Lambda are stored under:

```text
mysql/
```

Full path:

```text
s3://sanjusto-945824236743-backups-private/mysql/
```

---

# S3 security

Both buckets have:

- S3 versioning enabled.
- Server-side encryption using SSE-S3 (`AES256`).
- Public access blocked.

The production server does not have write access to the private backup bucket.

---

# Backup uploader IAM user

The production server uses a dedicated IAM user:

```text
sanjusto-backup-uploader
```

The user has only the permission required to upload MySQL backups:

```text
s3:PutObject
```

Resource:

```text
arn:aws:s3:::sanjusto-945824236743-backup-ingress/mysql/*
```

The IAM policy intentionally does not permit uploading outside the `mysql/` prefix.

For example, this upload is allowed:

```text
s3://sanjusto-945824236743-backup-ingress/mysql/backup.sql.gz
```

while an upload such as:

```text
s3://sanjusto-945824236743-backup-ingress/backup.sql.gz
```

is denied.

This restriction has been explicitly tested.

---

# Server AWS credentials

The AWS credentials used by the backup service are stored outside the Git repository.

The systemd backup script uses:

```text
AWS_PROFILE=sanjusto-backup
AWS_REGION=us-east-1
AWS_SHARED_CREDENTIALS_FILE=/etc/sanjusto-backup/credentials
```

The credentials file must never be committed to Git.

The server-side AWS credentials should only provide the permissions required by the backup uploader.

---

# S3 upload process

After successfully creating and validating a local backup, the backup script uploads it to:

```text
s3://sanjusto-945824236743-backup-ingress/mysql/
```

For example:

```text
sanjustodb-20260827-221353.sql.gz
```

becomes:

```text
s3://sanjusto-945824236743-backup-ingress/mysql/sanjustodb-20260827-221353.sql.gz
```

The upload is considered successful only when the AWS CLI command returns successfully.

---

# S3 → Lambda replication

The ingress bucket is configured with an S3 event notification:

```text
s3:ObjectCreated:*
```

The notification is filtered to:

```text
mysql/
```

The event invokes:

```text
sanjusto-backup-copy
```

The Lambda function copies the newly uploaded object from the ingress bucket to the private bucket.

Example:

```text
s3://sanjusto-945824236743-backup-ingress/mysql/
        │
        │ ObjectCreated
        ▼
sanjusto-backup-copy
        │
        ▼
s3://sanjusto-945824236743-backups-private/mysql/
```

The Lambda function runs on:

```text
Python 3.13
```

---

# Lambda permissions

The Lambda execution role is:

```text
sanjusto-backup-copy-lambda
```

The role permits:

```text
s3:GetObject
```

from:

```text
arn:aws:s3:::sanjusto-945824236743-backup-ingress/mysql/*
```

and:

```text
s3:PutObject
```

to:

```text
arn:aws:s3:::sanjusto-945824236743-backups-private/mysql/*
```

The Lambda also has the standard permissions required for CloudWatch Logs.

---

# Lambda logging

The Lambda function writes logs to:

```text
/aws/lambda/sanjusto-backup-copy
```

Logs can be inspected with:

```bash
AWS_PROFILE=lino aws logs tail \
  /aws/lambda/sanjusto-backup-copy \
  --since 30m \
  --region us-east-1
```

A successful invocation should report messages similar to:

```text
Received event
Copying s3://...-backup-ingress/mysql/<backup>
to s3://...-backups-private/mysql/<backup>
Successfully copied ...
```

---

# S3 lifecycle policies

## Ingress bucket

Objects under:

```text
mysql/
```

are configured to expire after:

```text
7 days
```

Noncurrent object versions are removed after:

```text
7 days
```

This bucket is therefore intended to be a short-lived ingestion area.

## Private bucket

Current objects under:

```text
mysql/
```

are retained.

Noncurrent object versions are removed after:

```text
30 days
```

This bucket is the longer-lived private backup repository.

---

# End-to-end backup validation

The complete backup workflow has been tested successfully.

A manual execution of:

```bash
sudo systemctl start sanjustodb-backup.service
```

successfully:

1. Created a MySQL dump.
2. Compressed it.
3. Verified the gzip file.
4. Stored it under `/backups/mysql`.
5. Uploaded it to the S3 ingress bucket.
6. Triggered the Lambda function.
7. Copied the object to the private S3 bucket.

The workflow has been verified using an actual `sanjustodb` backup.

---

# Check S3 backups

List ingress backups:

```bash
AWS_PROFILE=lino aws s3 ls \
  s3://sanjusto-945824236743-backup-ingress/mysql/ \
  --region us-east-1
```

List private backups:

```bash
AWS_PROFILE=lino aws s3 ls \
  s3://sanjusto-945824236743-backups-private/mysql/ \
  --region us-east-1
```

A newly generated backup should eventually appear in both locations.

---

# Installation

## Local backup infrastructure

The local backup infrastructure can be installed using:

```bash
sudo ./scripts/install-mysql-backup.sh
```

The installer is designed to be idempotent.

Running it multiple times should result in the same configuration.

The installer does not create or configure the MySQL Docker container.

It only installs the backup infrastructure.

---

# Prerequisites

The target server must have:

- Ubuntu/Linux with systemd.
- Docker.
- A running Docker container named `sanjusto_mysql`.
- A `/backups` directory.
- A MySQL database named `sanjustodb`.
- AWS CLI for off-server backup uploads.
- Valid AWS credentials configured outside the repository.

---

# What the installer configures

The installer:

1. Verifies Docker.
2. Verifies the `sanjusto_mysql` container.
3. Verifies `/backups`.
4. Creates the `backup-readers` system group if necessary.
5. Creates `/backups/mysql`.
6. Configures ownership and permissions.
7. Installs the backup script.
8. Installs the systemd service.
9. Installs the systemd timer.
10. Reloads systemd.
11. Enables the backup timer.
12. Starts the backup timer.

The installer does not execute a database backup.

A backup can be tested separately:

```bash
sudo systemctl start sanjustodb-backup.service
```

---

# Terraform / AWS infrastructure

The AWS backup infrastructure is managed using Terraform and Terragrunt.

Module:

```text
terraform/modules/backup-storage/
```

Production environment:

```text
terraform/environments/prod/us-east-1/backup-storage/
```

The environment uses:

```text
Terragrunt
```

with the AWS provider restricted to account:

```text
945824236743
```

and region:

```text
us-east-1
```

The Terraform configuration manages the AWS-side backup architecture, including:

- S3 ingress bucket.
- S3 private bucket.
- S3 versioning.
- S3 encryption.
- S3 public access blocks.
- S3 lifecycle configuration.
- Lambda function.
- Lambda execution role.
- Lambda IAM policy.
- Lambda CloudWatch logging permissions.
- S3 Lambda invocation permission.
- S3 event notification.
- Backup uploader IAM user.
- Backup uploader IAM policy.

Before making infrastructure changes:

```bash
AWS_PROFILE=lino terragrunt plan
```

The plan should be reviewed before applying changes.

---

# Terraform state and AWS credentials

AWS credentials and other secrets must not be stored in this repository.

Terraform should be executed using the appropriate AWS profile:

```bash
AWS_PROFILE=lino terragrunt plan
```

or:

```bash
AWS_PROFILE=lino terragrunt apply
```

The production server uses a separate restricted IAM identity for backup uploads.

---

# Troubleshooting

## Check the Docker container

```bash
docker ps --filter name=sanjusto_mysql
```

The container should be running.

## Check the backup service

```bash
sudo systemctl status sanjustodb-backup.service
```

## Check service logs

```bash
sudo journalctl \
  -u sanjustodb-backup.service \
  --no-pager
```

For the most recent execution:

```bash
sudo journalctl \
  -u sanjustodb-backup.service \
  -n 50 \
  --no-pager
```

## Check the timer

```bash
systemctl status sanjustodb-backup.timer
```

and:

```bash
systemctl list-timers sanjustodb-backup.timer
```

## Check backup permissions

```bash
ls -ld /backups/mysql
ls -lh /backups/mysql
```

Expected directory ownership:

```text
root backup-readers
```

Expected backup file permissions:

```text
-rw-r-----
```

## Check AWS credentials

Do not print credentials.

Verify the identity only:

```bash
AWS_PROFILE=sanjusto-backup aws sts get-caller-identity
```

The expected identity is the dedicated:

```text
sanjusto-backup-uploader
```

## Check the ingress bucket

```bash
AWS_PROFILE=lino aws s3 ls \
  s3://sanjusto-945824236743-backup-ingress/mysql/ \
  --region us-east-1
```

## Check the private bucket

```bash
AWS_PROFILE=lino aws s3 ls \
  s3://sanjusto-945824236743-backups-private/mysql/ \
  --region us-east-1
```

## Check Lambda logs

```bash
AWS_PROFILE=lino aws logs tail \
  /aws/lambda/sanjusto-backup-copy \
  --since 30m \
  --region us-east-1
```

---

# Restore

A local backup can be restored using `zcat` and the MySQL client.

Example:

```bash
zcat /backups/mysql/sanjustodb-YYYYMMDD-HHMMSS.sql.gz \
  | docker exec -i sanjusto_mysql \
      mysql -uroot -p sanjustodb
```

Do not execute a restore against the production database unless the consequences are fully understood.

A dedicated MySQL 5.7 test container should be used to validate backups before relying on them for disaster recovery.

## AWS restore

A backup can first be downloaded from the private S3 bucket.

For example:

```bash
AWS_PROFILE=lino aws s3 cp \
  s3://sanjusto-945824236743-backups-private/mysql/<backup-file>.sql.gz \
  /tmp/<backup-file>.sql.gz \
  --region us-east-1
```

The downloaded file should then be validated:

```bash
gzip -t /tmp/<backup-file>.sql.gz
```

The restore should preferably be performed against a dedicated test MySQL 5.7 environment.

---

# Recovery status

The backup creation and off-server replication workflow is currently operational.

The following have been implemented and tested:

- MySQL dump generation.
- gzip compression.
- gzip integrity verification.
- Local 14-day retention.
- systemd scheduling.
- S3 upload.
- Restricted backup uploader IAM identity.
- S3 ingress bucket.
- S3 versioning.
- S3 encryption.
- S3 lifecycle policies.
- S3 → Lambda event notification.
- Lambda backup copy.
- Private S3 backup bucket.
- Lambda logging.

The following still require additional work:

- A formally documented disaster-recovery restore procedure.
- A repeatable automated restore test.
- Backup monitoring and alerting.
- Server recovery documentation.
- Additional LAMP server configuration.

---

# Design principles

This repository follows several basic principles.

## Infrastructure should be reproducible

Server and cloud infrastructure should be represented in Git whenever practical.

## Scripts should be idempotent

Running an installation or configuration script multiple times should not cause unexpected changes.

## Secrets should not be stored in Git

Database passwords, AWS credentials, API keys, tokens, and other credentials must never be committed to this repository.

Credentials required by the production server are stored outside the repository.

## Backups are operational data

Database backup files do not belong in Git.

Local backups remain under:

```text
/backups/mysql
```

AWS backups remain in the S3 backup buckets.

## Least privilege

The production server uses a dedicated IAM user with permission limited to:

```text
s3:PutObject
```

on:

```text
sanjusto-945824236743-backup-ingress/mysql/*
```

The Lambda function has separate permissions for reading from the ingress bucket and writing to the private bucket.

## Configuration and data are separate

The repository contains the configuration required to create and operate the backup system.

The actual database backups remain outside Git.

## Recovery must be tested

A backup is only useful if it can actually be restored.

Restore testing is therefore considered a required part of the backup lifecycle.

---

# Server information

Current production server:

```text
Hostname: munisanjusto
OS: Ubuntu 24.04
Timezone: America/Argentina/Buenos_Aires
```

Relevant Docker containers:

```text
sanjusto_php72
sanjusto_mysql
```

MySQL:

```text
Version: 5.7.44
Database: sanjustodb
```

The application container exposes HTTP on port 80.

The MySQL container exposes MySQL on port 3306.

---

# Current backup flow summary

The operational backup flow is:

```text
02:00 approximately
       │
       ▼
systemd timer
       │
       ▼
sanjustodb-backup.service
       │
       ▼
/usr/local/sbin/backup-sanjustodb
       │
       ├── verify MySQL container
       ├── mysqldump
       ├── gzip
       ├── gzip integrity check
       ├── save locally
       ├── upload to S3 ingress
       └── local retention cleanup
                    │
                    ▼
       S3 backup-ingress/mysql/
                    │
                    │ ObjectCreated
                    ▼
          sanjusto-backup-copy
                    │
                    ▼
       S3 backups-private/mysql/
```

This provides both:

- short-term local recovery on the application server; and
- off-server backup storage in AWS.

The two layers have independent retention policies.

---

# Roadmap

The following items remain planned:

- Automated restore testing.
- Backup monitoring and alerting.
- Failure notification.
- Server recovery documentation.
- Additional LAMP server infrastructure.
- Further disaster-recovery improvements.

The following items are already implemented:

- Automated MySQL backup.
- Compressed backup files.
- Backup integrity verification.
- Local retention policy.
- systemd backup service.
- systemd backup timer.
- Reproducible backup installation.
- Idempotent backup configuration.
- Off-server S3 backup storage.
- Restricted S3 upload credentials.
- S3 → Lambda replication.
- Private backup storage.
- S3 lifecycle management.
- Terraform management of AWS backup infrastructure.
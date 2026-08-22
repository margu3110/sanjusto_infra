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
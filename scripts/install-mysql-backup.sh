#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

BACKUP_SCRIPT="${REPO_ROOT}/backup/backup-sanjustodb"
SYSTEMD_SERVICE="${REPO_ROOT}/backup/sanjustodb-backup.service"
SYSTEMD_TIMER="${REPO_ROOT}/backup/sanjustodb-backup.timer"

INSTALL_BACKUP_SCRIPT="/usr/local/sbin/backup-sanjustodb"
INSTALL_SYSTEMD_SERVICE="/etc/systemd/system/sanjustodb-backup.service"
INSTALL_SYSTEMD_TIMER="/etc/systemd/system/sanjustodb-backup.timer"

BACKUP_DIR="/backups/mysql"
BACKUP_GROUP="backup-readers"
MYSQL_CONTAINER="sanjusto_mysql"

log() {
    echo "[INFO] $*"
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

if [[ "${EUID}" -ne 0 ]]; then
    error "This script must be run as root. Use: sudo $0"
fi

log "Starting sanjustodb backup configuration"

# ---------------------------------------------------------------------------
# Validate prerequisites
# ---------------------------------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
    error "Docker is not installed"
fi

if ! systemctl is-active --quiet docker; then
    error "Docker service is not running"
fi

if ! docker inspect "${MYSQL_CONTAINER}" >/dev/null 2>&1; then
    error "Docker container '${MYSQL_CONTAINER}' does not exist"
fi

if [[ ! -d /backups ]]; then
    error "/backups does not exist"
fi

if [[ ! -f "${BACKUP_SCRIPT}" ]]; then
    error "Backup script not found: ${BACKUP_SCRIPT}"
fi

if [[ ! -f "${SYSTEMD_SERVICE}" ]]; then
    error "Systemd service file not found: ${SYSTEMD_SERVICE}"
fi

if [[ ! -f "${SYSTEMD_TIMER}" ]]; then
    error "Systemd timer file not found: ${SYSTEMD_TIMER}"
fi

# ---------------------------------------------------------------------------
# Configure backup group
# ---------------------------------------------------------------------------

if getent group "${BACKUP_GROUP}" >/dev/null 2>&1; then
    log "Group '${BACKUP_GROUP}' already exists"
else
    log "Creating group '${BACKUP_GROUP}'"
    groupadd --system "${BACKUP_GROUP}"
fi

# ---------------------------------------------------------------------------
# Configure backup directory
# ---------------------------------------------------------------------------

if [[ ! -d "${BACKUP_DIR}" ]]; then
    log "Creating ${BACKUP_DIR}"
    mkdir -p "${BACKUP_DIR}"
fi

log "Configuring ${BACKUP_DIR}"

chown root:"${BACKUP_GROUP}" "${BACKUP_DIR}"
chmod 750 "${BACKUP_DIR}"

# ---------------------------------------------------------------------------
# Install backup script
# ---------------------------------------------------------------------------

log "Installing backup script"

install \
    -o root \
    -g root \
    -m 0750 \
    "${BACKUP_SCRIPT}" \
    "${INSTALL_BACKUP_SCRIPT}"

# ---------------------------------------------------------------------------
# Install systemd units
# ---------------------------------------------------------------------------

log "Installing systemd service"

install \
    -o root \
    -g root \
    -m 0644 \
    "${SYSTEMD_SERVICE}" \
    "${INSTALL_SYSTEMD_SERVICE}"

log "Installing systemd timer"

install \
    -o root \
    -g root \
    -m 0644 \
    "${SYSTEMD_TIMER}" \
    "${INSTALL_SYSTEMD_TIMER}"

# ---------------------------------------------------------------------------
# Configure systemd
# ---------------------------------------------------------------------------

log "Reloading systemd"

systemctl daemon-reload

log "Enabling backup timer"

systemctl enable sanjustodb-backup.timer

log "Starting backup timer"

systemctl start sanjustodb-backup.timer

# ---------------------------------------------------------------------------
# Display configuration
# ---------------------------------------------------------------------------

echo
log "MySQL backup configuration installed successfully"
echo
echo "Backup directory:"
echo "  ${BACKUP_DIR}"
echo
echo "Backup group:"
echo "  ${BACKUP_GROUP}"
echo
echo "Backup script:"
echo "  ${INSTALL_BACKUP_SCRIPT}"
echo
echo "Systemd service:"
echo "  ${INSTALL_SYSTEMD_SERVICE}"
echo
echo "Systemd timer:"
echo "  ${INSTALL_SYSTEMD_TIMER}"
echo
echo "Timer status:"
systemctl --no-pager --full status sanjustodb-backup.timer
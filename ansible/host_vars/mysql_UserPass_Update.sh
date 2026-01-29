#!/bin/bash

##############################################################################
# Script: mysql_UserPass_Update.sh
# Description: Updates MySQL username and password in DB-related host_vars files
# Usage: ./mysql_UserPass_Update.sh <mysql_user> <mysql_password>
##############################################################################

# Input arguments
NEW_USER="$1"
NEW_PASS="$2"

if [[ -z "$NEW_USER" || -z "$NEW_PASS" ]]; then
  echo "Usage: $0 <mysql_user> <mysql_password>"
  exit 1
fi

# Configuration
HOST_VARS_DIR="/opt/Airlinq/ansible/amx_ansible/host_vars"
BACKUP_DIR="${HOST_VARS_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/tmp/mysql_UserPass_Update_$(date +%Y%m%d_%H%M%S).log"

# List of DB hosts to update
DB_HOSTS=(
  DLVMAMXGCCDR01
  DLVMAMXMASTERDB01
  DLVMAMXOLDB01
  DLVMAMXOLDB02
  DLVMAMXOLDB03
  DLVMAMXOMBSSDB02
  DLVMAMXPRODGCDBREP02
  DLVMAMXRECDRDB02
  DLVMAMXRECDRDB03
  DLVMAMXREPLICA01
  DLVMAMXREPLICA02
  DLVMAMXSECONDARYDB01
  DLVMMAXALLBSSDB03
  DLVMMAXBRBSSDB01
)

# Logging helpers
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"
log "${BLUE}============================================================"
log "MySQL User/Pass Update Script"
log "============================================================"
log "Start Time: $(date)"
log "Host Vars Directory: ${HOST_VARS_DIR}"
log "Log File: ${LOG_FILE}"
log "New MySQL User: ${NEW_USER}"
log "============================================================"
log "${BLUE}Creating backup directory: ${BACKUP_DIR}${NC}"
log "✓ Backup directory created"

# Process each DB host file
for host in "${DB_HOSTS[@]}"; do
  file="${HOST_VARS_DIR}/${host}.yml"

  if [[ ! -f "$file" ]]; then
    log "${RED}✗ ${file} not found, skipping.${NC}"
    continue
  fi

  log "\nProcessing: ${host}.yml"

  # Backup the original file
  cp "$file" "${BACKUP_DIR}/"
  if [[ $? -ne 0 ]]; then
    log "${RED}  ✗ Failed to back up ${file}${NC}"
    continue
  fi

  # Create temp file
  temp_file=$(mktemp)

  # Use awk to update both user and password under mysql_servers
  awk -v new_user="$NEW_USER" -v new_pass="$NEW_PASS" '
  BEGIN { in_mysql_block=0 }
  {
      if ($0 ~ /^mysql_servers:/) {
          in_mysql_block = 1
          print
          next
      }

      if (in_mysql_block) {
          if ($0 ~ /^[[:space:]]*-[[:space:]]*user:/ || $0 ~ /^[[:space:]]*user:/) {
              sub(/user:.*/, "user: " new_user)
          } else if ($0 ~ /^[[:space:]]*password:/) {
              sub(/password:.*/, "password: " new_pass)
          } else if ($0 !~ /^[[:space:]]+/) {
              # Exit mysql_servers block when non-indented line appears
              in_mysql_block = 0
          }
      }

      print
  }
  ' "$file" > "$temp_file"

  if [[ $? -eq 0 ]]; then
    mv "$temp_file" "$file"
    log "${GREEN}  ✓ Updated successfully${NC}"
  else
    log "${RED}  ✗ Failed to process ${file}${NC}"
    rm -f "$temp_file"
  fi
done

# Summary
log "\n${BLUE}MySQL user/password update completed for DB hosts.${NC}"
log "${BLUE}Backup directory: ${BACKUP_DIR}${NC}"
log "To rollback:"
log "  cp ${BACKUP_DIR}/* ${HOST_VARS_DIR}/"
log "============================================================"


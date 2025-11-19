#!/bin/bash

##############################################################################
# Script: enable_mysql_replica_monitor.sh
# Description: Sets deploy_mysql_replica_status_monitor to true for MySQL servers
# Usage: ./enable_mysql_replica_monitor.sh
##############################################################################

# Configuration
HOST_VARS_DIR="/opt/Airlinq/ansible/host_vars"
BACKUP_DIR="${HOST_VARS_DIR}/backup_mysql_enable_$(date +%Y%m%d_%H%M%S)"
OLD_LINE="deploy_mysql_replica_status_monitor: false"
NEW_LINE="deploy_mysql_replica_status_monitor: true"
LOG_FILE="/tmp/enable_mysql_replica_$(date +%Y%m%d_%H%M%S).log"

# MySQL servers that need the flag set to true
MYSQL_SERVERS=(
    "DLVMAMXOMBSSDB02"
    "DLVMMAXBRBSSDB01"
    "DLVMMAXALLBSSDB03"
    "DLVMAMXOLDB01"
    "DLVMAMXOLDB02"
    "DLVMAMXOLDB03"
    "DLVMAMXMASTERDB01"
    "DLVMAMXREPLICA01"
    "DLVMAMXSECONDARYDB01"
    "DLVMAMXREPLICA02"
    "DLVMAMXRECDRDB02"
    "DLVMAMXRECDRDB03"
    "DLVMAMXPRODGCDBREP02"
    "DLVMAMXGCCDR01"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_SERVERS=${#MYSQL_SERVERS[@]}
UPDATED_SERVERS=0
SKIPPED_SERVERS=0
ERROR_SERVERS=0

# Function to log messages
log_message() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Function to create backup
create_backup() {
    log_message "${BLUE}Creating backup directory: ${BACKUP_DIR}${NC}"
    mkdir -p "$BACKUP_DIR"
    if [ $? -eq 0 ]; then
        log_message "${GREEN}✓ Backup directory created${NC}"
        return 0
    else
        log_message "${RED}✗ Failed to create backup directory${NC}"
        return 1
    fi
}

# Function to check if hostname is in the MySQL servers list
is_mysql_server() {
    local hostname=$1
    for server in "${MYSQL_SERVERS[@]}"; do
        if [ "$server" = "$hostname" ]; then
            return 0
        fi
    done
    return 1
}

# Function to update a single file
update_file() {
    local hostname=$1
    local file="${HOST_VARS_DIR}/${hostname}.yml"
    
    log_message "\n${BLUE}Processing: ${hostname}${NC}"
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        log_message "${RED}  ✗ File not found: ${file}${NC}"
        ERROR_SERVERS=$((ERROR_SERVERS + 1))
        return 1
    fi
    
    # Check if file is readable and writable
    if [ ! -r "$file" ] || [ ! -w "$file" ]; then
        log_message "${RED}  ✗ Cannot read/write file${NC}"
        ERROR_SERVERS=$((ERROR_SERVERS + 1))
        return 1
    fi
    
    # Check if the old line exists
    if ! grep -q "^${OLD_LINE}" "$file"; then
        log_message "${YELLOW}  ⊘ Skipped: Line '${OLD_LINE}' not found${NC}"
        SKIPPED_SERVERS=$((SKIPPED_SERVERS + 1))
        return 0
    fi
    
    # Check if already set to true
    if grep -q "^${NEW_LINE}" "$file"; then
        log_message "${YELLOW}  ⊘ Skipped: Already set to true${NC}"
        SKIPPED_SERVERS=$((SKIPPED_SERVERS + 1))
        return 0
    fi
    
    # Create backup of this file
    cp "$file" "${BACKUP_DIR}/${hostname}.yml"
    if [ $? -ne 0 ]; then
        log_message "${RED}  ✗ Failed to create backup${NC}"
        ERROR_SERVERS=$((ERROR_SERVERS + 1))
        return 1
    fi
    
    # Update the file using sed
    sed -i "s/^${OLD_LINE}/${NEW_LINE}/" "$file"
    
    # Verify the change
    if grep -q "^${NEW_LINE}" "$file"; then
        log_message "${GREEN}  ✓ Updated successfully${NC}"
        log_message "${BLUE}     Changed: ${OLD_LINE}${NC}"
        log_message "${GREEN}     To:      ${NEW_LINE}${NC}"
        UPDATED_SERVERS=$((UPDATED_SERVERS + 1))
        return 0
    else
        log_message "${RED}  ✗ Update failed${NC}"
        # Restore from backup
        cp "${BACKUP_DIR}/${hostname}.yml" "$file"
        ERROR_SERVERS=$((ERROR_SERVERS + 1))
        return 1
    fi
}

# Main execution
main() {
    log_message "============================================================"
    log_message "Enable MySQL Replica Monitor Script"
    log_message "============================================================"
    log_message "Start Time: $(date)"
    log_message "Host Vars Directory: ${HOST_VARS_DIR}"
    log_message "Log File: ${LOG_FILE}"
    log_message "============================================================\n"
    
    # Check if host_vars directory exists
    if [ ! -d "$HOST_VARS_DIR" ]; then
        log_message "${RED}ERROR: Host vars directory not found: ${HOST_VARS_DIR}${NC}"
        exit 1
    fi
    
    # Create backup directory
    if ! create_backup; then
        log_message "${RED}ERROR: Cannot create backup directory. Exiting.${NC}"
        exit 1
    fi
    
    log_message "\n${BLUE}MySQL Servers to Update (${TOTAL_SERVERS} servers):${NC}"
    log_message "============================================================"
    for server in "${MYSQL_SERVERS[@]}"; do
        log_message "  - ${server}"
    done
    log_message "============================================================"
    
    log_message "\n${BLUE}Starting updates...${NC}"
    log_message "============================================================"
    
    # Process each MySQL server
    for server in "${MYSQL_SERVERS[@]}"; do
        update_file "$server"
    done
    
    # Summary
    log_message "\n============================================================"
    log_message "${BLUE}SUMMARY${NC}"
    log_message "============================================================"
    log_message "Total MySQL servers:     ${TOTAL_SERVERS}"
    log_message "${GREEN}Successfully updated:     ${UPDATED_SERVERS}${NC}"
    log_message "${YELLOW}Skipped (no change):      ${SKIPPED_SERVERS}${NC}"
    log_message "${RED}Errors:                   ${ERROR_SERVERS}${NC}"
    log_message "------------------------------------------------------------"
    log_message "Backup location: ${BACKUP_DIR}"
    log_message "Log file: ${LOG_FILE}"
    log_message "End Time: $(date)"
    log_message "============================================================\n"
    
    # Show verification commands
    if [ $UPDATED_SERVERS -gt 0 ]; then
        log_message "${GREEN}Changes applied successfully!${NC}\n"
        log_message "${BLUE}To verify changes, run:${NC}"
        log_message "  for server in ${MYSQL_SERVERS[@]:0:3}; do"
        log_message "    echo \"=== \$server ===\""
        log_message "    grep 'deploy_mysql_replica_status_monitor' ${HOST_VARS_DIR}/\${server}.yml"
        log_message "  done\n"
        log_message "${BLUE}To rollback if needed:${NC}"
        log_message "  cp ${BACKUP_DIR}/*.yml ${HOST_VARS_DIR}/\n"
    fi
    
    # Exit with appropriate code
    if [ $ERROR_SERVERS -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main

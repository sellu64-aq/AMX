#!/bin/bash

##############################################################################
# Script: update_host_vars_files.sh
# Description: Adds deploy_mysql_replica_status_monitor flag to all host_vars files
# Usage: ./update_host_vars_files.sh
##############################################################################

# Configuration
HOST_VARS_DIR="/opt/Airlinq/ansible/amx_ansible/host_vars"
BACKUP_DIR="${HOST_VARS_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
SEARCH_LINE="########## Feature Flags ##########"
NEW_LINE="deploy_mysql_replica_status_monitor: false"
LOG_FILE="/tmp/update_host_vars_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_FILES=0
UPDATED_FILES=0
SKIPPED_FILES=0
ERROR_FILES=0

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

# Function to process a single file
process_file() {
    local file=$1
    local filename=$(basename "$file")
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    log_message "\n${BLUE}Processing: ${filename}${NC}"
    
    # Check if file is readable
    if [ ! -r "$file" ]; then
        log_message "${RED}  ✗ Cannot read file${NC}"
        ERROR_FILES=$((ERROR_FILES + 1))
        return 1
    fi
    
    # Check if the search line exists in the file
    if ! grep -q "^${SEARCH_LINE}" "$file"; then
        log_message "${YELLOW}  ⊘ Skipped: Feature Flags section not found${NC}"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        return 0
    fi
    
    # Check if the new line already exists
    if grep -q "^${NEW_LINE}" "$file"; then
        log_message "${YELLOW}  ⊘ Skipped: Line already exists${NC}"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        return 0
    fi
    
    # Create backup of this file
    cp "$file" "${BACKUP_DIR}/${filename}"
    if [ $? -ne 0 ]; then
        log_message "${RED}  ✗ Failed to create backup${NC}"
        ERROR_FILES=$((ERROR_FILES + 1))
        return 1
    fi
    
    # Create temporary file
    local temp_file=$(mktemp)
    
    # Process the file: add new line after the search line
    awk -v search="$SEARCH_LINE" -v new="$NEW_LINE" '
    {
        print $0
        if ($0 ~ "^" search "$") {
            print new
        }
    }
    ' "$file" > "$temp_file"
    
    # Check if awk succeeded
    if [ $? -ne 0 ]; then
        log_message "${RED}  ✗ Failed to process file${NC}"
        rm -f "$temp_file"
        ERROR_FILES=$((ERROR_FILES + 1))
        return 1
    fi
    
    # Replace original file with modified version
    mv "$temp_file" "$file"
    if [ $? -eq 0 ]; then
        log_message "${GREEN}  ✓ Updated successfully${NC}"
        UPDATED_FILES=$((UPDATED_FILES + 1))
        
        # Show the change
        log_message "${BLUE}  → Added line after: ${SEARCH_LINE}${NC}"
        log_message "${GREEN}  → ${NEW_LINE}${NC}"
        return 0
    else
        log_message "${RED}  ✗ Failed to update file${NC}"
        rm -f "$temp_file"
        ERROR_FILES=$((ERROR_FILES + 1))
        return 1
    fi
}

# Main execution
main() {
    log_message "============================================================"
    log_message "Host Vars Files Update Script"
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
    
    log_message "\n${BLUE}Starting file processing...${NC}"
    log_message "============================================================"
    
    # Process all .yml files in host_vars directory
    for file in "${HOST_VARS_DIR}"/*.yml; do
        # Skip if no .yml files found
        if [ ! -e "$file" ]; then
            log_message "${YELLOW}No .yml files found in ${HOST_VARS_DIR}${NC}"
            break
        fi
        
        process_file "$file"
    done
    
    # Summary
    log_message "\n============================================================"
    log_message "${BLUE}SUMMARY${NC}"
    log_message "============================================================"
    log_message "Total files processed:  ${TOTAL_FILES}"
    log_message "${GREEN}Successfully updated:    ${UPDATED_FILES}${NC}"
    log_message "${YELLOW}Skipped (no change):     ${SKIPPED_FILES}${NC}"
    log_message "${RED}Errors:                  ${ERROR_FILES}${NC}"
    log_message "------------------------------------------------------------"
    log_message "Backup location: ${BACKUP_DIR}"
    log_message "Log file: ${LOG_FILE}"
    log_message "End Time: $(date)"
    log_message "============================================================\n"
    
    # Show how to verify changes
    if [ $UPDATED_FILES -gt 0 ]; then
        log_message "${GREEN}Changes applied successfully!${NC}\n"
        log_message "${BLUE}To verify changes, run:${NC}"
        log_message "  grep -A1 '${SEARCH_LINE}' ${HOST_VARS_DIR}/*.yml | grep '${NEW_LINE}'\n"
        log_message "${BLUE}To rollback if needed:${NC}"
        log_message "  cp ${BACKUP_DIR}/* ${HOST_VARS_DIR}/\n"
    fi
    
    # Exit with appropriate code
    if [ $ERROR_FILES -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main

#!/usr/bin/env python3
import pandas as pd
import os
import sys

EXCEL_FILE = sys.argv[1] if len(sys.argv) > 1 else "ansible_infra_master.xlsx"
OUTPUT_DIR = "host_vars"
LOG_FILE = "host_vars_generation.log"

print(f"📌 Reading Excel file: {EXCEL_FILE}")

if not os.path.exists(EXCEL_FILE):
    print(f"❌ ERROR: File '{EXCEL_FILE}' not found!")
    sys.exit(1)

# Load Excel sheet
try:
    df = pd.read_excel(EXCEL_FILE, sheet_name="host_vars", dtype=str)
except Exception as e:
    print(f"❌ ERROR: Unable to read sheet 'host_vars': {e}")
    sys.exit(1)

df.columns = df.columns.str.strip()

# Detect all boolean flags dynamically (col name starts with deploy_)
deploy_columns = [col for col in df.columns if col.startswith("deploy_")]

REQUIRED = ["hostname", "apps_list", "ports_list"]
missing = [col for col in REQUIRED if col not in df.columns]
if missing:
    print(f"❌ ERROR: Missing required columns: {missing}")
    sys.exit(1)

os.makedirs(OUTPUT_DIR, exist_ok=True)
log = open(LOG_FILE, "w")
log.write(f"Log started: {pd.Timestamp.now()}\n")

print(f"📂 Output dir: {OUTPUT_DIR}")
print(f"🔍 Detected deploy_* flags: {deploy_columns}")
print("----------------------------------------------------")

def to_bool(val):
    if pd.isna(val):
        return "false"
    v = str(val).strip().lower()
    return "true" if v in ("true", "yes", "1") else "false"

for idx, row in df.iterrows():
    hostname = str(row.get("hostname", "")).strip()
    if not hostname or hostname.lower() == "nan":
        print(f"⚠️  Row {idx+2}: Missing hostname - skipped")
        log.write(f"SKIP: Row {idx+2} missing hostname\n")
        continue

    yaml_file = os.path.join(OUTPUT_DIR, f"{hostname}.yml")
    print(f"➡️ Generating {yaml_file} ...")

    with open(yaml_file, "w") as f:
        f.write(f"# Variables for {hostname}\n---\n")

        # ✅ Write ALL deploy_* booleans dynamically
        for col in deploy_columns:
            f.write(f"{col}: {to_bool(row.get(col))}\n")

        f.write("\napps:\n")
        apps = row.get("apps_list", "")
        if pd.notna(apps) and apps.strip():
            for app in apps.split(","):
                app = app.strip()
                f.write(f"  - name: \"{app}\"\n")
                f.write(f"    match: \"{app}\"\n")
                f.write(f"    type: \"pattern\"\n")
        else:
            f.write("  # No apps configured\n")
            log.write(f"WARN: No apps_list for {hostname}\n")

        f.write("\nports:\n")
        ports = row.get("ports_list", "")
        if pd.notna(ports) and ports.strip():
            for item in ports.split(","):
                parts = [p.strip() for p in item.split(":")]
                if len(parts) == 3:
                    f.write(f"  - ip: \"{parts[0]}\"\n")
                    f.write(f"    port: {parts[1]}\n")
                    f.write(f"    name: \"{parts[2]}\"\n\n")
                else:
                    print(f"⚠️  Invalid port format in row {idx+2}: {item}")
                    log.write(f"WARN: Bad port '{item}' for {hostname}\n")
        else:
            f.write("  # No ports configured\n")
            log.write(f"WARN: No ports_list for {hostname}\n")

    print(f"✅ DONE: {yaml_file}")
    log.write(f"OK: {yaml_file}\n")

print("----------------------------------------------------")
print(f"✅ Completed! YAML files in: {OUTPUT_DIR}")
print(f"📝 Log saved to: {LOG_FILE}")
log.close()


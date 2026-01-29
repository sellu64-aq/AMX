#!/usr/bin/env python3
import pandas as pd
import os
import sys

EXCEL_FILE = sys.argv[1] if len(sys.argv) > 1 else "ansible_infra_master.xlsx"
OUTPUT_FILE = "inventory.ini"

print(f"📌 Reading Excel file: {EXCEL_FILE}")

# Validate file
if not os.path.exists(EXCEL_FILE):
    print(f"❌ ERROR: File '{EXCEL_FILE}' not found!")
    sys.exit(1)

try:
    inv_df = pd.read_excel(EXCEL_FILE, sheet_name="Inventory", dtype=str)
    global_df = pd.read_excel(EXCEL_FILE, sheet_name="global_vars", dtype=str)
except Exception as e:
    print(f"❌ ERROR: Failed to read required sheets: {e}")
    sys.exit(1)

inv_df.columns = inv_df.columns.str.strip()
global_df.columns = global_df.columns.str.strip()

REQUIRED_COLS = ["hostname", "ip", "group", "ansible_user", "ansible_ssh_pass", "ansible_become_password"]
missing = [c for c in REQUIRED_COLS if c not in inv_df.columns]
if missing:
    print(f"❌ ERROR: Missing required Inventory columns: {missing}")
    sys.exit(1)

with open(OUTPUT_FILE, "w") as f:

    # ====================== GLOBAL VARS ======================
    if not global_df.empty:
        f.write("[all:vars]\n")
        for _, row in global_df.iterrows():
            for col, val in row.items():
                if pd.notna(val):
                    f.write(f"{col}={val}\n")
        f.write("\n")

    # ====================== GROUP HOST ENTRIES ======================
    for group in sorted(inv_df["group"].dropna().unique()):
        f.write(f"[{group}]\n")
        subdf = inv_df[inv_df["group"] == group]

        for _, row in subdf.iterrows():
            host = row["hostname"]
            host_ip = row["ip"]
            user = row["ansible_user"]
            ssh_pass = row["ansible_ssh_pass"]
            become_pass = row["ansible_become_password"]
            python_interp = row.get("ansible_python_interpreter", "")

            f.write(f"{host} ansible_host={host_ip} ansible_user={user} ansible_ssh_pass='{ssh_pass}' ansible_become_password='{become_pass}'")

            if pd.notna(python_interp) and python_interp.strip():
                f.write(f" ansible_python_interpreter={python_interp}")

            f.write("\n")
        f.write("\n")

    # ====================== CHILD GROUPS SECTION ======================
    groups = sorted(inv_df["group"].dropna().unique())
    f.write("[all_servers:children]\n")
    for g in groups:
        f.write(f"{g}\n")

print(f"✅ inventory.ini generated successfully!")
print(f"📄 File saved as: {OUTPUT_FILE}")


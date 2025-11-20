# AAP Backup PVC Inspection Tools

This repository contains utilities to help inspect backup PVCs and gather the directory information required to build a correct **Ansible Automation Platform (AAP) 2.5 restore manifest**.

AAP 2.5 stores each component’s backup in separate PVCs, so identifying the correct directory under `/backups` is required before performing a restore.

These helper scripts automate that process.

---

## Scripts Included

### `inspectpvc`

Inspect a single PVC by:

- Creating a temporary pod  
- Mounting the PVC at `/backups`  
- Listing directory contents  
- Cleaning up after completion  

**Usage:**

```bash
./inspectpvc <PVC_NAME>
```

**Example:**

```bash
./inspectpvc aap-controller-backup-claim
```

This prints all directories under `/backups` for that specific PVC.

---

### `inspect-all-backups.sh`

A wrapper script that:

- Detects all PVCs with "backup" in the name  
- Runs `inspectpvc` for each  
- Extracts every directory containing "backup" inside each PVC  
- Outputs a clean summary table  

**Usage:**

```bash
./inspect-all-backups.sh
```

**Example output:**

```
PVC NAME                            | BACKUP DIRECTORIES
----------------------------------- | ------------------------------------------------------------
aap-backup-claim                    | aap-openshift-backup-2025-11-19-13:20:37
aap-controller-backup-claim         | tower-openshift-backup-2025-11-19-13:21:10
aap-hub-backup-claim                | openshift-backup-2025-11-19-13:21:12
aap-eda-backup-claim                | eda-openshift-backup-2025-11-19-13:21:15
```

This table provides the exact `backup_dir` values needed to construct the restore CR.

---

## Why This Is Needed for AAP Restores

AAP 2.5 backup/restore uses separate PVCs for:

- Platform metadata  
- Automation Controller  
- Automation Hub  
- EDA (Event-Driven Ansible)  

Each PVC contains a directory under `/backups` that stores the backup archive.  
During restore, the operator requires:

- The PVC name  
- The backup directory inside the PVC  

for each subsystem.  
These scripts ensure the values are collected accurately.

---

## Official Red Hat Documentation Reference

**Red Hat Ansible Automation Platform 2.5 — Backup and Recovery for Operator Environments**

Section: *Restoring the AAP platform from a PVC*  
https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/backup_and_recovery_for_operator_environments/assembly-aap-recovery#aap-platform-pvc-restore_aap-recovery

---

## Example Restore CR

Below is the example restore manifest from the Red Hat documentation, showing how PVC names and `backup_dir` values are used:

```yaml
---
apiVersion: aap.ansible.com/v1alpha1
kind: AnsibleAutomationPlatformRestore
metadata:
  name: aap
spec:
  deployment_name: aap
  backup_source: PVC
  backup_pvc: aap-backup-claim
  backup_dir: '/backups/aap-openshift-backup-2025-06-23-18:28:29'

  controller:
    backup_source: PVC
    backup_pvc: aap-controller-backup-claim
    backup_dir: '/backups/tower-openshift-backup-2025-06-23-182910'

  hub:
    backup_source: PVC
    backup_pvc: aap-hub-backup-claim
    backup_dir: '/backups/openshift-backup-2025-06-23-182853'
    storage_type: file

  eda:
    backup_source: PVC
    backup_pvc: aap-eda-backup-claim
    backup_dir: '/backups/eda-openshift-backup-2025-06-23-18:29:11'
```

After running `inspect-all-backups.sh`, replace each `backup_dir` value with the directory names found in your PVCs.

---

## Summary

These scripts:

- Automate discovery of AAP backup PVCs  
- Identify internal backup directories  
- Output a formatted summary table  
- Make preparing the AAP restore manifest repeatable and error-free  

If you'd like an additional tool that automatically generates the full restore YAML, just let me know.

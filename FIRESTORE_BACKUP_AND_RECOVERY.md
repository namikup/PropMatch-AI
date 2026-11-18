# PropMatch AI — Cloud Firestore Backup, Disaster Recovery & Retention Policy

## Document Metadata
- **Project Target**: `property-71665` (Google Cloud Project Number: `890199159513`)
- **Database**: Cloud Firestore `(default)`
- **Regulatory Framework**: Malaysian Personal Data Protection Act 2010 (PDPA) Security Principle (Section 9) & Malaysian Estate Agency Standards (MEAS)

---

## 1. Executive Summary & Recovery Objectives

PropMatch AI manages sensitive client information, financial budgets, and property transaction pipelines for Malaysian property negotiators. Data loss or corruption could disrupt agent operations and violate PDPA compliance obligations.

### Recovery Targets
- **Recovery Point Objective (RPO)**: $\le 1\text{ hour}$ (Maximum allowable data loss window in a disaster scenario).
- **Recovery Time Objective (RTO)**: $\le 2\text{ hours}$ (Maximum time to restore full operational capability).

---

## 2. Cloud Firestore Backup Architectures

Google Cloud provides two complementary backup mechanisms for Cloud Firestore:

```
┌────────────────────────────────────────────────────────────────────────┐
│                      PROPMATCH AI DATA BACKUP                          │
├───────────────────────────────────┬────────────────────────────────────┤
│   Point-in-Time Recovery (PITR)   │    Scheduled Cloud Storage Export  │
├───────────────────────────────────┼────────────────────────────────────┤
│ • Continuous logging              │ • Cold snapshot                    │
│ • 7-day rolling window            │ • 30-day to 1-year retention       │
│ • Restore to exact microsecond    │ • Cross-region backup copy         │
│ • Zero configuration once enabled │ • Archive for legal compliance     │
└───────────────────────────────────┴────────────────────────────────────┘
```

---

## 3. Implementation Steps

### Step 3.1: Enable Point-in-Time Recovery (PITR)
PITR is the first line of defense against accidental deletions, bad migrations, or rogue updates.

To enable PITR on `property-71665`:
```bash
gcloud firestore databases update \
  --project=property-71665 \
  --database="(default)" \
  --enable-pitr
```
*Note: PITR stores change logs for 7 days with billing based on gigabytes of storage.*

### Step 3.2: Create Dedicated Cloud Storage Backup Bucket
Create a Google Cloud Storage bucket in the same multi-region / region as the Firestore database (e.g., `asia-southeast1`):

```bash
gcloud storage buckets create gs://property-71665-firestore-backups \
  --project=property-71665 \
  --location=asia-southeast1 \
  --uniform-bucket-level-access
```

Configure a 30-day lifecycle rule to auto-expire old snapshots:
```json
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 30}
    }
  ]
}
```
Apply lifecycle:
```bash
gcloud storage buckets update gs://property-71665-firestore-backups --lifecycle-file=lifecycle.json
```

### Step 3.3: Schedule Automated Daily Exports
Use Cloud Scheduler to trigger an automated export daily at `03:00 MYT` (low-traffic Malaysian hours):

1. Grant Firestore Service Account permissions to write to the backup bucket:
   ```bash
   PROJECT_ID="property-71665"
   SERVICE_ACCOUNT="service-890199159513@gcp-sa-firestore.iam.gserviceaccount.com"
   gcloud storage buckets add-iam-policy-binding gs://${PROJECT_ID}-firestore-backups \
     --member="serviceAccount:${SERVICE_ACCOUNT}" \
     --role="roles/storage.admin"
   ```

2. Create a Cloud Scheduler HTTP Job targeting the Firestore export endpoint:
   ```bash
   gcloud scheduler jobs create http firestore-daily-backup \
     --project=property-71665 \
     --location=asia-southeast1 \
     --schedule="0 3 * * *" \
     --time-zone="Asia/Kuala_Lumpur" \
     --uri="https://firestore.googleapis.com/v1/projects/property-71665/databases/(default):exportDocuments" \
     --http-method=POST \
     --message-body='{"outputUriPrefix":"gs://property-71665-firestore-backups"}' \
     --oauth-service-account-email="property-71665@appspot.gserviceaccount.com"
   ```

---

## 4. Disaster Recovery & Restoration Procedures

### Scenario A: Restoring via Point-in-Time Recovery (PITR)
If an agent accidentally deletes records or a migration defect occurs at `2026-11-18 14:30:00 UTC`:

Restore to a fresh temporary database or directly inspect the historical snapshot:
```bash
# Restore to a new recovery database at exact timestamp
gcloud firestore databases restore \
  --project=property-71665 \
  --source-database="(default)" \
  --destination-database="restored-db-20261118" \
  --recovery-time="2026-11-18T14:30:00.000Z"
```

### Scenario B: Full Restoration from Cloud Storage Backup
To restore the entire database from a daily export:
```bash
gcloud firestore import \
  --project=property-71665 \
  --database="(default)" \
  gs://property-71665-firestore-backups/2026-11-18T03:00:00/
```

### Scenario C: Selective Collection Restoration
To restore only a corrupted or compromised collection (e.g., `buyers` or `consent_records`):
```bash
gcloud firestore import \
  --project=property-71665 \
  --database="(default)" \
  --collection-ids="buyers,consent_records" \
  gs://property-71665-firestore-backups/2026-11-18T03:00:00/
```

---

## 5. Data Recovery Risks & Operational Mitigations

| Risk | Consequence | Mitigation Procedure |
| :--- | :--- | :--- |
| **Additive Import Behavior** | `gcloud firestore import` does not delete newer documents created after the backup timestamp. | Always restore to an isolated staging database first (`restored-db-temp`), sanitize the delta, and merge selectively. |
| **Multi-Tenant Cross-Contamination** | Restoring an entire collection might overwrite Agent B's recent legitimate edits while trying to fix Agent A's issue. | Use `ownerId` filtering in custom recovery scripts to only re-insert affected records for the target agent. |
| **Audit Trail Invalidation** | Overwriting `consent_records` could corrupt PDPA compliance timelines. | `consent_records` should never be blindly imported over existing live records. Inspect the diff and append only missing events. |
| **Backup Storage Costs** | Accumulating uncompressed snapshots incurs persistent storage charges. | Enforce 30-day lifecycle expiration and use coldline/nearline storage classes for archives older than 7 days. |

---

## 6. Recommended Operational Schedule

| Cadence | Action | Target / Destination | Responsibility |
| :--- | :--- | :--- | :--- |
| **Continuous** | PITR Logging (7-day window) | Cloud Firestore Internal Engine | Automated |
| **Daily (03:00 MYT)** | Full Document Export | `gs://property-71665-firestore-backups/daily/` | Cloud Scheduler |
| **Monthly (1st, 04:00 MYT)** | Archive Snapshot | `gs://property-71665-firestore-backups/monthly/` (Coldline) | Cloud Scheduler |
| **Quarterly** | Disaster Recovery Drill | Staging Restore & Verification Test | DevOps / Engineering |

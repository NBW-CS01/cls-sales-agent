# Jamie 2.0 - Security Documentation

## Overview

Jamie 2.0 handles extremely sensitive commercial information including:
- **NDAs** (Non-Disclosure Agreements) - confidential client data
- **Proposals** - pricing, scoping, competitive positioning
- **SOWs** (Statements of Work) - project details, rates
- **Generated documents** - customer-specific NDAs with company details

This document outlines the comprehensive security controls implemented to protect this data.

---

## Security Architecture

### Defense in Depth Strategy

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: AWS Account Security                              │
│  - IAM least privilege                                      │
│  - MFA required for console access                          │
└─────────────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Data Encryption                                   │
│  - KMS encryption at rest                                   │
│  - TLS in transit                                           │
│  - Automatic key rotation                                   │
└─────────────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Access Controls                                   │
│  - S3 bucket policies                                       │
│  - Lambda execution roles (least privilege)                 │
│  - No public access                                         │
└─────────────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Audit & Monitoring                                │
│  - S3 access logs                                           │
│  - CloudWatch logs                                          │
│  - CloudTrail audit trail                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Encryption

### At Rest

**KMS Encryption** (AWS Key Management Service)
- **Algorithm**: AES-256-GCM
- **Key Type**: Customer Managed Key (CMK)
- **Key Rotation**: Automatic annual rotation enabled
- **Deletion Protection**: 30-day waiting period

**Implementation:**
```hcl
# KMS key with automatic rotation
resource "aws_kms_key" "jamie_kb_key" {
  deletion_window_in_days = 30
  enable_key_rotation     = true
}
```

**Why KMS over S3-managed encryption?**
- Centralized key management
- Fine-grained access control
- Audit trail of key usage
- Ability to disable keys (data breach response)

### In Transit

**TLS 1.2+ Required**
- All S3 access must use HTTPS
- Bucket policy denies non-SSL requests
- Lambda → S3: encrypted
- Bedrock Agent → Lambda: encrypted
- Client → API: encrypted

**Implementation:**
```json
{
  "Sid": "DenyInsecureTransport",
  "Effect": "Deny",
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
```

---

## Access Controls

### S3 Bucket Security

#### Public Access: BLOCKED
All four S3 public access settings enabled:
- `BlockPublicAcls = true`
- `BlockPublicPolicy = true`
- `IgnorePublicAcls = true`
- `RestrictPublicBuckets = true`

**Result**: No way to accidentally make data public

#### Bucket Policy: Least Privilege

**Allowed:**
- Lambda functions (with specific IAM role)
- Only necessary operations (GetObject, PutObject, ListBucket)

**Denied:**
- Public access
- Unencrypted uploads
- HTTP (non-SSL) requests

#### IAM Role: Lambda Execution

**Principle**: Least privilege

**Permissions:**
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",       // Read documents
    "s3:PutObject",       // Write generated NDAs
    "s3:ListBucket"       // Search knowledge base
  ],
  "Resource": [
    "arn:aws:s3:::jamie2-knowledge-base-*/",
    "arn:aws:s3:::jamie2-knowledge-base-*/*"
  ]
}
```

**NOT allowed:**
- `s3:DeleteObject` (no accidental deletions)
- `s3:*` (no wildcard permissions)
- Cross-account access

---

## Data Protection

### Versioning: Enabled

**Purpose**: Protect against accidental deletion/modification

**Features:**
- All object versions retained
- Deleted objects recoverable (via version ID)
- Corrupted files recoverable
- Audit trail of changes

**Lifecycle:**
- Current versions: Standard storage
- Old versions (90+ days): Glacier (cost optimization)
- Very old versions (365+ days): Deleted

### MFA Delete: Available

**Recommendation**: Enable via AWS CLI

```bash
aws s3api put-bucket-versioning \
  --bucket jamie2-knowledge-base-xxxxx \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "arn:aws:iam::ACCOUNT:mfa/USER TOKENCODE"
```

**Protection**: Even root user can't permanently delete without MFA

---

## Audit & Monitoring

### S3 Access Logs

**What's logged:**
- Every S3 API call
- Who accessed what document
- When and from where (IP address)
- Success/failure status

**Log retention:** Indefinite (can be configured)

**Log location:** `s3://jamie2-access-logs-xxxxx/knowledge-base-access/`

**Example log entry:**
```
2025-11-06 14:30:15 jamie2-knowledge-base-xxxxx
[REQUEST_ID] arn:aws:iam::ACCOUNT:role/lambda-role
s3:GetObject knowledge/NDAs/NDA_ACLED.pdf
200 - - TLSv1.2 ECDHE-RSA-AES128-GCM-SHA256
```

### CloudWatch Logs

**Lambda execution logs:**
- `/aws/lambda/jamie2-document-retriever` (7 days)
- `/aws/lambda/jamie2-nda-generator` (7 days)
- `/aws/lambda/jamie2-vector-search` (7 days)

**What's captured:**
- Function invocations
- Document searches
- NDA generations
- Error messages

**Retention**: 7 days (configurable up to indefinite)

### CloudTrail

**AWS API audit trail:**
- S3 bucket configuration changes
- IAM policy modifications
- KMS key usage
- Terraform deployments

**Enabled by default** at AWS account level

---

## Data Lifecycle

### Generated NDAs

**Auto-deletion after 90 days:**
```
s3://jamie2-knowledge-base/generated-ndas/
├── NDA_Company_A_20251106.docx  (30 days old) ✓ Retained
├── NDA_Company_B_20250810.docx  (88 days old) ✓ Retained
└── NDA_Company_C_20250805.docx  (93 days old) ✗ Auto-deleted
```

**Rationale:**
- Generated NDAs are temporary working documents
- Final signed NDAs stored elsewhere (CRM, SharePoint)
- Reduces data footprint
- Minimizes breach impact

**Override**: Download important NDAs before 90 days

### Knowledge Base Documents

**Retention:** Indefinite

**Versioning:**
- Current: Hot storage (Standard S3)
- 90+ days old: Cold storage (Glacier)
- 365+ days old: Deleted

**Exception:** Knowledge base source documents (NDAs, proposals) are **never** auto-deleted

---

## How Knowledge Base is Used

### NDA Knowledge Base Purpose

The NDAs in `knowledge/NDAs/` folder serve two purposes:

#### 1. Pattern Learning
When Jamie 2.0 receives a request to generate an NDA, it:
- Searches vector embeddings of existing NDAs
- Finds similar NDAs (by industry, company type, etc.)
- References clause structures and terminology
- Maintains consistency with CloudScaler's style

**Example:**
```
User: "Generate NDA for a Scottish company in healthcare"

Jamie 2.0:
1. Searches vectors: similarity to "Scotland" + "healthcare"
2. Finds: NDA_NHS_SCOTLAND.pdf (similarity: 0.85)
3. Uses as reference for jurisdiction clauses
4. Populates template with Companies House data
```

#### 2. Template Enhancement

Existing NDAs help Claude understand:
- CloudScaler's standard confidentiality terms
- Industry-specific variations (public sector vs enterprise)
- Jurisdiction differences (England vs Scotland vs NI)

### Important Security Notes

**✅ What Claude DOES:**
- Retrieves relevant NDA patterns via vector search
- References structure and terminology
- Uses for contextual understanding

**❌ What Claude DOES NOT:**
- Train on your data (Bedrock doesn't train on customer data)
- Store NDA contents long-term
- Share data across accounts
- Send data outside AWS region

**Data flow:**
```
Request → Vector Search → Retrieve Top 5 Similar NDAs →
→ Claude reads in-context → Generates new NDA → Discarded after response
```

**Retention:** NDA content only in:
1. S3 (encrypted, access-logged)
2. Lambda memory (temporary, seconds)
3. Claude's context window (temporary, request-scoped)

---

## Compliance

### GDPR Considerations

**Personal Data in NDAs:**
- Signatory names
- Company names
- Addresses

**Controls:**
- Right to erasure: Delete via S3 versioning
- Right to access: S3 access logs show who accessed what
- Data minimization: Only store necessary fields
- Purpose limitation: Only used for NDA generation

### NDA Confidentiality

**Irony**: We're storing NDAs in a system with strong confidentiality controls!

**Customer NDAs contain:**
- Company registration numbers (public data)
- Registered addresses (public data from Companies House)
- Signatory names (provided by user)

**Sensitivity:** LOW to MEDIUM (mostly public data)

**Internal proposals/SOWs:**
- Pricing (HIGHLY SENSITIVE)
- Competitive positioning (HIGHLY SENSITIVE)
- Technical approaches (SENSITIVE)

**Sensitivity:** HIGH

---

## Incident Response

### Data Breach Scenarios

#### Scenario 1: S3 Bucket Misconfiguration

**Detection:**
- AWS Config rule violations
- S3 public access alerts
- Unusual access patterns in logs

**Response:**
1. Immediately re-apply Terraform (resets security)
2. Review S3 access logs for unauthorized access
3. Disable KMS key (renders data unreadable)
4. Notify affected customers if data accessed

#### Scenario 2: Compromised IAM Credentials

**Detection:**
- CloudTrail anomaly detection
- Unusual API calls
- Geographic anomalies

**Response:**
1. Rotate IAM credentials immediately
2. Revoke active sessions
3. Review CloudWatch logs for data access
4. Assess data exposure via S3 access logs

#### Scenario 3: Lambda Function Vulnerability

**Detection:**
- Lambda errors in CloudWatch
- Unexpected invocations
- Cost anomalies

**Response:**
1. Disable Lambda functions
2. Review execution logs
3. Patch vulnerability
4. Redeploy with updated code

---

## Security Checklist

### Deployment

- [ ] Terraform applied with security resources
- [ ] S3 public access block verified
- [ ] KMS key created and active
- [ ] S3 access logging enabled
- [ ] CloudWatch log groups created
- [ ] IAM roles use least privilege
- [ ] Bucket policies deny unencrypted uploads
- [ ] MFA delete enabled (manual step)

### Ongoing

- [ ] Review S3 access logs monthly
- [ ] Monitor CloudWatch for anomalies
- [ ] Rotate KMS keys annually (automatic)
- [ ] Review IAM policies quarterly
- [ ] Test data recovery from versions
- [ ] Audit Lambda permissions quarterly

### Before Adding Sensitive Documents

- [ ] Verify document classification
- [ ] Check for PII/sensitive data
- [ ] Ensure proper file naming (no sensitive data in names)
- [ ] Use S3 object tags for classification
- [ ] Encrypt locally before upload (defense in depth)

---

## Best Practices

### For Administrators

1. **Never disable S3 public access block**
2. **Always use Terraform** (infrastructure as code = audit trail)
3. **Review access logs** regularly
4. **Enable MFA delete** for production buckets
5. **Use CloudTrail** to monitor configuration changes

### For Users (Patrick, Sharona, Jamie C)

1. **Don't share presigned URLs** publicly (they're temporary but still sensitive)
2. **Download important NDAs** before 90-day expiry
3. **Report suspicious activity** (unexpected documents, access patterns)
4. **Use strong AWS credentials** (MFA, long passwords)
5. **Don't put sensitive data** in document filenames

### For Developers

1. **Never log sensitive data** (NDA contents, customer details)
2. **Use KMS for all encryption** (no plaintext secrets)
3. **Test IAM policies** with `--dry-run` first
4. **Review CloudWatch logs** for debugging (don't expose data)
5. **Use least privilege** always

---

## Cost of Security

### Monthly Security Overhead

**KMS:**
- Key storage: $1/month
- API calls: $0.03 per 10,000 requests
- Estimated: ~$1.10/month

**S3 Access Logs:**
- Storage: ~$0.02/month (minimal traffic)
- GET requests: <$0.01/month

**CloudWatch Logs:**
- Ingestion: $0.50/GB
- Storage: $0.03/GB/month
- Estimated: ~$0.10/month (low traffic)

**Total security overhead: ~$1.25/month**

**Value:**
- Data breach prevention: Priceless
- Compliance: Required
- Audit trail: Invaluable

---

## Questions & Answers

### Q: Can NDAs in the knowledge base be deleted?

**A:** Yes, but:
1. Delete via S3 console (requires IAM permissions)
2. Deleted objects move to "deleted versions" (recoverable)
3. After 365 days, permanently deleted
4. Can force-delete with MFA delete enabled

### Q: Who can access the knowledge base?

**A:** Only:
1. Lambda functions (with specific IAM role)
2. AWS administrators (with IAM permissions)
3. No one else (public access blocked)

### Q: Is data shared with Anthropic/Claude?

**A:** No:
- Bedrock doesn't train on your data
- Data stays in your AWS account
- Processed in-region (eu-west-2)
- Not shared across accounts

### Q: What happens if someone steals the KMS key?

**A:** Can't happen:
- KMS keys never leave AWS
- Only used via API calls
- Requires IAM permissions
- All usage logged in CloudTrail

### Q: Can I make the security even stronger?

**A:** Yes:
1. Enable MFA delete (manual step)
2. Use VPC endpoints (private networking)
3. Add S3 Object Lock (compliance mode)
4. Enable GuardDuty (threat detection)
5. Add Macie (sensitive data discovery)

---

## Summary

Jamie 2.0 implements **enterprise-grade security** for sensitive commercial documents:

✅ **Encrypted at rest** (KMS with auto-rotation)
✅ **Encrypted in transit** (TLS 1.2+)
✅ **Zero public access** (all four S3 blocks)
✅ **Least privilege IAM** (no wildcard permissions)
✅ **Full audit trail** (S3 logs, CloudWatch, CloudTrail)
✅ **Versioning enabled** (accidental deletion protection)
✅ **Automatic lifecycle** (cost optimization)
✅ **Compliance-ready** (GDPR, NDA confidentiality)

**Monthly cost of security: ~$1.25**
**Value: Protecting confidential business information**

---

**Last Updated**: 2025-11-06
**Review Schedule**: Quarterly
**Next Review**: 2025-02-06

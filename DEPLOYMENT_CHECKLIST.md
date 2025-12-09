# LabLink Deployment Checklist

Use this checklist to ensure you have completed all required setup steps before deploying LabLink infrastructure.

## Pre-Deployment

### Repository Setup
- [ ] Created repository from template ("Use this template" button)
- [ ] Cloned repository to local machine
- [ ] Reviewed README.md for overview

### GitHub Secrets Configuration
- [ ] Added `AWS_ROLE_ARN` secret
  - Format: `arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME`
  - Verified IAM role exists and has correct permissions
  - Verified OIDC trust policy includes your repository
- [ ] Added `AWS_REGION` secret
  - Example: `us-west-2`, `us-east-1`, `eu-west-1`
  - Matches region in `config.yaml`
- [ ] Added `ADMIN_PASSWORD` secret
  - Strong password (12+ characters, mixed case, numbers, symbols)
  - Different from DB_PASSWORD
- [ ] Added `DB_PASSWORD` secret
  - Strong password (12+ characters, mixed case, numbers, symbols)
  - Different from ADMIN_PASSWORD

### AWS Setup

**Choose one approach:**

#### Option A: Automated Setup (Recommended)
- [ ] Copied example config: `cp lablink-infrastructure/config/test.example.yaml lablink-infrastructure/config/config.yaml`
- [ ] Edited `config.yaml` with your values (bucket_name, domain, region)
- [ ] Ran setup script: `./scripts/setup-aws-infrastructure.sh`
- [ ] Script created AWS infrastructure:
  - ✓ S3 bucket with versioning
  - ✓ DynamoDB lock-table
  - ✓ Route53 hosted zone (if DNS enabled) - empty DNS container
  - ✓ Updated config.yaml with zone_id

**What script does NOT create:**
- Domain registration (you must register domain separately - costs ~$12-15/year)
- DNS records (created by Terraform if `dns.terraform_managed: true`, or manually)

**Or if you prefer manual setup:**

#### Option B: Manual S3 Bucket Setup
- [ ] Created S3 bucket for Terraform state
  - Bucket name format: `tf-state-YOUR-ORG-lablink`
  - Bucket is globally unique across ALL of AWS
  - Bucket in same region as deployment
- [ ] Enabled versioning on S3 bucket (recommended)
- [ ] Updated `bucket_name` in `config.yaml` to match
- [ ] Created DynamoDB table named `lock-table` for state locking

#### IAM Role and OIDC
- [ ] Created OIDC identity provider (if not exists)
  - Provider URL: `https://token.actions.githubusercontent.com`
  - Audience: `sts.amazonaws.com`
- [ ] Created IAM role for GitHub Actions
  - Trust policy includes your repository path
  - Has PowerUserAccess or equivalent permissions:
    - EC2 full access
    - VPC management
    - S3 access (for state)
    - Route 53 (if using DNS)
    - IAM (for instance profiles)
- [ ] Verified role ARN matches `AWS_ROLE_ARN` secret

#### Elastic IP (Optional but Recommended)
- [ ] Allocated Elastic IP in AWS
- [ ] Tagged EIP with Name = `{tag_name}-{env}` (e.g., `lablink-eip-prod`)
- [ ] Set `eip.strategy: "persistent"` and `eip.tag_name: "lablink-eip"` to reuse the EIP
- [ ] Or set `eip.strategy: "dynamic"` to create new EIP with tag `{tag_name}-{env}` each deployment

#### DNS Setup (Choose One Approach)

**Approach A: Route53 + Let's Encrypt**
- [ ] Domain registered (Route53 registrar or external)
- [ ] Created or verified Route53 hosted zone exists (setup script does this)
- [ ] Updated domain nameservers to Route53 NS records
- [ ] Choose DNS record management:
  - `dns.terraform_managed: true` - Terraform creates/destroys records automatically
  - `dns.terraform_managed: false` - You create A records manually in Route53 console
- [ ] Set `ssl.provider: "letsencrypt"` in config

**Approach B: CloudFlare DNS + SSL**
- [ ] Domain managed in CloudFlare
- [ ] Set `dns.enabled: false` in config (not using Route53)
- [ ] Set `ssl.provider: "cloudflare"` in config
- [ ] After deployment: Create A record in CloudFlare UI pointing to allocator IP
- [ ] Enable CloudFlare proxy (orange cloud) for SSL

**Approach C: IP-Only (No DNS/SSL)**
- [ ] Set `dns.enabled: false` in config
- [ ] Set `ssl.provider: "none"` or leave SSL config at defaults
- [ ] Access via IP address only

### Configuration Customization

#### Edit `lablink-infrastructure/config/config.yaml`

**Machine/VM Settings:**
- [ ] Updated `repository` URL to your data/code repository
  - Or set to empty string if not needed
- [ ] Updated `software` name for your application
- [ ] Updated `extension` for your data file type
- [ ] Verified `machine_type` is appropriate for your workload
- [ ] Verified `ami_id` matches your AWS region
- [ ] (Optional) Updated `image` if using custom Docker image

**Application Settings:**
- [ ] Verified `region` matches `AWS_REGION` secret
- [ ] Confirmed `admin_user` is acceptable (default: "admin")

**DNS Settings** (if using DNS):
- [ ] Set `enabled: true`
- [ ] Updated `domain` to your domain name
- [ ] Chose `pattern`: "auto" or "custom"
- [ ] Set `zone_id` (or left empty for auto-lookup)
- [ ] Set `terraform_managed` based on preference
  - `true` = Terraform creates/destroys DNS records
  - `false` = You manually create DNS records in Route 53

**SSL Settings** (if using SSL):
- [ ] Set `provider`: "letsencrypt", "cloudflare", "acm", or "none"
- [ ] Updated `email` for Let's Encrypt notifications
- [ ] Set `ssl.provider` appropriately
  - `letsencrypt`: Automatic SSL with production certs
  - `cloudflare`: CloudFlare proxy provides SSL
  - `acm`: Use AWS Certificate Manager (enterprise)
  - `none`: HTTP only for testing

**⚠️ Let's Encrypt Rate Limit Check** (if using `ssl.provider: "letsencrypt"`):
- [ ] Understand rate limits **before deploying**:
  - **5 certificates per exact domain every 7 days** (e.g., `test.example.com`)
  - 50 certificates per registered domain every 7 days (e.g., all `*.example.com`)
  - **Rate limit violations = 7-day lockout with NO override**
- [ ] Check existing certificate count for your domain:
  - Visit [crt.sh](https://crt.sh/?q=your-domain.com) (replace with your domain)
  - Count certificates issued in last 7 days
  - Calculate remaining quota: `5 - (certificates in last 7 days)`
- [ ] Choose appropriate testing strategy if deploying frequently:
  - **IP-only** (no DNS/SSL): `dns.enabled: false`, `ssl.provider: "none"` - No rate limits
  - **Subdomain rotation**: Use different subdomains (`test1`, `test2`, etc.) - 5 attempts per subdomain
  - **CloudFlare SSL**: `ssl.provider: "cloudflare"` - No Let's Encrypt limits
  - See [TESTING_BEST_PRACTICES.md](docs/TESTING_BEST_PRACTICES.md) for detailed guidance
- [ ] If this is production with stable domain: proceed with Let's Encrypt
- [ ] If this is testing/staging: consider IP-only or CloudFlare to avoid lockouts

**S3 Bucket:**
- [ ] Updated `bucket_name` to match created S3 bucket

### Verify AWS Resources (Optional)

Before deploying, you can verify all required AWS resources exist:

```bash
# Verify S3 bucket exists
aws s3 ls s3://YOUR-BUCKET-NAME

# Verify DynamoDB table exists
aws dynamodb describe-table --table-name lock-table --region YOUR-REGION --query "Table.TableName" --output text

# Verify Route53 hosted zone exists (if using DNS)
aws route53 get-hosted-zone --id YOUR-ZONE-ID --query "HostedZone.Name" --output text

# Verify domain registration (if registered via Route53)
aws route53domains get-domain-detail --domain-name your-domain.com --region us-east-1 --query "{Domain: DomainName, Status: StatusList, AutoRenew: AutoRenew}"

# Verify GitHub secrets exist
gh secret list
```

Replace `YOUR-BUCKET-NAME`, `YOUR-REGION`, `YOUR-ZONE-ID`, and `your-domain.com` with your actual values from `config.yaml`.

## Deployment

### Before Running Workflow
- [ ] Reviewed all changes in `config.yaml`
- [ ] Committed and pushed changes to repository
- [ ] Verified no sensitive data in committed files

### Run Deployment
- [ ] Navigated to Actions → "Deploy LabLink Infrastructure"
- [ ] Clicked "Run workflow"
- [ ] Selected environment:
  - `test` - For staging/pre-production testing
  - `prod` - For production deployment
  - `ci-test` - For template maintainers testing infrastructure changes
- [ ] Started workflow

### Monitor Deployment
- [ ] Workflow started successfully
- [ ] No errors in "Configure AWS credentials" step
- [ ] No errors in "Terraform Init" step
- [ ] No errors in "Terraform Apply" step
- [ ] Deployment completed successfully

## Post-Deployment Verification

### Infrastructure Created
- [ ] EC2 instance for allocator is running in AWS console
- [ ] Security group created and attached to instance
- [ ] Elastic IP associated with instance (if using)
- [ ] (If DNS) Route 53 record created or verified

### Access Verification
- [ ] Downloaded SSH key from workflow artifacts
- [ ] Set correct permissions on key: `chmod 600 lablink-key.pem`
- [ ] Can SSH into allocator:
  ```bash
  ssh -i lablink-key.pem ubuntu@<ALLOCATOR_IP_OR_DOMAIN>
  ```
- [ ] Can access allocator web interface:
  - URL: `http://<ALLOCATOR_IP_OR_DOMAIN>:5000` (or HTTPS if SSL enabled)
  - Login works with admin credentials
- [ ] Admin dashboard loads correctly

### DNS Verification (if using DNS)
- [ ] DNS resolves correctly:
  ```bash
  nslookup your-domain.com
  ```
- [ ] DNS points to correct Elastic IP or instance IP
- [ ] Web interface accessible via domain name

### SSL Verification (if using SSL)
- [ ] HTTPS works without certificate errors
- [ ] Certificate is from Let's Encrypt (or CloudFlare)
- [ ] Force HTTPS redirect works (if configured)

### Functional Testing
- [ ] Can create a test client VM from admin dashboard
- [ ] Client VM provisions successfully
- [ ] Client VM appears in "View Instances" page
- [ ] Can access client VM via Chrome Remote Desktop
- [ ] Can destroy client VM successfully

## Verify Clean Destruction

After running destroy workflow or manual cleanup:

### EC2 Resources
- [ ] No EC2 instances remain (allocator or client VMs)
  ```bash
  aws ec2 describe-instances --region us-west-2 --filters "Name=tag:Name,Values=*{env}*" "Name=instance-state-name,Values=running,stopped"
  ```
- [ ] No orphaned security groups
  ```bash
  aws ec2 describe-security-groups --region us-west-2 --filters "Name=group-name,Values=*{env}*"
  ```
- [ ] No orphaned key pairs
  ```bash
  aws ec2 describe-key-pairs --region us-west-2 --filters "Name=key-name,Values=*{env}*"
  ```
- [ ] No orphaned Elastic IPs (if using dynamic strategy)
  ```bash
  aws ec2 describe-addresses --region us-west-2 --filters "Name=tag:Name,Values=*{env}*"
  ```

### IAM Resources
- [ ] No orphaned IAM roles
  ```bash
  aws iam list-roles --query "Roles[?contains(RoleName, '{env}')].RoleName"
  ```
- [ ] No orphaned IAM policies
  ```bash
  aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, '{env}')].PolicyName"
  ```
- [ ] No orphaned instance profiles
  ```bash
  aws iam list-instance-profiles --query "InstanceProfiles[?contains(InstanceProfileName, '{env}')].InstanceProfileName"
  ```

### Other Resources
- [ ] CloudWatch log groups cleaned up (optional - may keep for historical logs)
  ```bash
  aws logs describe-log-groups --region us-west-2 --log-group-name-prefix lablink --query "logGroups[?contains(logGroupName, '{env}')].logGroupName"
  ```
- [ ] S3 state files archived or deleted (if environment no longer needed)
  ```bash
  aws s3 ls s3://{bucket}/{env}/ --recursive
  ```
- [ ] DynamoDB lock entries removed
  ```bash
  aws dynamodb scan --table-name lock-table --region us-west-2 --filter-expression "contains(LockID, :env)" --expression-attribute-values '{":env": {"S": "{env}"}}'
  ```
- [ ] DNS records removed (if terraform_managed=true)
  ```bash
  aws route53 list-resource-record-sets --hosted-zone-id {zone_id} --query "ResourceRecordSets[?starts_with(Name, '{env}')]"
  ```
- [ ] Lambda functions removed
  ```bash
  aws lambda list-functions --region us-west-2 --query "Functions[?contains(FunctionName, '{env}')].FunctionName"
  ```

**Note**: Replace `{env}` with your environment name (e.g., `ci-test`, `test`, `prod`) and `{bucket}`, `{zone_id}` with your actual values from config.yaml.

See [Manual Cleanup Guide](MANUAL_CLEANUP_GUIDE.md) for detailed commands and troubleshooting if any resources remain.

## Troubleshooting Failed Steps

### If AWS credentials fail:
1. Verify `AWS_ROLE_ARN` secret is correct
2. Check IAM role trust policy includes your repository
3. Verify OIDC provider exists in IAM

### If Terraform init fails:
1. Verify S3 bucket exists and is accessible
2. Check bucket name in `config.yaml` matches actual bucket
3. Verify AWS region in secret matches bucket region

### If Terraform apply fails:
1. Check error message for specific resource failing
2. Verify IAM role has necessary permissions for that resource
3. For AMI errors: Update `ami_id` for your region
4. For network errors: Check VPC/subnet settings

### If DNS doesn't resolve:
1. Wait 5-10 minutes for DNS propagation
2. Verify Route 53 hosted zone exists
3. Check zone ID matches (or is empty for auto-lookup)
4. Verify nameservers at domain registrar match Route 53

### If can't access web interface:
1. Check security group allows inbound on port 5000
2. Try IP address instead of domain
3. Check allocator service is running:
   ```bash
   ssh ubuntu@<IP> "docker ps"
   ```
4. Check logs:
   ```bash
   ssh ubuntu@<IP> "docker logs <CONTAINER_ID>"
   ```

## After Successful Deployment

- [ ] Documented allocator URL/IP for team
- [ ] Stored SSH key securely
- [ ] Set up monitoring/alerts (if needed)
- [ ] Created test users/VMs to verify functionality
- [ ] (Optional) Set up automatic backups of Terraform state
- [ ] (Optional) Set up CloudWatch alarms for EC2 instance

## Ongoing Maintenance

- [ ] Regularly update Docker images to latest versions
- [ ] Monitor AWS costs
- [ ] Review security group rules periodically
- [ ] Update AMI when new versions available
- [ ] Renew SSL certificates (automatic with Let's Encrypt)
- [ ] Back up Terraform state regularly

## Need Help?

- [ ] Checked [README.md](README.md) troubleshooting section
- [ ] Reviewed [lablink-infrastructure/README.md](lablink-infrastructure/README.md)
- [ ] Consulted main docs: https://talmolab.github.io/lablink/
- [ ] Searched existing issues: https://github.com/talmolab/lablink/issues
- [ ] Created new issue if problem persists

---

**Deployment Date**: _________________

**Deployed By**: _________________

**Environment**: [ ] Test  [ ] Prod

**Notes**:

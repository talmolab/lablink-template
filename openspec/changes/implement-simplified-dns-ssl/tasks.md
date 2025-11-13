## 1. Configuration Schema Updates
- [ ] 1.1 Update main.tf locals to remove deprecated DNS fields (app_name, pattern, custom_subdomain, create_zone)
- [ ] 1.2 Update main.tf locals to remove ssl.staging
- [ ] 1.3 Add ssl.certificate_arn to locals (for ACM support)
- [ ] 1.4 Update config/config.yaml with new schema (remove deprecated fields)
- [ ] 1.5 Create config/test.example.yaml
- [ ] 1.6 Create config/prod.example.yaml
- [ ] 1.7 Create config/acm.example.yaml

## 2. Terraform DNS Configuration
- [ ] 2.1 Remove pattern-based FQDN computation logic (lines 223-230 in main.tf)
- [ ] 2.2 Update FQDN local to use dns.domain directly
- [ ] 2.3 Add lifecycle hooks to aws_route53_record (prevent_destroy for prod, ignore changes)
- [ ] 2.4 Update DNS zone lookup logic (remove create_zone conditional)
- [ ] 2.5 Test sub-subdomain support (e.g., test.lablink.sleap.ai)

## 3. FQDN Environment Variable
- [ ] 3.1 Add ALLOCATOR_FQDN computation in main.tf locals
- [ ] 3.2 FQDN format: "https://{domain}" when SSL enabled, "http://{ip}" when SSL disabled
- [ ] 3.3 Pass ALLOCATOR_FQDN to user_data.sh template
- [ ] 3.4 Update user_data.sh to set ALLOCATOR_FQDN environment variable in Docker run command
- [ ] 3.5 Remove FQDN computation logic from user_data.sh (Terraform is source of truth)

## 4. SSL/Caddy Configuration
- [ ] 4.1 Remove ssl.staging logic from user_data.sh
- [ ] 4.2 Update Caddy installation to be conditional (only when ssl.provider = letsencrypt or cloudflare)
- [ ] 4.3 Update Caddyfile template to support cloudflare provider
- [ ] 4.4 Ensure Caddy is NOT installed when ssl.provider = acm or none

## 5. ACM/ALB Support
- [ ] 5.1 Create alb.tf with conditional ALB resources (count = ssl.provider == "acm" ? 1 : 0)
- [ ] 5.2 Create Application Load Balancer
- [ ] 5.3 Create ALB target group (port 5000, health check on /health)
- [ ] 5.4 Attach target group to allocator EC2 instance
- [ ] 5.5 Create ALB listener (HTTPS:443 → target group)
- [ ] 5.6 Attach ACM certificate to HTTPS listener
- [ ] 5.7 Create security group for ALB (allow 80, 443 from internet)
- [ ] 5.8 Update allocator security group (allow 5000 from ALB security group)
- [ ] 5.9 Update DNS A record to point to ALB when ssl.provider="acm"

## 6. CI Validation Workflow
- [ ] 6.1 Create .github/workflows/config-validation.yml
- [ ] 6.2 Trigger on pull_request for paths: lablink-infrastructure/config/*.yaml
- [ ] 6.3 Add job: checkout, setup Python 3.11, pip install lablink-allocator-service
- [ ] 6.4 Run lablink-validate-config on each config file
- [ ] 6.5 Fail workflow if validation fails
- [ ] 6.6 Add status check requirement in branch protection (if applicable)

## 7. Documentation Updates
- [ ] 7.1 Update README.md with migration guide
- [ ] 7.2 Document new dns.domain format (full domain, not base zone)
- [ ] 7.3 Document removed fields (app_name, pattern, custom_subdomain, create_zone, staging)
- [ ] 7.4 Document 5 canonical use cases with example configs
- [ ] 7.5 Add ACM certificate creation instructions
- [ ] 7.6 Update troubleshooting section (common migration issues)

## 8. Testing
- [ ] 8.1 Validate new config.yaml passes lablink-validate-config
- [ ] 8.2 Test Use Case 1: IP-only (dns.enabled=false, ssl.provider="none")
- [ ] 8.3 Test Use Case 2: CloudFlare (dns.enabled=false, ssl.provider="cloudflare")
- [ ] 8.4 Test Use Case 3: Route53 + Let's Encrypt (Terraform-managed)
- [ ] 8.5 Test Use Case 4: Route53 + ACM (if certificate available)
- [ ] 8.6 Test Use Case 5: Route53 + Let's Encrypt (manual DNS)
- [ ] 8.7 Verify ALLOCATOR_FQDN environment variable is set correctly in container
- [ ] 8.8 Verify DNS cleanup on terraform destroy (no dangling records)

## 9. Cleanup
- [ ] 9.1 Remove old config examples if any
- [ ] 9.2 Update workflow files to use new config schema
- [ ] 9.3 Verify all GitHub Actions workflows still work
- [ ] 9.4 Run terraform fmt on all .tf files
- [ ] 9.5 Run terraform validate
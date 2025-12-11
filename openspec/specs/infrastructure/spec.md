# Infrastructure Specification

## Purpose

This specification defines the infrastructure requirements for the LabLink system, including Terraform configuration, DNS/SSL management, CI validation, and deployment workflows.

## Requirements

### Requirement: FQDN Environment Variable
The allocator container SHALL receive the fully qualified domain name (FQDN) as an environment variable computed by Terraform.

#### Scenario: FQDN with SSL enabled
- **WHEN** dns.enabled=true AND ssl.provider in ["letsencrypt", "cloudflare", "acm"]
- **THEN** ALLOCATOR_FQDN="https://{dns.domain}"

#### Scenario: FQDN with IP-only access
- **WHEN** dns.enabled=false OR ssl.provider="none"
- **THEN** ALLOCATOR_FQDN="http://{ec2_public_ip}"

#### Scenario: FQDN passed to Docker container
- **WHEN** allocator container starts
- **THEN** ALLOCATOR_FQDN environment variable is set via docker run -e

### Requirement: ACM/ALB Support
The infrastructure SHALL support AWS Certificate Manager (ACM) certificates via Application Load Balancer when ssl.provider="acm".

#### Scenario: ALB creation when ACM enabled
- **WHEN** ssl.provider="acm"
- **THEN** Terraform creates ALB, target group, HTTPS listener, and security groups

#### Scenario: ACM certificate attachment
- **WHEN** ssl.provider="acm" AND ssl.certificate_arn is provided
- **THEN** ALB HTTPS listener uses the specified ACM certificate

#### Scenario: ALB target registration
- **WHEN** ALB is created
- **THEN** allocator EC2 instance is registered to target group on port 5000

#### Scenario: DNS points to ALB
- **WHEN** ssl.provider="acm" AND dns.terraform_managed=true
- **THEN** Route53 A record points to ALB (not EC2 EIP)

### Requirement: Configuration Validation in CI
The CI pipeline SHALL validate config.yaml before deployment using lablink-validate-config.

#### Scenario: Config validation on PR
- **WHEN** pull request modifies lablink-infrastructure/config/*.yaml
- **THEN** GitHub Actions workflow runs lablink-validate-config

#### Scenario: Invalid config blocks merge
- **WHEN** lablink-validate-config exits with non-zero status
- **THEN** workflow fails and merge is blocked

#### Scenario: Valid config allows merge
- **WHEN** lablink-validate-config exits successfully
- **THEN** workflow passes and merge is allowed

### Requirement: DNS Lifecycle Management
DNS records SHALL be cleaned up on infrastructure destruction to prevent subdomain takeover.

#### Scenario: DNS cleanup on destroy
- **WHEN** terraform destroy is executed
- **THEN** Route53 A records are deleted before EC2/ALB termination

#### Scenario: Production DNS protection
- **WHEN** resource_suffix="prod" AND dns.terraform_managed=true
- **THEN** Route53 record has lifecycle { prevent_destroy = true }

### Requirement: DNS Configuration
The system SHALL accept full domain names in dns.domain and support sub-subdomains without pattern-based construction.

#### Scenario: Full domain specified
- **WHEN** dns.domain="lablink.sleap.ai"
- **THEN** Route53 A record is created for "lablink.sleap.ai" (exact match)

#### Scenario: Sub-subdomain specified
- **WHEN** dns.domain="test.lablink.sleap.ai"
- **THEN** Route53 A record is created for "test.lablink.sleap.ai" (exact match)

#### Scenario: Zone lookup matches exact domain
- **WHEN** dns.zone_id="" AND dns.domain="lablink.sleap.ai"
- **THEN** Terraform looks up hosted zone for "lablink.sleap.ai." (exact match only)

### Requirement: SSL Provider Configuration
The system SHALL support four SSL providers: none, letsencrypt, cloudflare, and acm.

#### Scenario: Let's Encrypt SSL
- **WHEN** ssl.provider="letsencrypt"
- **THEN** Caddy is installed and configured for auto-SSL

#### Scenario: CloudFlare SSL
- **WHEN** ssl.provider="cloudflare"
- **THEN** Caddy is installed and serves HTTP (CloudFlare proxy handles SSL termination)

#### Scenario: ACM SSL
- **WHEN** ssl.provider="acm"
- **THEN** Caddy is NOT installed, ALB handles SSL termination

#### Scenario: No SSL
- **WHEN** ssl.provider="none"
- **THEN** Caddy is NOT installed, allocator serves HTTP on port 5000
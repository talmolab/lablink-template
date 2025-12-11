# CI Validation Capability

## MODIFIED Requirements

### Requirement: Config Validation Uses Deployment Image
CI workflows SHALL validate configuration using the same allocator Docker image specified in config.yaml that will be deployed.

**Rationale:** Ensures validation schema matches deployment schema, preventing version mismatches between validator and deployed service.

**Old Behavior:**
- Workflows installed lablink-allocator-service from PyPI using UV
- Validation used schema version from PyPI package
- Version mismatch possible during development (PyPI lags Docker image)

**New Behavior:**
- Workflows extract allocator.image_tag from config.yaml
- Validation uses Docker image matching deployment
- Schema version always matches what will be deployed

#### Scenario: Extract allocator image tag from config
**Given** a config.yaml file exists with `allocator.image_tag` field
**When** the CI validation workflow runs
**Then** it MUST extract the image tag value using:
```bash
IMAGE_TAG=$(grep -A5 "^allocator:" "$CONFIG_FILE" | grep "image_tag:" | awk '{print $2}' | tr -d '"')
```
**And** the workflow MUST fail if image_tag is not found

#### Scenario: Pull allocator Docker image
**Given** an allocator image tag has been extracted
**When** the validation workflow prepares to run validation
**Then** it MUST pull the Docker image from GitHub Container Registry:
```bash
docker pull ghcr.io/talmolab/lablink-allocator-image:${IMAGE_TAG}
```
**And** it MUST authenticate using GITHUB_TOKEN secret

#### Scenario: Run validator in Docker container
**Given** the allocator Docker image has been pulled
**When** the validation workflow runs the validator
**Then** it MUST run lablink-validate-config inside the Docker container:
```bash
docker run --rm \
  -v "$CONFIG_PATH:/config/config.yaml:ro" \
  "ghcr.io/talmolab/lablink-allocator-image:${IMAGE_TAG}" \
  lablink-validate-config /config/config.yaml --verbose
```
**And** the container MUST mount the config file as read-only
**And** the workflow MUST fail if validation returns non-zero exit code

#### Scenario: Validation with bleeding-edge commit
**Given** config.yaml specifies `image_tag: "linux-amd64-0d73aef91a90afe5289b2252fcde76aa1fd4e31f-test"`
**When** the validation workflow runs
**Then** it MUST pull and use that exact commit-based image
**And** validation MUST use the schema from that commit
**And** new schema features in that commit MUST be recognized as valid

#### Scenario: Validation with stable version
**Given** config.yaml specifies `image_tag: "linux-amd64-v1.2.3"`
**When** the validation workflow runs
**Then** it MUST pull and use that exact versioned image
**And** validation MUST use the schema from version 1.2.3

## ADDED Requirements

### Requirement: GitHub Container Registry Authentication
CI workflows SHALL authenticate to GitHub Container Registry before pulling allocator images.

**Rationale:** Prevents rate limiting and enables access to private images if needed.

#### Scenario: Docker login with GITHUB_TOKEN
**Given** the workflow is running in GitHub Actions
**When** the workflow prepares to pull Docker images
**Then** it MUST authenticate using:
```bash
echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
```
**And** login MUST complete before docker pull command

### Requirement: Validation Error Reporting
When validation fails, workflows SHALL provide clear instructions for local reproduction using Docker.

**Rationale:** Helps users debug validation failures locally before pushing fixes.

#### Scenario: Display Docker validation command on failure
**Given** config validation has failed
**When** the workflow reports the failure
**Then** it MUST display instructions including:
```bash
docker pull ghcr.io/talmolab/lablink-allocator-image:<your-image-tag>
docker run --rm -v "$(pwd)/lablink-infrastructure/config/config.yaml:/config/config.yaml:ro" \
  ghcr.io/talmolab/lablink-allocator-image:<your-image-tag> \
  lablink-validate-config /config/config.yaml --verbose
```

## REMOVED Requirements

- **Pip-Based Validation:** CI workflows no longer install lablink-allocator-service from PyPI. Removed because PyPI package may lag behind Docker image during development, causing version mismatches. Migration: All workflows now use Docker-based validation instead.
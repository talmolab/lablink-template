# CI Validation Specification

## Purpose

This specification defines CI validation requirements for configuration files using Docker-based validation.

## Requirements

### Requirement: Config Validation Uses Deployment Image
CI workflows SHALL validate configuration using the same allocator Docker image specified in config.yaml that will be deployed.

#### Scenario: Extract allocator image tag from config
- **GIVEN** a config.yaml file exists with `allocator.image_tag` field
- **WHEN** the CI validation workflow runs
- **THEN** it MUST extract the image tag value using:
```bash
IMAGE_TAG=$(grep -A5 "^allocator:" "$CONFIG_FILE" | grep "image_tag:" | awk '{print $2}' | tr -d '"')
```
- **AND** the workflow MUST fail if image_tag is not found

#### Scenario: Pull allocator Docker image
- **GIVEN** an allocator image tag has been extracted
- **WHEN** the validation workflow prepares to run validation
- **THEN** it MUST pull the Docker image from GitHub Container Registry:
```bash
docker pull ghcr.io/talmolab/lablink-allocator-image:${IMAGE_TAG}
```
- **AND** it MUST authenticate using GITHUB_TOKEN secret

#### Scenario: Run validator in Docker container
- **GIVEN** the allocator Docker image has been pulled
- **WHEN** the validation workflow runs the validator
- **THEN** it MUST run lablink-validate-config inside the Docker container:
```bash
docker run --rm \
  -v "$CONFIG_PATH:/config/config.yaml:ro" \
  "ghcr.io/talmolab/lablink-allocator-image:${IMAGE_TAG}" \
  lablink-validate-config /config/config.yaml --verbose
```
- **AND** the container MUST mount the config file as read-only
- **AND** the workflow MUST fail if validation returns non-zero exit code

#### Scenario: Validation with bleeding-edge commit
- **GIVEN** config.yaml specifies `image_tag: "linux-amd64-0d73aef91a90afe5289b2252fcde76aa1fd4e31f-test"`
- **WHEN** the validation workflow runs
- **THEN** it MUST pull and use that exact commit-based image
- **AND** validation MUST use the schema from that commit
- **AND** new schema features in that commit MUST be recognized as valid

#### Scenario: Validation with stable version
- **GIVEN** config.yaml specifies `image_tag: "linux-amd64-v1.2.3"`
- **WHEN** the validation workflow runs
- **THEN** it MUST pull and use that exact versioned image
- **AND** validation MUST use the schema from version 1.2.3

### Requirement: GitHub Container Registry Authentication
CI workflows SHALL authenticate to GitHub Container Registry before pulling allocator images.

#### Scenario: Docker login with GITHUB_TOKEN
- **GIVEN** the workflow is running in GitHub Actions
- **WHEN** the workflow prepares to pull Docker images
- **THEN** it MUST authenticate using:
```bash
echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
```
- **AND** login MUST complete before docker pull command

### Requirement: Validation Error Reporting
When validation fails, workflows SHALL provide clear instructions for local reproduction using Docker.

#### Scenario: Display Docker validation command on failure
- **GIVEN** config validation has failed
- **WHEN** the workflow reports the failure
- **THEN** it MUST display instructions including:
```bash
docker pull ghcr.io/talmolab/lablink-allocator-image:<your-image-tag>
docker run --rm -v "$(pwd)/lablink-infrastructure/config/config.yaml:/config/config.yaml:ro" \
  ghcr.io/talmolab/lablink-allocator-image:<your-image-tag> \
  lablink-validate-config /config/config.yaml --verbose
```
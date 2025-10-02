# LabLink Template Use Cases

This document helps you decide how to use this template based on your needs.

## Quick Decision Guide

### Allocator Image

**The allocator image is ALWAYS maintained by the LabLink team.**

- **Use**: `ghcr.io/talmolab/lablink-allocator-image:latest`
- **Why**: The allocator service code and dependencies are maintained separately
- **Customization**: Not available via this template (contribute to main repo instead)

### Client Base Image

**Should you build your own client image or use the maintained one?**

### ✅ Use Pre-Built Images (Recommended for Most Users)

**Use `ghcr.io/talmolab/lablink-client-base-image:latest` if you:**
- Want to get started quickly
- Don't need custom dependencies or system packages
- Want automatic updates and bug fixes
- Trust the maintained images
- Want less maintenance overhead

**How**: Simply reference the images in your config:
```yaml
# In lablink-allocator-service/conf/config.yaml
machine:
  image: "ghcr.io/talmolab/lablink-client-base-image:latest"
```

And use the allocator image directly without rebuilding.

### 🔧 Build Custom Client Image

**Build your own client image if you need:**
- Custom system dependencies or packages
- Organization-specific security requirements
- Private base images
- Version pinning to specific commits
- Modifications to the Docker build process
- To add proprietary software or tools

**How**: Use the provided Dockerfiles and GitHub Actions workflows to build your own versions.

## Detailed Use Cases

### Use Case 1: Standard Deployment (90% of users)

**Goal**: Deploy LabLink for your research software with minimal customization

**What to use:**
- ✅ Pre-built allocator image: `ghcr.io/talmolab/lablink-allocator-image:latest`
- ✅ Pre-built client image: `ghcr.io/talmolab/lablink-client-base-image:latest`
- ✅ Configuration files (config.yaml, .env, terraform.tfvars)
- ✅ GitHub Actions for infrastructure deployment only
- ❌ Don't modify client Dockerfile
- ❌ Don't run image build workflows

**Steps:**
1. Use this template
2. Configure `config.yaml` with your AWS settings and software name
3. Set environment variables in `.env`
4. Deploy infrastructure via GitHub Actions or Terraform

---

### Use Case 2: Custom Dependencies

**Goal**: You need additional Python packages, system libraries, or tools in the images

**What to use:**
- ✅ Pre-built allocator image (always)
- ✅ Modify client Dockerfile only
- ✅ Build custom client image via GitHub Actions
- ✅ Configuration files
- ✅ Reference YOUR custom client image in config.yaml

**Steps:**
1. Use this template
2. Modify `lablink-client-base/lablink-client-base-image/Dockerfile`
3. Update `config.yaml` to reference `ghcr.io/YOUR_ORG/lablink-client-base-image:latest`
4. Push changes to trigger client image build
5. Deploy infrastructure

**Example client Dockerfile modifications:**
```dockerfile
# In lablink-client-base/lablink-client-base-image/Dockerfile

# Add custom Python packages for your research software
RUN /opt/miniforge3/bin/conda install -y \
    your-analysis-package \
    custom-ml-library

# Add system dependencies
RUN apt-get update && apt-get install -y \
    specialized-gpu-driver \
    custom-visualization-tool
```

---

### Use Case 3: Private/Airgapped Environment

**Goal**: Deploy in environment without access to public container registries

**What to use:**
- ✅ Pre-built allocator image (or mirror it)
- ✅ Build and host client image in your private registry
- ✅ Modify client Dockerfile if needed
- ✅ Configuration files
- ❌ Can't use GitHub Actions (unless self-hosted runners)

**Steps:**
1. Use this template
2. (Optional) Mirror allocator image to your private registry
3. Build client image locally or in your CI/CD
4. Push to your private registry (e.g., AWS ECR, Azure ACR)
5. Update `config.yaml` with private registry URLs
6. Deploy infrastructure with appropriate registry credentials

---

### Use Case 4: Contributing Back to LabLink

**Goal**: You found a bug or want to improve the core images/packages

**What to do:**
- ❌ Don't modify this template repository
- ✅ Contribute to the main [LabLink repository](https://github.com/talmolab/lablink)
- ✅ Submit PRs for bug fixes or features
- ✅ Report issues on the main repo

This template is for **deployments**, not core development.

---

## Docker Image Maintenance Matrix

| Component | Maintained By | Can Customize? |
|-----------|---------------|----------------|
| **Allocator image** | LabLink team | ❌ No - use maintained version |
| **Client base image** | LabLink team | ✅ Yes - for custom dependencies |
| **Client Dockerfile** | Template (you) | ✅ Yes - modify as needed |
| **Infrastructure config** | Template (you) | ✅ Yes - always customize |
| **Python packages** | LabLink team | ❌ No - submit PRs instead |
| **Application code** | LabLink team | ❌ No - submit PRs instead |

## Image Build Workflow Decision Tree

```
Allocator Image:
└─ Always use ghcr.io/talmolab/lablink-allocator-image:latest
   (Not customizable via template)

Client Image:
Do you need custom dependencies not in the base client image?
├─ NO → Use ghcr.io/talmolab/lablink-client-base-image:latest
│       ├─ Disable/ignore image build workflow
│       └─ Focus on config.yaml customization
│
└─ YES → Build custom client image
        ├─ Modify lablink-client-base-image/Dockerfile
        ├─ Keep image build workflow enabled
        ├─ Push to YOUR registry
        └─ Reference YOUR client image in config.yaml
```

## Recommended Workflow by Org Type

### Academic Lab / Small Team
- **Use**: Pre-built images
- **Customize**: config.yaml only
- **Reason**: Focus on research, not infrastructure

### Enterprise / Large Org
- **Use**: Custom images (security requirements)
- **Customize**: Dockerfiles + config.yaml
- **Reason**: Compliance, audit trails, private registries

### Open Source Project
- **Use**: Pre-built images initially
- **Customize**: Fork if your software needs are different
- **Reason**: Contribute improvements back upstream

### Cloud Provider
- **Use**: Custom images
- **Customize**: Everything for your platform
- **Reason**: Integration with specific cloud services

## Getting Help

Still not sure which approach to use?

1. **Start simple**: Use pre-built images first
2. **Iterate**: Build custom images only when you hit limitations
3. **Ask**: Open an issue describing your use case

Remember: **You can always switch from pre-built to custom images later** if your needs change.

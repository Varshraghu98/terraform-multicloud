# Multi-Cloud Terraform: AWS, Azure, GCP

This repository contains three independent Terraform stacks:

- `aws-sql/`
- `azure-sql/`
- `gcp-sql/`

Each stack deploys networking + a VM for a Flask + MySQL style setup.

## Prerequisites

- Terraform `>= 1.0`
- Cloud CLI authentication configured for the provider you are deploying
- Permissions to create networking, security/firewall, and VM resources

Recommended Terraform workflow in each folder:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

To remove resources:

```bash
terraform destroy
```

## AWS (`aws-sql`)

### What it deploys

- VPC, public subnet, route table, internet gateway
- Security group
- EC2 instance (Ubuntu)
- S3 gateway VPC endpoint

### Required input

- `key_pair_name` (optional): existing EC2 key pair for SSH

### Run

```bash
cd aws-sql
terraform init
terraform plan
terraform apply
```

### Destroy

```bash
cd aws-sql
terraform destroy
```

## Azure (`azure-sql`)

### What it deploys

- VNet + subnet in `Germany West Central`
- Public IP
- Network Security Group + rules
- NIC + NSG association
- Linux VM (Ubuntu)

### Important notes

- `main.tf` currently uses a fixed `subscription_id` in the provider block.
- The resource group is looked up as an existing RG:
  - `azure-network-components`
- Ensure this resource group already exists in that subscription.

### Required input

- `vm_admin_password` (required, sensitive)

### Run

```bash
cd azure-sql
terraform init
terraform plan -var='vm_admin_password=REPLACE_WITH_STRONG_PASSWORD'
terraform apply -var='vm_admin_password=REPLACE_WITH_STRONG_PASSWORD'
```

### Destroy

```bash
cd azure-sql
terraform destroy -var='vm_admin_password=REPLACE_WITH_STRONG_PASSWORD'
```

## GCP (`gcp-sql`)

### What it deploys

- Custom mode VPC + subnet in `europe-west3`
- Firewall rules (SSH, HTTP, app port 5000, MySQL 3306, internal/ICMP)
- Compute Engine VM with external IP in `europe-west3-a`

### Required input

- `project_id` (required)

### Optional inputs

- `region` (default: `europe-west3`)
- `zone` (default: `europe-west3-a`)
- `network_name` (default: `application-deployment`)
- `subnet_name` (default: `application-deployment-subnet`)
- `instance_name` (default: `application-deployment-vm`)
- `ssh_source_ranges` (default: `["0.0.0.0/0"]`)

### Run

```bash
cd gcp-sql
terraform init
terraform plan -var='project_id=YOUR_GCP_PROJECT_ID'
terraform apply -var='project_id=YOUR_GCP_PROJECT_ID'
```

Example with restricted SSH source:

```bash
terraform plan \
  -var='project_id=YOUR_GCP_PROJECT_ID' \
  -var='ssh_source_ranges=["YOUR.PUBLIC.IP.ADDR/32"]'
```

### Destroy

```bash
cd gcp-sql
terraform destroy -var='project_id=YOUR_GCP_PROJECT_ID'
```

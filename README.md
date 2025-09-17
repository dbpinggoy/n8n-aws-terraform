# n8n on AWS with Terraform

This project deploys n8n (workflow automation tool) on AWS using Terraform, with a secure PostgreSQL RDS database backend.

## 🌐 **Domain & HTTPS Setup (Optional)**

You can deploy n8n with either:
- **IP-based access** (HTTP only) - Default, simpler setup
- **Domain-based access** (HTTPS with SSL certificate) - Production recommended

### **Option 1: IP-Based Access (Default)**
```bash
# Leave domain settings empty in terraform.tfvars
domain_name = ""
```
- Access via: `http://YOUR_EC2_IP:5678`
- No SSL certificate
- Good for development/testing

### **Option 2: Domain-Based Access with HTTPS**

#### **Prerequisites:**
- You own a domain name (e.g., `yourdomain.com`)
- Domain is either managed in Route 53 OR you can add DNS records manually

#### **Setup Steps:**

**Step 1: Configure domain in terraform.tfvars**
```bash
# For new domain (Terraform will create Route 53 hosted zone)
domain_name = "yourdomain.com"
subdomain = "n8n"
create_route53_zone = true

# For existing domain (you manage DNS elsewhere)
domain_name = "yourdomain.com" 
subdomain = "n8n"
create_route53_zone = false
```

**Step 2: Deploy infrastructure**
```bash
cd infra
terraform apply
```

**Step 3: Configure DNS**

**If `create_route53_zone = true`:**
- Get nameservers: `terraform output nameservers`
- Update your domain's nameservers at your registrar to point to Route 53

**If `create_route53_zone = false`:**
- Get ALB DNS: `terraform output load_balancer_dns`
- Create CNAME record: `n8n.yourdomain.com` → `ALB_DNS_NAME`

**Step 4: Access n8n**
- URL: `https://n8n.yourdomain.com`
- SSL certificate automatically provisioned by ACM
- HTTP requests automatically redirect to HTTPS

## Architecture

### **IP-Based Deployment:**
- **EC2 Instance**: Ubuntu LTS running n8n in Docker
- **RDS PostgreSQL**: Managed database in private subnets
- **VPC**: Custom VPC with public and private subnets
- **Security**: Database credentials stored in AWS Secrets Manager
- **Access**: Direct HTTP access to EC2 on port 5678

### **Domain-Based Deployment (with HTTPS):**
- **EC2 Instance**: Ubuntu LTS running n8n in Docker
- **RDS PostgreSQL**: Managed database in private subnets
- **Application Load Balancer**: HTTPS termination and traffic distribution
- **ACM Certificate**: Automatic SSL certificate provisioning
- **Route 53**: DNS management (optional)
- **VPC**: Custom VPC with public and private subnets
- **Security**: Database credentials in Secrets Manager, HTTPS encryption
- **Access**: HTTPS access via custom domain with automatic HTTP→HTTPS redirect

## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform installed** (version >= 1.0)
3. **SSH key pair** generated for n8n project

### Generate SSH Key Pair for n8n

**⚠️ Important**: We'll create a dedicated SSH key for this project to avoid overwriting existing keys.

```bash
# Create a dedicated SSH key for n8n (won't overwrite existing keys)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/n8n_key -C "n8n-project-key"

# When prompted:
# - Press Enter for no passphrase (or add one for extra security)
# - Confirm by pressing Enter again

# The files created will be:
# ~/.ssh/n8n_key      (private key - keep this secure!)
# ~/.ssh/n8n_key.pub  (public key - this goes to AWS)
```

**Benefits of dedicated SSH key:**
- ✅ Won't overwrite your existing `~/.ssh/id_rsa` key
- ✅ Easy to manage and revoke for this project only
- ✅ Can be shared with team members if needed
- ✅ Clear separation between different projects

**If you already have SSH keys** and want to use them instead:
```bash
# Check existing keys
ls -la ~/.ssh/

# To use existing key, update terraform.tfvars:
# ssh_public_key_path = "~/.ssh/id_rsa.pub"
```

## Project Structure

```
project/
├── infra/
│   ├── main.tf              # Provider and AMI data source
│   ├── variables.tf         # Input variables
│   ├── vpc.tf              # VPC, subnets, routing
│   ├── security_groups.tf  # Security groups for EC2 and RDS
│   ├── ec2.tf              # EC2 instance configuration
│   ├── rds.tf              # RDS PostgreSQL and secrets
│   └── outputs.tf          # Output values
├── scripts/
│   └── install_n8n.sh     # n8n installation script
└── README.md               # This file
```

## Quick Start

1. **Clone or create the project structure** with all the Terraform files

2. **Navigate to the infrastructure directory**:
   ```bash
   cd infra
   ```

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Find your public IP address** (recommended for security):
   ```bash
   # Method 1: Using curl
   curl ifconfig.me
   
   # Method 2: Using curl (alternative)
   curl ipinfo.io/ip
   
   # Method 3: Using dig
   dig +short myip.opendns.com @resolver1.opendns.com
   
   # Method 4: Check in browser
   # Visit: https://whatismyipaddress.com/
   ```

5. **Review and customize variables** (recommended):

   **For IP-based access (simpler):**
   ```bash
   cat > terraform.tfvars << EOF
   my_ip = "$(curl -s ifconfig.me)/32"
   aws_region = "us-east-1"
   project_name = "my-n8n-project"
   ssh_public_key_path = "~/.ssh/n8n_key.pub"
   domain_name = ""
   EOF
   ```

   **For domain-based access with HTTPS:**
   ```bash
   cat > terraform.tfvars << EOF
   my_ip = "$(curl -s ifconfig.me)/32"
   aws_region = "us-east-1"
   project_name = "my-n8n-project"
   ssh_public_key_path = "~/.ssh/n8n_key.pub"
   domain_name = "yourdomain.com"
   subdomain = "n8n"
   create_route53_zone = true
   EOF
   ```

5. **Plan the deployment**:
   ```bash
   terraform plan
   ```

6. **Deploy the infrastructure**:
   ```bash
   terraform apply
   ```

7. **Wait for deployment** (usually takes 5-10 minutes)

8. **Access n8n**:
   - URL will be shown in the Terraform output
   - Default credentials: `admin` / `changeme123!`
   - **IMPORTANT**: Change these credentials after first login!

## Configuration Options

### Variables (in `variables.tf`)

- `aws_region`: AWS region (default: us-east-1)
- `project_name`: Project name for resource naming
- `instance_type`: EC2 instance type (default: t3.micro)
- `db_instance_class`: RDS instance class (default: db.t3.micro)
- `my_ip`: Your IP address for SSH/web access (default: 0.0.0.0/0)

### Security Configuration

#### 🔒 **Important: Restrict IP Access**

By default, the configuration allows access from any IP (`0.0.0.0/0`). **This is not secure for production!**

**To find and set your IP address:**

```bash
# Find your public IP
MY_IP=$(curl -s ifconfig.me)
echo "Your public IP is: $MY_IP"

# Set it in terraform.tfvars
echo "my_ip = \"$MY_IP/32\"" >> terraform.tfvars
```

**Understanding IP notation:**
- `123.456.789.0/32` = Only your specific IP address
- `123.456.789.0/24` = Your IP range (256 addresses)  
- `0.0.0.0/0` = Any IP address (not recommended)

**Alternative ways to check your IP:**
```bash
# Command line options
curl ifconfig.me
curl ipinfo.io/ip  
dig +short myip.opendns.com @resolver1.opendns.com

# Or visit in browser: https://whatismyipaddress.com/
```

#### Production Security Checklist:

1. **Restrict IP access**: Set `my_ip` to your specific IP address
2. **Enable deletion protection**: Change `deletion_protection = true` in RDS
3. **Enable final snapshot**: Change `skip_final_snapshot = false` in RDS
4. **Use stronger passwords**: Modify the n8n basic auth credentials
5. **Enable HTTPS**: Configure SSL/TLS certificates

## 📁 **Workflow Management**

The installation includes a complete workflow management system:

### **Directory Structure**
```
/home/ubuntu/n8n/
├── config/
│   ├── workflows/     # Individual workflow JSON exports
│   ├── credentials/   # Credential exports (without secrets)
│   ├── backups/       # Full timestamped backups
│   └── templates/     # Workflow templates
├── logs/              # Application logs
└── Management Scripts:
    ├── backup_workflows.sh      # Backup all workflows
    ├── restore_workflows.sh     # Restore from backup
    ├── export_workflow.sh       # Export single workflow
    ├── import_workflow.sh       # Import single workflow
    └── setup_automated_backups.sh # Setup daily backups
```

### **Workflow Operations**

**Backup all workflows:**
```bash
ssh -i ~/.ssh/n8n_key ubuntu@YOUR_EC2_IP
cd /home/ubuntu/n8n
./backup_workflows.sh
```

**Export individual workflow:**
```bash
./export_workflow.sh "My Workflow Name"
./export_workflow.sh workflow_id_123
```

**Import workflow:**
```bash
./import_workflow.sh ./config/workflows/my_workflow.json
```

**Setup automated daily backups:**
```bash
./setup_automated_backups.sh
# Runs daily at 2 AM, keeps 7 days of backups
```

**Restore from backup:**
```bash
# List available backups
ls ./config/backups/

# Restore specific backup
./restore_workflows.sh 2024-01-24_10-30-00
```

## Managing the Infrastructure

### Viewing Outputs

```bash
terraform output
```

### SSH into EC2 Instance

```bash
# Using the dedicated n8n key (default)
terraform output ssh_command
# Or manually:
ssh -i ~/.ssh/n8n_key ubuntu@<PUBLIC_IP>

# If you're using existing SSH keys:
ssh -i ~/.ssh/id_rsa ubuntu@<PUBLIC_IP>
```

**SSH Key Management**:
```bash
# List your SSH keys
ls -la ~/.ssh/

# Add SSH key to SSH agent (optional, for convenience)
ssh-add ~/.ssh/n8n_key

# Test SSH connection
ssh -i ~/.ssh/n8n_key -o ConnectTimeout=5 ubuntu@<PUBLIC_IP>
```

### Managing n8n Service

Once connected to EC2:

```bash
# Check n8n status
systemctl status n8n

# View logs
cd /home/ubuntu/n8n
docker compose logs -f n8n

# Restart n8n
systemctl restart n8n

# Stop n8n
systemctl stop n8n
```

### Database Access

Database credentials are securely stored in AWS Secrets Manager. The EC2 instance automatically retrieves them using IAM roles.

To manually retrieve credentials (from EC2):
```bash
aws secretsmanager get-secret-value --secret-id <SECRET_ARN> --region <REGION>
```

## Troubleshooting

### n8n Not Starting

1. **Check service status**:
   ```bash
   systemctl status n8n
   ```

2. **Check Docker logs**:
   ```bash
   cd /home/ubuntu/n8n
   docker compose logs -f
   ```

3. **Verify database connectivity**:
   ```bash
   # Test from EC2
   pg_isready -h <RDS_ENDPOINT> -p 5432
   ```

### SSH Connection Issues

1. **Permission denied (publickey)**:
   ```bash
   # Check if key exists
   ls -la ~/.ssh/n8n_key*
   
   # Verify key permissions
   chmod 600 ~/.ssh/n8n_key
   chmod 644 ~/.ssh/n8n_key.pub
   
   # Test SSH connection
   ssh -i ~/.ssh/n8n_key -v ubuntu@<PUBLIC_IP>
   ```

2. **Using existing SSH keys**:
   ```bash
   # Update terraform.tfvars to use existing key
   echo 'ssh_public_key_path = "~/.ssh/id_rsa.pub"' >> terraform.tfvars
   terraform apply
   ```

3. **Key file not found**:
   ```bash
   # Generate the n8n key if missing
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/n8n_key -C "n8n-project-key"
   
   # Then re-run terraform apply
   terraform apply
   ```

### Connection Issues

1. **Can't access n8n web interface**:
   ```bash
   # Check if your IP changed
   curl ifconfig.me
   
   # If changed, update terraform.tfvars and re-apply
   echo "my_ip = \"$(curl -s ifconfig.me)/32\"" > terraform.tfvars
   terraform apply
   ```

2. **"Connection refused" or timeout errors**:
   - Verify your current IP: `curl ifconfig.me`
   - Check if it matches the `my_ip` variable in your terraform.tfvars
   - ISPs often change residential IPs daily/weekly

3. **SSH connection issues**:
   ```bash
   # Check current IP and update if needed
   terraform apply -var="my_ip=$(curl -s ifconfig.me)/32"
   ```

### Domain & SSL Issues

1. **Certificate not ready**:
   ```bash
   # Check certificate status
   cd infra
   terraform output certificate_arn
   aws acm describe-certificate --certificate-arn "$(terraform output -raw certificate_arn)" --query 'Certificate.Status'
   ```

2. **DNS not resolving**:
   ```bash
   # Check DNS propagation
   nslookup n8n.yourdomain.com
   
   # Check Route 53 records
   terraform output nameservers
   ```

3. **Load balancer health checks failing**:
   ```bash
   # Check target group health
   aws elbv2 describe-target-health --target-group-arn "$(aws elbv2 describe-target-groups --names my-n8n-project-tg --query 'TargetGroups[0].TargetGroupArn' --output text)"
   ```

4. **Switch from IP to domain (or vice versa)**:
   ```bash
   # Update terraform.tfvars with new domain settings
   terraform apply
   # Note: This will recreate some resources
   ```

### Cost Optimization

For development/testing:
- Use `t3.micro` instances (eligible for free tier)
- Stop EC2 instances when not in use
- Consider using RDS snapshots instead of always-on instances

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete all resources, including the database!

## Security Features

- Database credentials never stored in plain text
- RDS in private subnets (no direct internet access)
- Security groups restrict access to necessary ports only
- Encrypted EBS volumes and RDS storage
- IAM roles for secure service-to-service communication

## Customization

### Adding SSL/HTTPS

1. Modify security groups to allow port 443
2. Update the installation script to configure reverse proxy (nginx)
3. Use AWS Certificate Manager for SSL certificates

### Scaling

1. Increase instance sizes in `variables.tf`
2. Configure RDS read replicas for read scaling
3. Consider using Application Load Balancer for high availability

## Support

This implementation follows AWS and Terraform best practices for:
- Security (credentials management, network isolation)
- Reliability (encrypted storage, backups)
- Maintainability (modular structure, clear documentation)

For issues:
1. Check AWS CloudWatch logs
2. Review Terraform state and plans
3. Verify AWS permissions and quotas
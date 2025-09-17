# 🏗️ n8n Architecture Decisions & Trade-offs

## • **Orchestration: EC2 + Docker Compose**
**Choice:** Single EC2 instance with Docker Compose over ECS/Fargate/App Runner

**Rationale:** Lower operational overhead for single-instance deployment. ECS/Fargate adds complexity for minimal scaling benefits when n8n workflows are typically I/O bound rather than CPU intensive. EC2 provides direct control over systemd services, easier troubleshooting, and simpler backup/restore workflows. 

**Trade-off:** Manual scaling vs automatic, but n8n's architecture doesn't benefit significantly from horizontal scaling due to workflow state management.

## • **Database: PostgreSQL RDS vs SQLite**
**Choice:** PostgreSQL RDS over SQLite on EBS/EFS

**Rationale:** RDS provides automated backups, point-in-time recovery, automatic patching, and Multi-AZ failover capabilities. n8n's workflow execution history and credential storage benefit from ACID compliance and concurrent access patterns that PostgreSQL handles better than SQLite. Managed service reduces operational burden. 

**Trade-off:** Higher cost (~$12/month) vs SQLite's zero cost, but workflow durability and backup reliability justify the expense for production use.

## • **Networking & TLS: ALB + ACM + Public/Private Architecture**
**Choice:** Application Load Balancer with ACM certificates, n8n in public subnet, RDS in private subnets

**Rationale:** ALB provides SSL termination, health checks, and future scaling capabilities. ACM certificates auto-renew and integrate seamlessly. Public subnet for n8n enables direct internet access for webhook integrations while private subnets for RDS ensure database security. Alternative NAT Gateway approach would cost $45/month extra for minimal security benefit. 

**Trade-off:** Direct public access vs full private architecture, balanced with security groups providing adequate protection.

## • **Security & IAM: Secrets Manager + Identity Center + Least Privilege**
**Choice:** AWS Secrets Manager for database credentials, IAM Identity Center for human access, least-privilege EC2 role

**Rationale:** Secrets Manager eliminates hardcoded credentials and provides automatic rotation capabilities. Identity Center follows AWS 2024 best practices for human user access with temporary sessions and MFA support. EC2 instance role limited to Secrets Manager read-only access. Viewer access policy scoped to specific services (EC2, RDS, VPC, CloudWatch) rather than broad ReadOnlyAccess. 

**Trade-off:** Slight complexity increase vs security posture improvement, but modern identity management justifies the approach.

## • **Resilience: Single-AZ + Auto-restart vs Multi-AZ**
**Choice:** Single-AZ deployment with systemd auto-restart and health checks

**Rationale:** For cost-conscious deployment, single-AZ provides 99.5% availability vs 99.95% for Multi-AZ at 2x the cost. n8n's workflow retry mechanisms and webhook resilience handle brief outages gracefully. ALB health checks ensure quick detection of failures, systemd provides automatic container restart. 

**Trade-off:** ~4 hours additional downtime per year vs $25+ monthly savings. Multi-AZ RDS available as upgrade path when budget allows.

## • **Operational Features: Comprehensive Backup + Monitoring**
**Choice:** Multiple backup strategies, comprehensive logging, systemd service management

**Implementation:** Automated daily workflow backups with 7-day retention, RDS automated backups with point-in-time recovery, CloudWatch integration for application logs, systemd service for automatic startup/restart. Includes workflow import/export scripts, manual and automated backup restoration procedures. 

**Trade-off:** Storage costs for comprehensive backups vs operational confidence and disaster recovery capabilities.

## • **Development Experience: Infrastructure as Code + Documentation**
**Choice:** Complete Terraform automation with optional manual configurations

**Rationale:** Terraform provides reproducible deployments, version control, and easy environment management. Comprehensive documentation supports both automated (Terraform) and manual (Console) setup approaches. Identity Center setup via console acknowledges AWS's limited Terraform support for modern identity features while maintaining infrastructure automation for core components. Includes troubleshooting guides and production upgrade path documentation.

---

## 📋 **Testing & Production Readiness**

### **Testing Instructions**
- Deploy with IP-based access first, add HTTPS domain later
- Test workflow creation, execution, and backup/restore procedures  
- Verify viewer access permissions and security boundaries
- Load test webhook handling and database connection pooling

### **Known Trade-offs**
- **Single-AZ reduces availability** but controls costs (~$31/month vs $60+/month)
- **Public subnet deployment** vs full private architecture balances security with simplicity
- **Manual scaling** vs auto-scaling reflects n8n's typical usage patterns

### **Production Enhancements**
- **Enable Multi-AZ RDS deployment** (+$12/month for 99.95% availability)
- **Implement CloudWatch alarms** and SNS notifications for monitoring
- **Add WAF protection** and rate limiting via ALB rules  
- **Configure automated SSL certificate rotation** monitoring
- **Implement blue/green deployment strategy** for zero-downtime updates

---

## 💰 **Cost Analysis**

### **Current Architecture**
| Component | Monthly Cost | Justification |
|-----------|-------------|---------------|
| EC2 t3.micro | $7.59 | Sufficient for moderate workflow loads |
| RDS db.t3.micro | $12.41 | Managed database with automated backups |
| ALB | $16.20 | SSL termination and health checks |
| Route 53 + ACM | $0.50 | Professional domain with auto-renewing SSL |
| **Total** | **~$37/month** | **Cost-effective production setup** |

### **Cost Optimization Options**
- **Development use**: Stop instances when not needed (~65% savings)
- **Remove ALB**: Use IP-based access (-$16.20/month, lose HTTPS)
- **SQLite alternative**: Remove RDS (-$12.41/month, lose backups/reliability)

### **Scaling Costs**
- **Multi-AZ RDS**: +$12/month (99.95% availability)
- **Larger instances**: t3.small doubles cost, t3.medium quadruples
- **Additional environments**: ~$35/month per environment

---

## 🔒 **Security Model**

### **Network Security**
- **Public subnet**: n8n accessible via ALB only
- **Private subnets**: RDS isolated from internet
- **Security groups**: Least-privilege port access
- **No NAT Gateway**: Cost optimization, outbound via IGW

### **Identity & Access**
- **IAM Identity Center**: Modern user access with MFA
- **Temporary sessions**: 8-hour maximum, automatic expiry
- **Least privilege**: Viewer access scoped to relevant services
- **No long-lived keys**: Eliminates credential rotation burden

### **Data Protection**
- **Encryption at rest**: EBS and RDS storage encrypted
- **Encryption in transit**: HTTPS/TLS for all connections
- **Secrets management**: Database credentials in Secrets Manager
- **Backup encryption**: All backup data encrypted

---

## 🚀 **Deployment Patterns**

### **Development Workflow**
1. **Deploy core infrastructure** with Terraform
2. **Add domain and HTTPS** after testing
3. **Configure user access** via Identity Center
4. **Test workflow operations** and backup procedures

### **Production Migration**
1. **Enable Multi-AZ RDS** for high availability
2. **Implement monitoring** and alerting
3. **Add rate limiting** and security headers
4. **Configure automated backups** and testing

### **Disaster Recovery**
1. **RDS automated backups**: Point-in-time recovery up to 7 days
2. **Workflow exports**: Daily automated backups with retention
3. **Infrastructure as Code**: Complete environment recreation via Terraform
4. **Runbook documentation**: Step-by-step recovery procedures

This architecture balances cost, security, and operational simplicity while providing clear upgrade paths for production scale requirements.
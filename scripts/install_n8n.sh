#!/bin/bash

# n8n Installation Script with All Fixes Applied
# This script installs Docker and sets up n8n with PostgreSQL connection
# Includes all troubleshooting fixes discovered during deployment

set -e

# Log all output
exec 1> >(tee -a /var/log/n8n-install.log)
exec 2> >(tee -a /var/log/n8n-install.log >&2)

echo "=== n8n Installation Started at $(date) ==="

# Update system
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install Docker
echo "Installing Docker..."
apt-get install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install AWS CLI v2
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

# Install additional tools
echo "Installing additional tools..."
apt-get install -y jq postgresql-client

# Create n8n directory
mkdir -p /home/ubuntu/n8n
chown ubuntu:ubuntu /home/ubuntu/n8n

# Create script to get database credentials from Secrets Manager
echo "Creating database credentials script..."
cat > /home/ubuntu/n8n/get_db_credentials.sh << 'EOF'
#!/bin/bash
SECRET_ARN="${secret_arn}"
REGION="${aws_region}"

echo "Getting database credentials from AWS Secrets Manager..."
echo "Secret ARN: $SECRET_ARN"
echo "Region: $REGION"

# Get secret value with retries
for i in {1..5}; do
    echo "Attempt $i: Getting secret from AWS Secrets Manager..."
    SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --region $REGION --query SecretString --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$SECRET_VALUE" ]; then
        echo "✅ Successfully retrieved secret"
        break
    else
        echo "⏳ Failed to get secret, retrying in 10 seconds..."
        sleep 10
    fi
    
    if [ $i -eq 5 ]; then
        echo "❌ Failed to get secret after 5 attempts"
        exit 1
    fi
done

# Parse JSON to get username and password
DB_USER=$(echo $SECRET_VALUE | jq -r '.username')
DB_PASS=$(echo $SECRET_VALUE | jq -r '.password')

if [ "$DB_USER" = "null" ] || [ "$DB_PASS" = "null" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo "❌ Failed to parse database credentials"
    exit 1
fi

# Set database connection details (IMPORTANT: Remove any port from hostname)
DB_HOST_CLEAN="${db_host}"
DB_HOST_CLEAN=$${DB_HOST_CLEAN%:*}  # Remove anything after : including port

# Export as environment variables
export DB_POSTGRESDB_USER="$DB_USER"
export DB_POSTGRESDB_PASSWORD="$DB_PASS"
export DB_POSTGRESDB_HOST="$DB_HOST_CLEAN"
export DB_POSTGRESDB_DATABASE="${db_name}"

echo "Database connection configured successfully:"
echo "Host: $DB_POSTGRESDB_HOST"
echo "Database: $DB_POSTGRESDB_DATABASE"
echo "User: $DB_USER"
EOF

chown ubuntu:ubuntu /home/ubuntu/n8n/get_db_credentials.sh
chmod +x /home/ubuntu/n8n/get_db_credentials.sh

# Create docker-compose.yml for n8n with all fixes
echo "Creating Docker Compose configuration..."
cat > /home/ubuntu/n8n/docker-compose.yml << 'EOF'
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=changeme123!
      - N8N_SECURE_COOKIE=${domain_configured}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=$${DB_POSTGRESDB_HOST}
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=$${DB_POSTGRESDB_DATABASE}
      - DB_POSTGRESDB_USER=$${DB_POSTGRESDB_USER}
      - DB_POSTGRESDB_PASSWORD=$${DB_POSTGRESDB_PASSWORD}
      - DB_POSTGRESDB_SSL_ENABLED=true
      - DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=${n8n_protocol}
      - N8N_EDITOR_BASE_URL=${n8n_editor_base_url}
      - WEBHOOK_URL=${webhook_url}
      - NODE_ENV=production
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
EOF

chown ubuntu:ubuntu /home/ubuntu/n8n/docker-compose.yml

# Create startup script with database waiting logic
echo "Creating startup script..."
cat > /home/ubuntu/n8n/start_n8n.sh << 'EOF'
#!/bin/bash
cd /home/ubuntu/n8n

echo "Starting n8n startup process..."

# Source database credentials
source ./get_db_credentials.sh

# Wait for database to be ready
echo "Waiting for database to be ready..."
for i in {1..30}; do
    echo "[$i/30] Testing database connection to $DB_POSTGRESDB_HOST..."
    
    if pg_isready -h $DB_POSTGRESDB_HOST -p 5432 -t 10 >/dev/null 2>&1; then
        echo "✅ Database is accepting connections!"
        
        # Test actual login
        if PGPASSWORD=$DB_POSTGRESDB_PASSWORD psql -h $DB_POSTGRESDB_HOST -U $DB_POSTGRESDB_USER -d $DB_POSTGRESDB_DATABASE -c "SELECT version();" > /dev/null 2>&1; then
            echo "✅ Database login successful!"
            break
        else
            echo "⏳ Database not ready for login, waiting..."
        fi
    else
        echo "⏳ Database not accepting connections, waiting 20 seconds..."
    fi
    
    sleep 20
    
    if [ $i -eq 30 ]; then
        echo "❌ Database not ready after 10 minutes. Check RDS status."
        echo "Attempting to start n8n anyway (it will retry connection)..."
        break
    fi
done

# Start n8n with Docker Compose
echo "Starting n8n with Docker Compose..."
docker compose up -d

echo "n8n startup initiated!"
echo "Access n8n at: ${n8n_editor_base_url}"
echo "Default credentials: admin / changeme123!"
echo ""
echo "To check logs: docker compose logs -f n8n"
echo "To stop: docker compose down"
echo "To restart: docker compose restart n8n"
EOF

chown ubuntu:ubuntu /home/ubuntu/n8n/start_n8n.sh
chmod +x /home/ubuntu/n8n/start_n8n.sh

# Create systemd service for n8n
echo "Creating systemd service..."
cat > /etc/systemd/system/n8n.service << 'EOF'
[Unit]
Description=n8n Workflow Automation
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=ubuntu
WorkingDirectory=/home/ubuntu/n8n
ExecStart=/home/ubuntu/n8n/start_n8n.sh
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
systemctl daemon-reload
systemctl enable n8n.service

# Wait for RDS to be ready before starting n8n
echo "Waiting for RDS to be fully ready before starting n8n..."
sleep 90

# Test database connection before starting service
echo "Testing database connection..."
cd /home/ubuntu/n8n
source ./get_db_credentials.sh

# Give final status
if pg_isready -h $DB_POSTGRESDB_HOST -p 5432 -t 30 >/dev/null 2>&1; then
    echo "✅ Database is ready! Starting n8n service..."
    systemctl start n8n.service
    
    # Wait and check status
    sleep 30
    if systemctl is-active --quiet n8n; then
        echo "✅ n8n service started successfully!"
    else
        echo "⚠️  n8n service may still be starting. Check logs: journalctl -u n8n -f"
    fi
else
    echo "⚠️  Database not ready yet. n8n service will start automatically."
    echo "   Monitor with: journalctl -u n8n -f"
    systemctl start n8n.service
fi

# Create a helpful info file
cat > /home/ubuntu/n8n/README.txt << EOF
n8n Installation Complete!

Access n8n at: ${n8n_editor_base_url}

Default login credentials:
- Username: admin
- Password: changeme123!

IMPORTANT: Change these credentials after first login!

Useful commands:
- Check n8n status: systemctl status n8n
- View n8n logs: docker compose logs -f n8n
- View service logs: journalctl -u n8n -f
- Restart n8n: systemctl restart n8n
- Stop n8n: systemctl stop n8n
- Test database: cd /home/ubuntu/n8n && source ./get_db_credentials.sh && pg_isready -h \$DB_POSTGRESDB_HOST -p 5432

Troubleshooting:
- If n8n won't start, check: journalctl -u n8n -f
- Database connection issues: ./get_db_credentials.sh
- Check installation logs: tail -f /var/log/n8n-install.log

Files location:
- Configuration: /home/ubuntu/n8n/
- Data volume: n8n_data (managed by Docker)
- Logs: /var/log/n8n-install.log
EOF

chown ubuntu:ubuntu /home/ubuntu/n8n/README.txt

echo "=== n8n Installation Completed Successfully at $(date) ==="
echo "Installation log saved to: /var/log/n8n-install.log"
echo "n8n will be available at: ${n8n_editor_base_url}"
#!/bin/bash

# Step 1: Update the System
sudo apt-get update -y && sudo apt-get upgrade -y

# Step 2: Install Python and Required Libraries
sudo apt-get install -y python3-pip python3-dev python3-venv libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev -y

# Step 3: Install NPM and CSS plugins
sudo apt-get install -y npm
sudo ln -s /usr/bin/nodejs /usr/bin/node
sudo npm install -g less less-plugin-clean-css
sudo apt-get install -y node-less

# Step 4: Install Wkhtmltopdf
sudo wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.bionic_amd64.deb
sudo dpkg -i wkhtmltox_0.12.6-1.bionic_amd64.deb
sudo apt install -f

# Step 5: Install PostgreSQL
sudo apt-get install postgresql -y
sudo systemctl start postgresql && sudo systemctl enable postgresql
sudo systemctl status postgresql

# Step 6: Create Odoo and PostgreSQL users
sudo read -sp "Enter Odoo and PostgreSQL password: " ODOO_PG_PASSWORD
echo ""
sudo useradd -m -U -r -d /opt/odoo17 -s /bin/bash odoo17
echo "odoo17:$ODOO_PG_PASSWORD" | sudo chpasswd
sudo su - postgres -c "psql -c \"CREATE USER odoo17 WITH PASSWORD '$ODOO_PG_PASSWORD';\""

# Step 7: Install and Configure Odoo 17
su - odoo17 << EOF
git clone https://www.github.com/odoo/odoo --depth 1 --branch 17.0 /opt/odoo17/odoo17
cd /opt/odoo17
python3 -m venv odoo17-venv
source odoo17-venv/bin/activate
pip install --upgrade pip
pip3 install wheel
pip3 install -r odoo17/requirements.txt
deactivate
mkdir /opt/odoo17/odoo17-custom-addons
chown -R odoo17:odoo17 /opt/odoo17/odoo17-custom-addons
sudo mkdir -p /var/log/odoo17
sudo touch /var/log/odoo17.log
sudo chown -R odoo17:odoo17 /var/log/odoo17
EOF

# Step 8: Create Odoo 17 configuration file
sudo touch /etc/odoo17.conf
read -sp "Enter Odoo admin password: " ODOO_ADMIN_PASSWORD
echo ""
sudo cat << EOF | sudo tee -a /etc/odoo17.conf
[options]
admin_passwd = $ODOO_ADMIN_PASSWORD
db_host = False
db_port = False
db_user = odoo17
db_password = $ODOO_PG_PASSWORD
xmlrpc_port = 8069
logfile = /var/log/odoo17/odoo17.log
addons_path = /opt/odoo17/odoo17/addons,/opt/odoo17/odoo17-custom-addons 
EOF

# Step 9: Create an Odoo systemd unit file
sudo touch /etc/systemd/system/odoo17.service
sudo cat << EOF | sudo tee -a /etc/systemd/system/odoo17.service
[Unit]
Description=odoo17
After=network.target postgresql@14-main.service

[Service]
Type=simple
SyslogIdentifier=odoo17
PermissionsStartOnly=true
User=odoo17
Group=odoo17
ExecStart=/opt/odoo17/odoo17-venv/bin/python3 /opt/odoo17/odoo17/odoo-bin -c /etc/odoo17.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start odoo17 && sudo systemctl enable odoo17
sudo systemctl status odoo17

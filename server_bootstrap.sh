#!/bin/bash
set -e

# Ensure we are running as root
check_root() {
if [ "$USER" != "root" ]; then
      echo "Permission Denied"
      echo "Can only be run by root"
      exit
fi
}

# Add Servers.do public key for management
add-public-key() {
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC99t/T2d0gczP7LNWiGGlPF9eI0H7266GqATimigceSGGl7Sm5j40S65PLFVseig4mfKy1e3zl9br169uiS/3kVoX44yC8U0Bd7c7sgbyKiS6lVZB07zlLhHpSJf2qSRQqL2A6OBPQfrm7QsKjKwCCCdFOWlNVW/voMGIvJZTvaJ01pB8uBlLdEQdbufz1qA1H8MW+SwgsWXSmwZrB4o2GIP8OnnM9uOW1aFcO6jyukXUy29SlNFVhNDYSAUT1nAT3owGctWHnclWZYQtoBhD1yI8EZ6p7k9amQy6+qCceTIXrytx+sR6lswardFI+LN91LexbTEFfVXhRjeJCO5Dh root@ns519458" >> ~/.ssh/authorized_keys
}

# Update apps
apt-get-update() {
	sudo apt-get update
}

# Disable password-based SSH authentication
disable-password-authentication() {
	# Disable password authentication
	sudo grep -q "ChallengeResponseAuthentication" /etc/ssh/sshd_config && sed -i "/^[^#]*ChallengeResponseAuthentication[[:space:]]yes.*/c\ChallengeResponseAuthentication no" /etc/ssh/sshd_config || echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
	sudo grep -q "^[^#]*PasswordAuthentication" /etc/ssh/sshd_config && sed -i "/^[^#]*PasswordAuthentication[[:space:]]yes/c\PasswordAuthentication no" /etc/ssh/sshd_config || echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
	/etc/init.d/ssh reload
}

# Get Dokku if not already installed
install-dokku() {
    if ! command -v dokku &> /dev/null
    then
        wget https://raw.githubusercontent.com/dokku/dokku/v0.26.6/bootstrap.sh;
        sudo DOKKU_TAG=v0.26.6 bash bootstrap.sh
    fi
}

# Check that dokku is installed on the server
ensure-dokku() {
  if ! command -v dokku &> /dev/null
  then
      echo "dokku is not installed"
      exit
  fi
}

# Create a keys file if one does not already exist
create-keys-file() {
	mkdir -p ~/.ssh
	touch ~/.ssh/authorized_keys
}

# Install UFW
install-firewall() {
	apt-get install ufw
	ufw enable && sudo ufw allow www && sudo ufw allow https
	(yes | sudo ufw allow ssh)
	sudo ufw status
}

# Install Fail2Ban
install-fail2ban() {
    sudo apt-get install fail2ban -y
    cd /etc/fail2ban/

    wget https://gist.githubusercontent.com/petarGitNik/e24f9bfda6e1277640e376f8a2ecfaef/raw/a58d7983260e73a45668c2774e16122ccf4fc5f4/http-get-dos.conf
    wget https://gist.githubusercontent.com/petarGitNik/e24f9bfda6e1277640e376f8a2ecfaef/raw/a58d7983260e73a45668c2774e16122ccf4fc5f4/http-post-dos.conf
    wget https://gist.githubusercontent.com/petarGitNik/e24f9bfda6e1277640e376f8a2ecfaef/raw/a58d7983260e73a45668c2774e16122ccf4fc5f4/jail.local
    cd ~

    if command -v fail2ban &> /dev/null
    then
        sudo systemctl restart fail2ban
        # sudo fail2ban-client status
    fi
}

# Make directories for db import/export
make-dirs() {
    cd ~
    mkdir dumps
    cd dumps
    mkdir postgres
    mkdir mysql
    mkdir redis
    mkdir mongo
    cd ~
}

# Check if dokku redis plugin is intalled and otherwise install it
install-redis() {
  if sudo dokku plugin:installed redis; then
    echo "=> Redis plugin already installed skipping"
  else
    echo "=> Installing redis plugin"
    sudo dokku plugin:install https://github.com/dokku/dokku-redis.git redis
  fi
}

# Check if dokku postgres plugin is intalled and otherwise install it
install-postgres() {
  if sudo dokku plugin:installed postgres; then
    echo "=> Postgres plugin already installed skipping"
  else
    echo "=> Installing postgres plugin"
    sudo dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres
  fi
}

# Check if dokku MySQL plugin is intalled and otherwise install it
install-mysql() {
  if sudo dokku plugin:installed mysql; then
    echo "=> Postgres plugin already installed skipping"
  else
    echo "=> Installing mysql plugin"
    sudo dokku plugin:install https://github.com/dokku/dokku-mysql.git mysql
  fi
}

# Check if dokku mongo plugin is intalled and otherwise install it
install-mongo() {
  if sudo dokku plugin:installed mongo; then
    echo "=> Postgres plugin already installed skipping"
  else
    echo "=> Installing mongo plugin"
    sudo dokku plugin:install https://github.com/dokku/dokku-mongo.git mongo
  fi
}

# Check if dokku memcached plugin is intalled and otherwise install it
install-memcached() {
  if sudo dokku plugin:installed memcached; then
    echo "=> Memcached plugin already installed skipping"
  else
    echo "=> Installing memcached plugin"
    sudo dokku plugin:install https://github.com/dokku/dokku-memcached.git memcached
  fi
}

# Install Letsencrypt plugin
install-letsencrypt() {
	sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
	dokku letsencrypt:cron-job --add
}

# Install custom dokku limited users plugin
install-limited-users() {
	sudo dokku plugin:install https://github.com/kidGodzilla/dokku-limited-users.git
}


main() {
  check_root

  # Get user ip and export to environment variable
  DOKKU_SSH_HOST=$(curl ifconfig.co)
  SERVER_IP=$(curl ipinfo.io/ip)

  # Basics
  apt-get-update
  install-firewall

  # Add access key
  create-keys-file
  add-public-key

  # Hardening
  disable-password-authentication

  # Install Dokku
  install-dokku
  make-dirs

  # Ensure dokku was installed
  ensure-dokku

  # dokku databases & plugins
  install-redis
  install-postgres
  install-mysql
  install-mongo
  install-letsencrypt
  install-limited-users

  # install-fail2ban
}

main

#!/bin/bash
set -euo pipefail

LOG_DIR="/var/log/oracle-install"
LOG_FILE="${LOG_DIR}/01-preinstall.log"
mkdir -p "${LOG_DIR}"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Iniciando pré-instalação Oracle Database 26ai ==="

# --------------------------------------------------
# 1. Atualização básica e pacotes auxiliares
# --------------------------------------------------
echo ">>> Instalando pacotes auxiliares..."
dnf -y install wget curl unzip tar

# --------------------------------------------------
# 2. Instalação do preinstall package
# --------------------------------------------------
echo ">>> Instalando oracle-ai-database-preinstall-26ai..."
dnf -y install oracle-ai-database-preinstall-26ai.x86_64

# --------------------------------------------------
# 3. Definição da senha do usuário oracle
#    (valor injetado pelo Terraform / remote-exec)
# --------------------------------------------------
if [ -z "${ORACLE_OS_PASSWORD:-}" ]; then
  echo "ERRO: variável ORACLE_OS_PASSWORD não definida."
  exit 1
fi

echo ">>> Definindo senha do usuário oracle..."
usermod -p "${ORACLE_OS_PASSWORD_HASH}" oracle

# --------------------------------------------------
# 4. Firewall
# --------------------------------------------------
echo ">>> Desabilitando firewalld..."
systemctl stop firewalld || true
systemctl disable firewalld || true

# --------------------------------------------------
# 5. SELinux
# --------------------------------------------------
echo ">>> Desabilitando SELinux..."
if [ -f /etc/selinux/config ]; then
  sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
fi
setenforce 0 || true

# --------------------------------------------------
# 6. Clock source (recomendado para VMs x86-64)
# --------------------------------------------------
echo ">>> Configurando clocksource tsc..."
if [ -w /sys/devices/system/clocksource/clocksource0/current_clocksource ]; then
  echo "tsc" > /sys/devices/system/clocksource/clocksource0/current_clocksource || true
fi

# --------------------------------------------------
# 7. Diretórios ORACLE_BASE / ORACLE_HOME
# --------------------------------------------------
ORACLE_HOME_VERSION="${ORACLE_HOME_VERSION:-23.26.1}"
ORACLE_HOME_DIR="/u01/app/oracle/product/${ORACLE_HOME_VERSION}/dbhome_1"

echo ">>> Criando estrutura de diretórios Oracle em ${ORACLE_HOME_DIR}..."
mkdir -p "${ORACLE_HOME_DIR}"
mkdir -p /u01/app/oracle/oradata
mkdir -p /u01/app/oracle/fast_recovery_area
mkdir -p /u01/app/oraInventory

chown -R oracle:oinstall /u01
chmod -R 775 /u01

# --------------------------------------------------
# 8. Diretório de trabalho para scripts do usuário oracle
# --------------------------------------------------
echo ">>> Preparando /home/oracle/scripts..."
mkdir -p /home/oracle/scripts
chown -R oracle:oinstall /home/oracle/scripts
chmod 775 /home/oracle/scripts

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Pré-instalação concluída com sucesso ===" | tee -a "$LOG_FILE"

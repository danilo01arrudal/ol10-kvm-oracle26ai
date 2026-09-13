#!/bin/bash
set -euo pipefail

LOG_DIR="/var/log/oracle-install"
LOG_FILE="${LOG_DIR}/03-install-software.log"
mkdir -p "${LOG_DIR}"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Iniciando instalação do software Oracle Database 26ai ==="

# --------------------------------------------------
# Variáveis (injetadas pelo Terraform / remote-exec)
# --------------------------------------------------
ORACLE_HOME_VERSION="${ORACLE_HOME_VERSION:-23.26.1}"
ORACLE_SID="${ORACLE_SID:-appscdb}"
ORACLE_HOSTNAME="${ORACLE_HOSTNAME:-$(hostname -f)}"

ORACLE_BASE="/u01/app/oracle"
ORACLE_HOME="${ORACLE_BASE}/product/${ORACLE_HOME_VERSION}/dbhome_1"
ORA_INVENTORY="/u01/app/oraInventory"

RESPONSE_DIR="/tmp/oracle-install/response"
DB_INSTALL_RSP="${RESPONSE_DIR}/db_install.rsp"

# --------------------------------------------------
# 1. Validações iniciais
# --------------------------------------------------
if [ ! -d "${ORACLE_HOME}" ]; then
  echo "ERRO: ORACLE_HOME não encontrado em ${ORACLE_HOME}"
  echo "Execute antes o 02-copy-software.sh"
  exit 1
fi

if [ ! -x "${ORACLE_HOME}/runInstaller" ]; then
  echo "ERRO: runInstaller não encontrado ou sem permissão de execução em ${ORACLE_HOME}"
  exit 1
fi

if [ ! -f "${DB_INSTALL_RSP}" ]; then
  echo "ERRO: response file não encontrado em ${DB_INSTALL_RSP}"
  echo "Certifique-se de que o Terraform gerou/copiou db_install.rsp"
  exit 1
fi

if ! id oracle &>/dev/null; then
  echo "ERRO: usuário oracle não existe. Execute antes o 01-preinstall.sh"
  exit 1
fi

# --------------------------------------------------
# 2. Garante ownership antes do runInstaller
# --------------------------------------------------
echo ">>> Ajustando ownership de /u01 para oracle:oinstall..."
chown -R oracle:oinstall /u01
chmod -R 775 /u01

# --------------------------------------------------
# 3. Executa runInstaller em modo silent (usuário oracle)
# --------------------------------------------------
echo ">>> Executando runInstaller em modo silent (ignorando pré-requisitos de swap/sistema)..."
su - oracle -c "cd '${ORACLE_HOME}' && ./runInstaller -silent -waitforcompletion -ignorePrereqFailure -responseFile '${DB_INSTALL_RSP}'" || true

# --------------------------------------------------
# 4. Aguarda estabilização e executa scripts root obrigatórios
# --------------------------------------------------
echo ">>> Aguardando 30 segundos para estabilização do ambiente..."
sleep 30

echo ">>> Executando orainstRoot.sh..."
if [ -x "${ORA_INVENTORY}/orainstRoot.sh" ]; then
  "${ORA_INVENTORY}/orainstRoot.sh"
else
  echo "ERRO: ${ORA_INVENTORY}/orainstRoot.sh não encontrado"
  exit 1
fi

echo ">>> Executando root.sh..."
if [ -x "${ORACLE_HOME}/root.sh" ]; then
  "${ORACLE_HOME}/root.sh"
else
  echo "ERRO: ${ORACLE_HOME}/root.sh não encontrado em ${ORACLE_HOME}"
  exit 1
fi

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Instalação do software Oracle concluída com sucesso ===" | tee -a "$LOG_FILE"

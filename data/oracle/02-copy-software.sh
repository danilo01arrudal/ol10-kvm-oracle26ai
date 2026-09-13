#!/bin/bash
set -euo pipefail

LOG_DIR="/var/log/oracle-install"
LOG_FILE="${LOG_DIR}/02-copy-software.log"
mkdir -p "${LOG_DIR}"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Iniciando cópia/descompactação do software Oracle Database 26ai ==="

# --------------------------------------------------
# Variáveis (injetadas pelo Terraform / remote-exec)
# --------------------------------------------------
ORACLE_HOME_VERSION="${ORACLE_HOME_VERSION:-23.26.1}"
ORACLE_SID="${ORACLE_SID:-appscdb}"
ORACLE_SOFTWARE_ZIP="${ORACLE_SOFTWARE_ZIP:-V1054592-01.zip}"

ORACLE_BASE="/u01/app/oracle"
ORACLE_HOME="${ORACLE_BASE}/product/${ORACLE_HOME_VERSION}/dbhome_1"

# Origem: arquivo já transferido pelo Terraform para a VM
SOURCE_DIR="/tmp/oracle-install/sfw/"
SOURCE_ZIP="${SOURCE_DIR}/${ORACLE_SOFTWARE_ZIP}"

# --------------------------------------------------
# 1. Validações iniciais
# --------------------------------------------------
if [ ! -f "${SOURCE_ZIP}" ]; then
  echo "ERRO: arquivo de software não encontrado em ${SOURCE_ZIP}"
  echo "Certifique-se de que o Terraform copiou o zip para /tmp/oracle-install/"
  exit 1
fi

if ! id oracle &>/dev/null; then
  echo "ERRO: usuário oracle não existe. Execute antes o 01-preinstall.sh"
  exit 1
fi

# --------------------------------------------------
# 2. Garante estrutura de diretórios
# --------------------------------------------------
echo ">>> Garantindo diretórios ORACLE_BASE/ORACLE_HOME..."
mkdir -p "${ORACLE_HOME}"
mkdir -p "${ORACLE_BASE}/oradata"
mkdir -p "${ORACLE_BASE}/fast_recovery_area"
mkdir -p /u01/app/oraInventory

chown -R oracle:oinstall /u01
chmod -R 775 /u01

# --------------------------------------------------
# 3. Copia o zip para o ORACLE_HOME
# --------------------------------------------------
echo ">>> Copiando ${ORACLE_SOFTWARE_ZIP} para ${ORACLE_HOME}..."
cp -f "${SOURCE_ZIP}" "${ORACLE_HOME}/"
chown oracle:oinstall "${ORACLE_HOME}/${ORACLE_SOFTWARE_ZIP}"

# --------------------------------------------------
# 4. Descompacta o software como usuário oracle
# --------------------------------------------------
echo ">>> Descompactando software Oracle em ${ORACLE_HOME}..."
su - oracle -c "cd '${ORACLE_HOME}' && unzip -o '${ORACLE_SOFTWARE_ZIP}'"

# --------------------------------------------------
# 5. Remove o zip após descompactar
# --------------------------------------------------
echo ">>> Removendo arquivo zip após descompactação..."
rm -f "${ORACLE_HOME}/${ORACLE_SOFTWARE_ZIP}"

# --------------------------------------------------
# 6. Ajuste final de permissões
# --------------------------------------------------
echo ">>> Ajustando ownership final de /u01..."
chown -R oracle:oinstall /u01
chmod -R 775 /u01

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Cópia e descompactação do software concluídas com sucesso ===" | tee -a "$LOG_FILE"

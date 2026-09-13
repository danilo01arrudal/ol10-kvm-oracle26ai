#!/bin/bash
set -euo pipefail

LOG_DIR="/var/log/oracle-install"
LOG_FILE="${LOG_DIR}/04-create-database.log"
mkdir -p "${LOG_DIR}"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Iniciando criação do banco Oracle Database 26ai ==="

# --------------------------------------------------
# Variáveis (injetadas pelo Terraform / remote-exec)
# --------------------------------------------------
ORACLE_HOME_VERSION="${ORACLE_HOME_VERSION:-23.26.1}"
ORACLE_SID="${ORACLE_SID:-appscdb}"
ORACLE_UNQNAME="${ORACLE_UNQNAME:-${ORACLE_SID}}"
PDB_NAME="${PDB_NAME:-appspdb1}"
ORACLE_HOSTNAME="${ORACLE_HOSTNAME:-$(hostname -f)}"

ORACLE_BASE="/u01/app/oracle"
ORACLE_HOME="${ORACLE_BASE}/product/${ORACLE_HOME_VERSION}/dbhome_1"
ORA_INVENTORY="/u01/app/oraInventory"

RESPONSE_DIR="/tmp/oracle-install/response"
DBCA_RSP="${RESPONSE_DIR}/dbca.rsp"
NETCA_RSP="${RESPONSE_DIR}/netca.rsp"

# --------------------------------------------------
# 1. Validações iniciais
# --------------------------------------------------
if [ -z "${SYS_PASSWORD:-}" ]; then
  echo "ERRO: variável SYS_PASSWORD não definida."
  exit 1
fi

if [ -z "${SYSTEM_PASSWORD:-}" ]; then
  echo "ERRO: variável SYSTEM_PASSWORD não definida."
  exit 1
fi

if [ -z "${PDBADMIN_PASSWORD:-}" ]; then
  echo "ERRO: variável PDBADMIN_PASSWORD não definida."
  exit 1
fi

if [ ! -d "${ORACLE_HOME}" ]; then
  echo "ERRO: ORACLE_HOME não encontrado em ${ORACLE_HOME}"
  echo "Execute antes o 03-install-software.sh"
  exit 1
fi

if [ ! -x "${ORACLE_HOME}/bin/dbca" ]; then
  echo "ERRO: dbca não encontrado em ${ORACLE_HOME}/bin"
  exit 1
fi

if [ ! -x "${ORACLE_HOME}/bin/netca" ]; then
  echo "ERRO: netca não encontrado em ${ORACLE_HOME}/bin"
  exit 1
fi

if [ ! -f "${DBCA_RSP}" ]; then
  echo "ERRO: response file não encontrado em ${DBCA_RSP}"
  exit 1
fi

if [ ! -f "${NETCA_RSP}" ]; then
  echo "ERRO: response file não encontrado em ${NETCA_RSP}"
  exit 1
fi

if ! id oracle &>/dev/null; then
  echo "ERRO: usuário oracle não existe. Execute antes o 01-preinstall.sh"
  exit 1
fi

# --------------------------------------------------
# 2. Garante scripts de ambiente do usuário oracle
# --------------------------------------------------
echo ">>> Preparando scripts de ambiente do usuário oracle..."
mkdir -p /home/oracle/scripts

if [ -f /tmp/oracle-install/scripts/setEnv.sh ]; then
  cp -f /tmp/oracle-install/scripts/setEnv.sh /home/oracle/scripts/setEnv.sh
fi

if [ -f /tmp/oracle-install/scripts/start_all.sh ]; then
  cp -f /tmp/oracle-install/scripts/start_all.sh /home/oracle/scripts/start_all.sh
fi

if [ -f /tmp/oracle-install/scripts/stop_all.sh ]; then
  cp -f /tmp/oracle-install/scripts/stop_all.sh /home/oracle/scripts/stop_all.sh
fi

chown -R oracle:oinstall /home/oracle/scripts
chmod u+x /home/oracle/scripts/*.sh || true

# Garante carga do ambiente no login do oracle
if [ -f /home/oracle/scripts/setEnv.sh ]; then
  if ! grep -q "setEnv.sh" /home/oracle/.bash_profile 2>/dev/null; then
    echo ". /home/oracle/scripts/setEnv.sh" >> /home/oracle/.bash_profile
  fi
  chown oracle:oinstall /home/oracle/.bash_profile
fi

# --------------------------------------------------
# 3. Copia response files para o home do oracle
# --------------------------------------------------
echo ">>> Copiando response files para /home/oracle..."
cp -f "${DBCA_RSP:-/tmp/oracle-install/response/dbca.rsp}" /home/oracle/dbca.rsp
cp -f "${NETCA_RSP:-/tmp/oracle-install/response/netca.rsp}" /home/oracle/netca.rsp
chown oracle:oinstall /home/oracle/dbca.rsp /home/oracle/netca.rsp
chmod 600 /home/oracle/dbca.rsp /home/oracle/netca.rsp

# --------------------------------------------------
# 4. Configura HugePages (conforme procedimento)
# --------------------------------------------------
echo ">>> Configurando HugePages..."
SYSCTL_FILE="/etc/sysctl.d/99-oracle-ai-database-preinstall-26ai-sysctl.conf"
if [ -f "${SYSCTL_FILE}" ]; then
  if grep -q '^vm.nr_hugepages' "${SYSCTL_FILE}"; then
    sed -i 's/^vm.nr_hugepages.*/vm.nr_hugepages = 2560/' "${SYSCTL_FILE}"
  else
    echo "vm.nr_hugepages = 2560" >> "${SYSCTL_FILE}"
  fi
else
  cat > "${SYSCTL_FILE}" <<'EOF'
# oracle-ai-database-preinstall-26ai for vm.nr_hugepages is 2560
vm.nr_hugepages = 2560
# oracle-ai-database-preinstall-26ai setting special parameters END
EOF
fi

sysctl -p "${SYSCTL_FILE}" || true
echo "HugePages_Total atual:" | tee -a "${LOG_FILE}"
grep HugePages_Total /proc/meminfo | tee -a "${LOG_FILE}" || true

# --------------------------------------------------
# 5. Cria o banco com DBCA (usuário oracle)
# --------------------------------------------------
echo ">>> Executando DBCA em modo silent..."
su - oracle -c "dbca -silent -createDatabase -responseFile /home/oracle/dbca.rsp"

# --------------------------------------------------
# 6. Cria o listener com NETCA (usuário oracle)
# --------------------------------------------------
echo ">>> Executando NETCA em modo silent..."
su - oracle -c "netca -silent -responsefile /home/oracle/netca.rsp"

# --------------------------------------------------
# 7. Configura oratab para autostart
# --------------------------------------------------
echo ">>> Configurando /etc/oratab..."
if [ -f /etc/oratab ]; then
  if grep -q "^${ORACLE_SID:-appscdb}:" /etc/oratab; then
    sed -i "s|^${ORACLE_SID:-appscdb}:.*|${ORACLE_SID:-appscdb}:${ORACLE_HOME}:Y|" /etc/oratab
  else
    echo "${ORACLE_SID:-appscdb}:${ORACLE_HOME}:Y" >> /etc/oratab
  fi
fi

# --------------------------------------------------
# 8. Habilita autostart do PDB (best effort)
# --------------------------------------------------
echo ">>> Habilitando abertura automática do PDB ${PDB_NAME:-appspdb1}..."
su - oracle -c "sqlplus -s / as sysdba <<'SQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
ALTER PLUGGABLE DATABASE ${PDB_NAME:-appspdb1} SAVE STATE;
EXIT;
SQL" || echo "AVISO: não foi possível salvar o estado do PDB agora."

# --------------------------------------------------
# 9. Status final
# --------------------------------------------------
echo ">>> Start do listener:"
su - oracle -c "lsnrctl start" || true

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Criação do banco Oracle concluída com sucesso ===" | tee -a "${LOG_FILE}"

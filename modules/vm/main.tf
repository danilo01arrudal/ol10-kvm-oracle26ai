# Geração do arquivo kickstart a partir do template
resource "local_file" "ks" {
  content = templatefile("${path.module}/templates/ks.cfg.tpl", {
    ip                 = var.ip
    gateway            = var.gateway
    netmask            = var.netmask
    dns                = var.dns
    hostname           = var.hostname
    disk_size_mb       = var.disk_size_mb
    root_size_mb       = local.root_size_mb
    swap_size_mb       = var.swap_size_mb
    timezone           = var.timezone
    root_password_hash = var.root_password_hash
    user_name          = var.user_name
    user_password_hash = var.user_password_hash
    ssh_public_key       = var.ssh_public_key
    ssh_private_key_path = var.ssh_private_key_path
  })
  filename = "${path.module}/../../data/kickstart/${local.ks_filename}"
}

# Script de start da VM (versão robusta - espera até shut off)
resource "local_file" "start_vm_script" {
  content = <<-EOT
#!/bin/bash
set -e

VM_NAME="${var.name}"
LOG_DIR="${path.module}/../../data/logs"
LOG_FILE="$LOG_DIR/start-$VM_NAME.log"
mkdir -p "$LOG_DIR"

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Iniciando monitoramento da VM $VM_NAME ===" | tee -a "$LOG_FILE"

# --------------------------------------------------
# 1. Aguarda a VM aparecer no libvirt
# --------------------------------------------------
echo "Aguardando VM aparecer no libvirt..." | tee -a "$LOG_FILE"
for i in $(seq 1 60); do
  if virsh dominfo "$VM_NAME" &>/dev/null; then
    echo "VM $VM_NAME encontrada." | tee -a "$LOG_FILE"
    break
  fi
  echo "  Tentativa $i/60 - VM ainda não existe..." | tee -a "$LOG_FILE"
  sleep 10
done

if ! virsh dominfo "$VM_NAME" &>/dev/null; then
  echo "ERRO: Timeout - VM $VM_NAME não foi criada." | tee -a "$LOG_FILE"
  exit 1
fi

# --------------------------------------------------
# 2. Loop principal: espera até a VM ficar "shut off"
# --------------------------------------------------
echo "Monitorando estado da VM até ela ficar 'shut off'..." | tee -a "$LOG_FILE"
echo "(Isso pode levar de 10 a 40 minutos dependendo do hardware)" | tee -a "$LOG_FILE"

MAX_ATTEMPTS=180
ATTEMPT=0

while true; do
  ATTEMPT=$((ATTEMPT + 1))
  STATE=$(virsh domstate "$VM_NAME" 2>/dev/null || echo "unknown")

  echo "[$(date '+%H:%M:%S')] Estado atual: $STATE (tentativa $ATTEMPT/$MAX_ATTEMPTS)" | tee -a "$LOG_FILE"

  if [ "$STATE" = "shut off" ]; then
    echo ">>> VM entrou em estado 'shut off'. Instalação concluída." | tee -a "$LOG_FILE"
    break
  fi

  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "ERRO: Timeout esperando a VM ficar 'shut off'." | tee -a "$LOG_FILE"
    echo "Estado final: $STATE" | tee -a "$LOG_FILE"
    exit 1
  fi

  sleep 15
done

# --------------------------------------------------
# 3. Segurança + start
# --------------------------------------------------
echo "Aguardando 15 segundos de segurança antes de iniciar..." | tee -a "$LOG_FILE"
sleep 15

echo "Iniciando VM $VM_NAME..." | tee -a "$LOG_FILE"
virsh start "$VM_NAME"

sleep 8
FINAL_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null || echo "unknown")

if [ "$FINAL_STATE" = "running" ]; then
  echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] SUCESSO: VM $VM_NAME está running ===" | tee -a "$LOG_FILE"
  exit 0
else
  echo "ERRO: Falha ao iniciar a VM. Estado final: $FINAL_STATE" | tee -a "$LOG_FILE"
  exit 1
fi
EOT

  filename        = "${path.module}/../../data/scripts/start-vm-${var.name}.sh"
  file_permission = "0755"
}

# Response files Oracle (senhas via templatefile)
resource "local_file" "db_install_rsp" {
  content = templatefile("${path.module}/../../data/oracle/response/db_install.rsp.tpl", {
    oracle_home_version = var.oracle_home_version
  })
  filename        = "${path.module}/../../data/oracle/response/db_install-${var.name}.rsp"
  file_permission = "0600"
}

resource "local_file" "dbca_rsp" {
  content = templatefile("${path.module}/../../data/oracle/response/dbca.rsp.tpl", {
    db_sid              = var.db_sid
    pdb_name            = var.pdb_name
    oracle_home_version = var.oracle_home_version
    sys_password        = var.sys_password
    system_password     = var.system_password
    pdbadmin_password   = var.pdbadmin_password
    dbsnmp_password     = var.dbsnmp_password != "" ? var.dbsnmp_password : var.system_password
  })
  filename        = "${path.module}/../../data/oracle/response/dbca-${var.name}.rsp"
  file_permission = "0600"
}

resource "local_file" "netca_rsp" {
  content = templatefile("${path.module}/../../data/oracle/response/netca.rsp.tpl", {
    hostname = var.hostname
  })
  filename        = "${path.module}/../../data/oracle/response/netca-${var.name}.rsp"
  file_permission = "0600"
}

resource "local_file" "setenv_sh" {
  content = templatefile("${path.module}/../../data/oracle/scripts/setEnv.sh.tpl", {
    hostname            = var.hostname
    db_sid              = var.db_sid
    oracle_home_version = var.oracle_home_version
  })
  filename        = "${path.module}/../../data/oracle/scripts/setEnv-${var.name}.sh"
  file_permission = "0644"
}

# Recurso principal que executa o virt-install
resource "null_resource" "vm" {
  triggers = {
    vm_name      = var.name
    memory       = var.memory
    vcpus        = var.vcpus
    disk_path    = var.disk_path
    disk_size_gb = var.disk_size_gb
    iso_path     = var.iso_path
    ip           = var.ip
    network      = var.network
    ks_filename  = local.ks_filename
    ks_content   = local_file.ks.content
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      LOG_DIR="${path.module}/../../data/logs"
      LOG_FILE="$LOG_DIR/install-${self.triggers.vm_name}.log"
      mkdir -p "$LOG_DIR"

      echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Iniciando provisionamento da VM ${self.triggers.vm_name} ===" | tee "$LOG_FILE"

      mkdir -p "$(dirname ${self.triggers.disk_path})"
      rm -f "${self.triggers.disk_path}"

      if virt-install \
        --virt-type kvm \
        --name "${self.triggers.vm_name}" \
        --memory "${self.triggers.memory}" \
        --vcpus "${self.triggers.vcpus}" \
        --os-variant ol8.10 \
        --location "${self.triggers.iso_path}" \
        --network "network=${self.triggers.network},model=virtio" \
        --disk "path=${self.triggers.disk_path},size=${self.triggers.disk_size_gb}" \
        --initrd-inject "${local_file.ks.filename}" \
        --extra-args "inst.ks=file:/${self.triggers.ks_filename} console=tty0 console=ttyS0,115200" \
        --noautoconsole >> "$LOG_FILE" 2>&1; then

        echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] VM ${self.triggers.vm_name} disparada com sucesso. ===" | tee -a "$LOG_FILE"
      else
        EXIT_CODE=$?
        echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] ERRO FATAL: Falha ao executar virt-install (Exit code $EXIT_CODE). ===" | tee -a "$LOG_FILE"
        echo "Consulte os detalhes do erro em: $LOG_FILE" >&2
        exit $EXIT_CODE
      fi
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "Destruindo VM ${self.triggers.vm_name}..."
      virsh destroy ${self.triggers.vm_name} 2>/dev/null || true
      virsh undefine ${self.triggers.vm_name} --remove-all-storage 2>/dev/null || true
      rm -f ${self.triggers.disk_path}
      echo "VM removida."
    EOT
  }
}

# ============================================================
# Aguarda a instalação do SO e inicia a VM
# ============================================================
resource "null_resource" "start_vm" {
  depends_on = [
    null_resource.vm,
    local_file.start_vm_script
  ]

  triggers = {
    vm_name = var.name
    script  = local_file.start_vm_script.content
  }

  provisioner "local-exec" {
    command = local_file.start_vm_script.filename
  }
}

# ============================================================
# Aguarda SSH na VM (host → guest)
# ============================================================
resource "null_resource" "wait_for_ssh" {
  depends_on = [null_resource.start_vm]

  triggers = {
    ip        = var.ip
    user_name = var.user_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      KEY="${pathexpand(var.ssh_private_key_path)}"
      USER="${var.user_name}"
      HOST="${var.ip}"

      echo "Aguardando SSH em $USER@$HOST ..."
      for i in $(seq 1 90); do
        if ssh -i "$KEY" \
             -o StrictHostKeyChecking=no \
             -o UserKnownHostsFile=/dev/null \
             -o BatchMode=yes \
             -o ConnectTimeout=5 \
             "$USER@$HOST" "echo ok" 2>/dev/null; then
          echo "SSH OK"
          exit 0
        fi
        echo "  tentativa $i/90..."
        sleep 10
      done
      echo "Timeout aguardando SSH" >&2
      exit 1
    EOT
  }
}

# ============================================================
# Cópia de artefatos + instalação Oracle Database 26ai na VM
# ============================================================
resource "null_resource" "install_oracle" {
  depends_on = [
    null_resource.wait_for_ssh,
    local_file.db_install_rsp,
    local_file.dbca_rsp,
    local_file.netca_rsp,
    local_file.setenv_sh,
  ]

  triggers = {
    vm_name             = var.name
    ip                  = var.ip
    db_sid              = var.db_sid
    pdb_name            = var.pdb_name
    oracle_home_version = var.oracle_home_version
    oracle_software_zip = var.oracle_software_zip
    db_install_rsp      = local_file.db_install_rsp.content
    dbca_rsp            = local_file.dbca_rsp.content
    netca_rsp           = local_file.netca_rsp.content
  }

  connection {
    type        = "ssh"
    host        = var.ip
    user        = var.user_name
    private_key = file(pathexpand(var.ssh_private_key_path))
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/oracle-install/sfw /tmp/oracle-install/response /tmp/oracle-install/scripts /tmp/oracle-install/bin",
    ]
  }

  # Software Oracle (host → VM)
  provisioner "file" {
    source      = "${path.root}/oracle_database/sfw/${var.oracle_software_zip}"
    destination = "/tmp/oracle-install/sfw/${var.oracle_software_zip}"
  }

  # Scripts de instalação
  provisioner "file" {
    source      = "${path.module}/../../data/oracle/01-preinstall.sh"
    destination = "/tmp/oracle-install/bin/01-preinstall.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../../data/oracle/02-copy-software.sh"
    destination = "/tmp/oracle-install/bin/02-copy-software.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../../data/oracle/03-install-software.sh"
    destination = "/tmp/oracle-install/bin/03-install-software.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../../data/oracle/04-create-database.sh"
    destination = "/tmp/oracle-install/bin/04-create-database.sh"
  }

  # Response files já renderizados
  provisioner "file" {
    source      = local_file.db_install_rsp.filename
    destination = "/tmp/oracle-install/response/db_install.rsp"
  }

  provisioner "file" {
    source      = local_file.dbca_rsp.filename
    destination = "/tmp/oracle-install/response/dbca.rsp"
  }

  provisioner "file" {
    source      = local_file.netca_rsp.filename
    destination = "/tmp/oracle-install/response/netca.rsp"
  }

  # Scripts de ambiente Oracle
  provisioner "file" {
    source      = local_file.setenv_sh.filename
    destination = "/tmp/oracle-install/scripts/setEnv.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../../data/oracle/scripts/start_all.sh"
    destination = "/tmp/oracle-install/scripts/start_all.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../../data/oracle/scripts/stop_all.sh"
    destination = "/tmp/oracle-install/scripts/stop_all.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/oracle-install/bin/*.sh /tmp/oracle-install/scripts/*.sh || true",
      
      # 01-preinstall.sh (usa a senha do SO do usuário oracle se aplicável)
      "sudo -E ORACLE_OS_PASSWORD='${var.oracle_password}' ORACLE_HOME_VERSION='${var.oracle_home_version}' ORACLE_SID='${var.db_sid}' ORACLE_HOSTNAME='${var.hostname}' bash /tmp/oracle-install/bin/01-preinstall.sh",
      
      # 02-copy-software.sh
      "sudo -E ORACLE_HOME_VERSION='${var.oracle_home_version}' ORACLE_SOFTWARE_ZIP='${var.oracle_software_zip}' bash /tmp/oracle-install/bin/02-copy-software.sh",
      
      # 03-install-software.sh
      "sudo -E ORACLE_HOME_VERSION='${var.oracle_home_version}' bash /tmp/oracle-install/bin/03-install-software.sh",
      
      # 04-create-database.sh (agora recebendo todas as credenciais e parâmetros mapeados)
      "sudo -E ORACLE_HOME_VERSION='${var.oracle_home_version}' ORACLE_SID='${var.db_sid}' PDB_NAME='${var.pdb_name}' ORACLE_HOSTNAME='${var.hostname}' SYS_PASSWORD='${var.sys_password}' SYSTEM_PASSWORD='${var.system_password}' PDBADMIN_PASSWORD='${var.pdbadmin_password}' DBSNMP_PASSWORD='${var.dbsnmp_password}' bash /tmp/oracle-install/bin/04-create-database.sh",
    ]
  }
}

variable "name" {
  description = "Nome da VM"
  type        = string
}

variable "memory" {
  description = "Memória RAM em MB"
  type        = number
}

variable "vcpus" {
  description = "Número de vCPUs"
  type        = number
}

variable "disk_size_gb" {
  description = "Tamanho do disco em GB (usado pelo virt-install)"
  type        = number
}

variable "disk_size_mb" {
  description = "Tamanho do disco em MB (usado no particionamento do kickstart)"
  type        = number
}

variable "swap_size_mb" {
  description = "Tamanho da partição swap em MB"
  type        = number
}

variable "ip" {
  description = "Endereço IP estático"
  type        = string
}

variable "gateway" {
  description = "Gateway da rede"
  type        = string
}

variable "netmask" {
  description = "Máscara de rede"
  type        = string
}

variable "dns" {
  description = "Servidor DNS"
  type        = string
}

variable "hostname" {
  description = "Hostname da VM"
  type        = string
}

variable "iso_path" {
  description = "Caminho para a ISO de instalação"
  type        = string
}

variable "disk_path" {
  description = "Caminho onde o disco da VM será criado"
  type        = string
}

variable "network" {
  description = "Rede libvirt a ser usada"
  type        = string
  default     = "default"
}

variable "timezone" {
  description = "Fuso horário"
  type        = string
  default     = "America/Fortaleza"
}

variable "root_password_hash" {
  description = "Hash da senha do root (gerado com openssl passwd -6)"
  type        = string
  sensitive   = true
}

variable "user_name" {
  description = "Nome do usuário não-root (SSH)"
  type        = string
}

variable "user_password_hash" {
  description = "Hash da senha do usuário"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Chave pública SSH injetada no kickstart"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Caminho da chave privada no host"
  type        = string
  default     = ".ssh/ol8-kvm-terraform"
}

# ============================================================
# Oracle Database 26ai
# ============================================================

variable "oracle_password" {
  description = "Senha do usuário sistema operacional oracle"
  type        = string
  sensitive   = true
}

variable "sys_password" {
  description = "Senha do usuário SYS"
  type        = string
  sensitive   = true
}

variable "system_password" {
  description = "Senha do usuário SYSTEM"
  type        = string
  sensitive   = true
}

variable "pdbadmin_password" {
  description = "Senha do usuário PDBADMIN"
  type        = string
  sensitive   = true
}

variable "dbsnmp_password" {
  description = "Senha do usuário DBSNMP (opcional; se vazio, usa system_password no template)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_sid" {
  description = "ORACLE_SID / nome do CDB"
  type        = string
  default     = "appscdb"
}

variable "pdb_name" {
  description = "Nome do PDB"
  type        = string
  default     = "appspdb1"
}

variable "oracle_home_version" {
  description = "Versão no path do ORACLE_HOME (ex: 23.26.1)"
  type        = string
  default     = "23.26.1"
}

variable "oracle_software_zip" {
  description = "Nome do zip em oracle_database/sfw/"
  type        = string
  default     = "V1054592-01.zip"
}

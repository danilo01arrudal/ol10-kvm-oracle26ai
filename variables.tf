variable "environment" {
  description = "Ambiente (dev, hom, prd)"
  type        = string
  default     = "dev"
}

variable "vm_config" {
  description = "Configurações da VM"
  type = object({
    name               = string
    memory             = number
    vcpus              = number
    disk_size_gb       = number
    disk_size_mb       = number
    swap_size_mb       = number
    ip                 = string
    gateway            = string
    netmask            = string
    dns                = string
    hostname           = string
    iso_path           = string
    disk_path          = string
    network            = string
    timezone           = string
    root_password_hash = string
    user_name          = string
    user_password_hash = string
  })
}

# ============================================================
# SSH (chave entre host Terraform e a VM)
# ============================================================
variable "ssh_public_key" {
  description = "Chave pública SSH injetada no usuário da VM via kickstart"
  type        = string
}

variable "ssh_private_key_path" {
  type    = string
  default = ".ssh/ol8-kvm-terraform"
}

variable "ssh_public_key_path" {
  type    = string
  default = ".ssh/ol8-kvm-terraform.pub"
}

# ============================================================
# Oracle Database 26ai
# ============================================================
variable "oracle_password_hash" {
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
  description = "Senha do usuário DBSNMP"
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
  description = "Versão usada no caminho do ORACLE_HOME (ex: 23.26.1)"
  type        = string
  default     = "23.26.1"
}

variable "oracle_software_zip" {
  description = "Nome do arquivo zip do software Oracle Database"
  type        = string
  default     = "V1054592-01.zip"
}


# Expressões locais para simplificar e reutilizar valores
locals {
  full_vm_name         = "${var.environment}-${var.vm_config.name}"
  ssh_private_key_path = pathexpand(var.ssh_private_key_path)
  ssh_public_key_path  = pathexpand(var.ssh_public_key_path)
  # Se var.ssh_public_key tiver valor usa ele; caso contrário, lê direto do arquivo .pub
  ssh_public_key = var.ssh_public_key != null && var.ssh_public_key != "" ? var.ssh_public_key : trimspace(file(local.ssh_public_key_path))
}

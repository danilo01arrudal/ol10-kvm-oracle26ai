# Expressões locais para simplificar e reutilizar valores
locals {
  # Exemplo: concatenar nome do ambiente com nome da VM
  full_vm_name = "${var.environment}-${var.vm_config.name}"
  ssh_private_key_path = pathexpand(var.ssh_private_key_path)
  ssh_public_key       = trimspace(file(local.ssh_private_key_path != "" ? pathexpand(var.ssh_public_key_path) : "/dev/null"))
}

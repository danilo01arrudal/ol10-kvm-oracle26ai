# Provisionamento Automatizado de VMs Oracle Linux 8.10 com Terraform em ambiente on-premisse servidor KVM Oracle Linux 10 Instalando o Oracle Database 26ai e a ferrramenta Flyway possibilitando a execucao de scripts de deploy de schema de forma automatica.

[![GitHub](https://img.shields.io/badge/Repository-danilo01arrudal/ol10--kvm--oracle26ai--flyway-blue?logo=github)](https://github.com/danilo01arrudal/ol10-kvm-oracle26ai-flyway)
[![Terraform](https://img.shields.io/badge/Terraform-≥1.5-purple?logo=terraform)](https://www.terraform.io/)
[![Oracle Linux](https://img.shields.io/badge/Oracle%20Linux-8.10%20%2B%2010-red?logo=oracle)](https://www.oracle.com/linux/)
[![Oracle Database](https://img.shields.io/badge/Oracle%20Database-26ai%20EE-orange?logo=oracle)](https://www.oracle.com/database/)
[![Flyway](https://img.shields.io/badge/Flyway-Migration-green?logo=flyway)](https://flywaydb.org/)
[![KVM](https://img.shields.io/badge/KVM-libvirt-blue?logo=qemu)](https://www.linux-kvm.org/)

## Visão Geral

Este projeto automatiza, de ponta a ponta, a criação de uma máquina virtual Oracle Linux 8.10 em ambiente KVM/libvirt (host Oracle Linux 10) e, após a instalação do sistema operacional, realiza:

1. Criação da VM **Oracle Linux 8.10** no KVM  
1. Instalação do **Oracle Database 26ai Enterprise Edition** (via RPM)
2. Criação de um banco de dados (CDB + PDB)
3. Instalação do **Flyway**
4. Execução automática de scripts de migration (ex.: schema **HR**)

Tudo isso controlado pelo Terraform, de forma **reprodutível**, **configurável** e **desassistida**.

### Objetivos principais

- **Reprodutível**: todo o processo (OS + Database + Flyway) é descrito como código.
- **Automatizado**: instalação do SO via Kickstart + pós-instalação via scripts remotos.
- **Modular**: lógica de VM isolada em módulo reutilizável.
- **Extensível**: fácil adicionar novos schemas ou migrations via Flyway.
- **Integrável**: pode ser usado em pipelines CI/CD.

<img width="1408" height="768" alt="image" src="https://github.com/danilo01arrudal/ol10-kvm-oracle26ai-flyway/blob/main/images/0001.png" />

## Principais Funcionalidades

| Funcionalidade                        | Descrição                                                                 |
|---------------------------------------|---------------------------------------------------------------------------|
| Criação automatizada de VMs           | Provisiona VMs KVM com `virt-install`                                     |
| Instalação desassistida do SO         | Kickstart gerado dinamicamente a partir de template                       |
| Rede estática                         | IP, gateway, máscara e DNS configuráveis                                  |
| Particionamento flexível              | LVM com volumes root e swap parametrizados                                |
| Instalação Oracle Database 26ai EE    | Via script de criação de banco (CDB + PDB)                          |
| Instalação e configuração do Flyway   | Download + configuração automática                                        |
| Deploy de schema via Flyway           | Execução de migrations (exemplo: schema HR)                               |
| Ciclo de vida completo                | `terraform apply` / `terraform destroy`                                   |
| Segurança                             | Senhas com hash SHA-512 + suporte a chave SSH                             |
| Separação por ambiente                | Diretórios `dev` / `hom` / `prd`                                          |

## Fluxo de Execução

```
1. terraform apply
   ├── Gera Kickstart
   ├── Cria VM com virt-install (instalação OL 8.10)
   ├── Aguarda reboot + SSH disponível
   ├── Copia scripts e artefatos (RPM, Flyway, migrations)
   ├── Instala oracle-ai-database-preinstall-26ai + RPM 26ai EE
   ├── Cria banco de dados (CDB + PDB)
   ├── Instala e configura Flyway
   └── Executa flyway migrate (schema HR)
2. VM pronta para uso com Oracle Database + schema HR
```

## 🗂️ Estrutura do Projeto

```plaintext
ol10-kvm-oracle26ai-flyway/
├── data
│   ├── kickstart
│   │   └── .gitkeep
│   ├── logs
│   │   ├── install-ol8-prd.log
│   │   └── start-ol8-prd.log
│   ├── oracle
│   │   ├── 01-preinstall.sh
│   │   ├── 02-copy-software.sh
│   │   ├── 03-install-software.sh
│   │   ├── 04-create-database.sh
│   │   ├── response
│   │   │   ├── dbca.rsp.tpl
│   │   │   ├── db_install.rsp.tpl
│   │   │   └── netca.rsp.tpl
│   │   └── scripts
│   │       ├── setEnv.sh.tpl
│   │       ├── start_all.sh
│   │       └── stop_all.sh
│   └── scripts
│       └── generate-hash.sh
├── docs
│   ├── architecture.md
│   └── troubleshooting.md
├── environments
│   ├── dev
│   │   └── terraform.tfvars.example
│   ├── hom
│   │   └── terraform.tfvars.example
│   └── prd
│       └── terraform.tfvars.example
├── .gitignore
├── images
│   └── 0001.png
├── locals.tf
├── main.tf
├── modules
│   └── vm
│       ├── locals.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── templates
│       │   └── ks.cfg.tpl
│       └── variables.tf
├── oracle_database
│   └── sfw
│       └── V1054592-01.zip
├── outputs.tf
├── providers.tf
├── README.md
├── .ssh
│   ├── ol8-kvm-terraform
│   └── ol8-kvm-terraform.pub
├── terraform.tfvars
├── variables.tf
└── versions.tf
```

## ⚙️ Tecnologias Utilizadas

| Tecnologia              | Versão / Observação          | Finalidade                                      |
|-------------------------|------------------------------|-------------------------------------------------|
| Oracle Linux            | 10 (host) / 8.10 (guest)     | SO do host e da VM                              |
| KVM / libvirt           | —                            | Hipervisor                                      |
| Terraform               | ≥ 1.5                        | Infrastructure as Code                          |
| virt-install            | —                            | Criação da VM                                   |
| Oracle Database         | 26ai Enterprise Edition      | Banco de dados                                  |
| oracle-ai-database-preinstall-26ai | —                 | Pré-requisitos do Oracle                        |
| Flyway                  | Community (última estável)   | Controle de versão de schema / migrations       |
| Java                    | 21 (OpenJDK)                 | Runtime do Flyway                               |

## ✅ Pré-requisitos

Antes de executar o projeto, certifique-se de que o servidor host atenda aos seguintes requisitos:

### 1. Sistema Operacional
- **Oracle Linux 10** (ou qualquer distribuição Linux com suporte a KVM/libvirt).
- Arquitetura **x86_64**.

### 2. Verificação de Hardware
Certifique-se de que a virtualização por hardware (Intel VT-x ou AMD-V) está habilitada na BIOS e suportada pelo kernel:

```bash
grep -E "vmx|svm" /proc/cpuinfo
```

Se não houver saída, ative a virtualização na BIOS.

### 3. Pacotes e Ferramentas
Instale os seguintes pacotes usando o gerenciador `dnf` (ou `yum`):

```bash
sudo dnf install -y qemu-kvm libvirt virt-install openssl
```

- **qemu-kvm**: hipervisor KVM.
- **libvirt**: API de gerenciamento de virtualização.
- **virt-install**: utilitário de linha de comando para criar VMs.
- **openssl**: necessário para gerar hashes de senha (SHA‑512).

### 4. Terraform
O Terraform **não** está disponível nos repositórios padrão do Oracle Linux. Siga os passos abaixo para instalá‑lo:

**Método 1 – Repositório oficial (recomendado):**

```bash
# Adicionar o repositório oficial do HashiCorp
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

# Instalar o Terraform
sudo dnf install -y terraform

# Verificar a instalação
terraform --version
```

**Método 2 – Binário manual:**

```bash
wget https://releases.hashicorp.com/terraform/1.9.5/terraform_1.9.5_linux_amd64.zip
unzip terraform_1.9.5_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

(Substitua a versão pela mais recente disponível.)

### 5. Serviço libvirtd
Habilite e inicie o serviço libvirt:

```bash
sudo systemctl enable --now libvirtd
sudo systemctl enable --now virtlogd
```

Verifique o status:

```bash
sudo systemctl status libvirtd
```

### 6. Permissões de Usuário
O usuário que executará o Terraform (geralmente o mesmo que roda o `virt-install`) precisa ter permissão para acessar o libvirt e escrever nos diretórios de discos.

**Opção A – Adicionar o usuário ao grupo `libvirt`** (recomendado):

```bash
sudo usermod -aG libvirt,kvm $USER
# Faça logout e login novamente para aplicar o grupo
```

**Opção B – Executar como root** (não recomendado para produção).

Além disso, garanta que o diretório onde os discos serão criados (ex: `/var/lib/libvirt/images/`) tenha permissões adequadas:

```bash
sudo chown -R $USER:$USER /var/lib/libvirt/images/
```

### 7. Rede
Certifique‑se de que a rede padrão do libvirt (`default`) esteja ativa e configurada:

```bash
sudo virsh net-list --all
sudo virsh net-start default   # se estiver inativa
sudo virsh net-autostart default
```

Para verificar os detalhes da rede:

```bash
sudo virsh net-dumpxml default | grep -A5 "<ip"
```

A rede padrão geralmente utiliza o range `192.168.122.0/24`.

### 8. ISO de Instalação
Baixe a ISO do Oracle Linux 8.10 e coloque‑a em um diretório acessível (ex: `/var/lib/libvirt/images/OracleLinux-R8-U10-x86_64-dvd.iso`). Você pode obter a ISO no [site oficial da Oracle](https://yum.oracle.com/oracle-linux-isos.html).

Exemplo de download com `wget`:

```bash
wget https://yum.oracle.com/ISOS/OracleLinux/OL8/u10/x86_64/OracleLinux-R8-U10-x86_64-dvd.iso -O /var/lib/libvirt/images/OracleLinux-R8-U10-x86_64-dvd.iso
```

### 9. Espaço em Disco
Verifique se há espaço suficiente no diretório de discos (pelo menos o tamanho definido em `disk_size_gb`).

### 10. Variáveis de Ambiente (opcional)
Para facilitar, defina a variável `LIBVIRT_DEFAULT_URI` para apontar para o sistema QEMU:

```bash
export LIBVIRT_DEFAULT_URI="qemu:///system"
```

Adicione ao seu `~/.bashrc` para persistência.

### 11. Teste de Funcionamento
Antes de executar o Terraform, teste manualmente o `virt-install` com uma VM simples para garantir que tudo está funcionando:

```bash
virt-install --version
virsh list --all
```

---

Após atender a todos os requisitos, prossiga com a configuração e uso do projeto conforme descrito na seção **🚀 Como Utilizar**.

## 🚀 Como Utilizar

### 1. Clonar o repositório

```bash
git clone https://github.com/danilo01arrudal/ol10-kvm-oracle26ai-flyway.git
cd ol10-kvm-oracle26ai-flyway
```

### 2. Criar chave SSH

```bash
mkdir -p .ssh
ssh-keygen -t ed25519 -f .ssh/ol8-kvm-terraform -N "" -C "terraform-ol8-kvm"
```

### 3. Preparar artefatos

- Coloque o RPM do Oracle Database 26ai EE em `data/oracle/`
- (Opcional) Coloque o zip do Flyway ou deixe o script baixar automaticamente

### 4. Configurar variáveis

```bash
cp environments/dev/terraform.tfvars.example terraform.tfvars
```

**Gerar hash de senha:**

```bash
chmod +x ./data/scripts/generate-hash.sh
./data/scripts/generate-hash.sh "SuaSenhaForte123"
# ou
openssl passwd -6 "SuaSenhaForte123"
```

No arquivo `terraform.tfvars`, defina :

- `vm_name`: nome desejado para a VM.
- `ip`: endereço IP estático que a VM terá.
- `iso_path`: caminho completo para a ISO de instalação.
- `disk_path`: caminho onde o disco da VM será criado.
- `root_password_hash` : senha do usuario root obtida via comando **generate-hash.sh**
- `user_password_hash` : senha do usuario root obtida via comando **generate-hash.sh**
- `oracle_password_hash` : senha do usuario oracle obtida via comando **generate-hash.sh**

### 5. Fazer o Download do Oracle Database 26ai 
Baixe o software do Oracle Database 23.26.01 e coloque‑a em um diretório **oracle_database/sfw/** com o seguinte nome : **V1054592-01.zip**.

Você pode obter diretamente no [site oficial da Oracle](https://www.oracle.com/database/technologies/oracle26ai-linux-downloads.html#license-lightbox).

```bash
mkdir -p oracle_database/sfw/
mv ~/Downloads/LINUX.X64_2326100_db_home.zip ~/ol10-kvm-oracle26ai-flyway/oracle_database/sfw/V1054592-01.zip
```

### 6. Inicializar e aplicar

Por se tratar de um ambiente com banco de dados Oracle e necessario repassar ao terraform o valor de senha de alguns usuarios do banco de dados, o export evita que isso fique armazenado em arquivos.
[*A regra padrão exige no mínimo 8 caracteres (com 1 maiúscula, 1 minúscula, 1 número e 1 caractere especial como _, # ou $)*]

```bash
export TF_VAR_sys_password="SuaSenhaSecreta123!"
export TF_VAR_system_password="SuaSenhaSecreta123!"
export TF_VAR_pdbadmin_password="SuaSenhaSecreta123!"
export TF_VAR_dbsnmp_password="SuaSenhaSecreta123!"
```
Apos isso e possivel iniciar, validar e aplicar !

```bash
terraform init
terraform plan
terraform apply
```

O processo completo (criação da VM + instalação do SO + Oracle + Flyway + schema HR) pode levar de **25 a 50 minutos**, dependendo do hardware e da velocidade de download.

### 7. Acompanhar a instalação

```bash
# Console da VM
virsh console <nome_da_vm>

# Logs de pós-instalação (após SSH ficar disponível)
ssh admin@<IP> "sudo tail -f /var/log/oracle-install/*.log"
```

### 8. Verificar o resultado

Após o `terraform apply` concluir com sucesso:

```bash
ssh admin@<IP>

# Como usuário oracle
sudo su - oracle
sqlplus / as sysdba

# Verificar PDB e schema HR
SHOW PDBS;
ALTER SESSION SET CONTAINER = ORCLPDB1;
SELECT username FROM dba_users WHERE username = 'HR';
```

Flyway:

```bash
/opt/flyway/flyway info
```

### 9. Destruir o ambiente

```bash
terraform destroy
```

Remove a VM, o disco e os arquivos gerados.

## 🌍 Ambientes

O projeto suporta múltiplos ambientes:

```bash
cd environments/dev
terraform init
terraform apply
```

Cada ambiente possui seu próprio `terraform.tfvars`.

## 🔧 Personalização

- **Schema adicional**: adicione novas migrations em `data/flyway/sql/`
- **Parâmetros do banco**: edite o script `03-create-database.sh` (SID, PDB, character set, memória, etc.)
- **Particionamento**: ajuste o template `ks.cfg.tpl`
- **Recursos da VM**: altere `memory`, `vcpus` e `disk_size_gb` no `terraform.tfvars`

## 📚 Documentação Adicional

- [docs/architecture.md](docs/architecture.md) – Arquitetura detalhada
- [docs/troubleshooting.md](docs/troubleshooting.md) – Problemas comuns e soluções

## Referências

- [Oracle AI Database 26ai Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/26/)
- [Oracle Database Sample Schemas (HR)](https://github.com/oracle-samples/db-sample-schemas)
- [Flyway Documentation](https://documentation.red-gate.com/flyway)
- [Oracle Linux Kickstart](https://docs.oracle.com/en/operating-systems/oracle-linux/)

---

**Autor:** Danilo Arruda  
**Licença:** MIT (ou a que estiver definida no repositório)


#version=OL8

# Instalação autônoma em modo texto
text
cmdline
skipx

# Utiliza a própria ISO DVD montada pelo virt-install como fonte de pacotes
cdrom

%packages
@^minimal-environment
kexec-tools
openssh-server
sudo
%end

# Layout de teclado e linguagem
keyboard --xlayouts='us'
lang en_US.UTF-8

# Configuração de Rede Estática
network --bootproto=static --device=enp1s0 --gateway=${gateway} --ip=${ip} --nameserver=${dns} --netmask=${netmask} --noipv6 --activate
network --hostname=${hostname}

# Desativa o assistente no primeiro boot
firstboot --disable

# Configuração do Bootloader (BIOS)
bootloader --location=mbr --boot-drive=vda

ignoredisk --only-use=vda
clearpart --all --initlabel

# Particionamento do Disco
part biosboot --fstype="biosboot" --ondisk=vda --size=2
part /boot --fstype="ext4" --ondisk=vda --size=1024
part pv.610 --fstype="lvmpv" --ondisk=vda --grow

volgroup ol --pesize=4096 pv.610
logvol / --fstype="ext4" --grow --size=1024 --name=root --vgname=ol
logvol swap --fstype="swap" --size=${swap_size_mb} --name=swap --vgname=ol

# Fuso Horário
timezone ${timezone} --isUtc

# Senhas de Root e Usuário (console local; automação usa chave SSH)
rootpw --iscrypted ${root_password_hash}
user --groups=wheel --name=${user_name} --password=${user_password_hash} --iscrypted --gecos="${user_name}"

# Chave SSH do usuário (Terraform / automação)
sshkey --username=${user_name} "${ssh_public_key}"

# Aceita licença de uso
eula --agreed

%addon com_redhat_kdump --disable --reserve-mb='auto'
%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end

# ----------------------------------------------------------
# Pós-instalação: SSH + sudo sem senha para o usuário de automação
# ----------------------------------------------------------
%post --erroronfail
set -e

# Garante authorized_keys (além da diretiva sshkey)
mkdir -p /home/${user_name}/.ssh
echo "${ssh_public_key}" >> /home/${user_name}/.ssh/authorized_keys
chown -R ${user_name}:${user_name} /home/${user_name}/.ssh
chmod 700 /home/${user_name}/.ssh
chmod 600 /home/${user_name}/.ssh/authorized_keys

# Sudo NOPASSWD — obrigatório para remote-exec do Terraform (01–04)
echo "${user_name} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${user_name}
chmod 440 /etc/sudoers.d/${user_name}

# SSH habilitado no boot
systemctl enable sshd

# (Opcional) só autenticação por chave via SSH
# sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config || true

%end

# Reinicia e ejeta o DVD automaticamente ao finalizar
reboot --eject

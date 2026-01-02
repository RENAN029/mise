#!/bin/bash
set -e

# Super script para Arch Linux - Otimizações do Sistema

# Função para verificar se estamos no Arch Linux
check_arch() {
    if [ ! -f /etc/arch-release ] && [ ! -f /etc/os-release ]; then
        echo "Este script é apenas para Arch Linux"
        exit 1
    fi
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" != "arch" ] && [[ ! "$ID_LIKE" =~ "arch" ]]; then
            echo "Este script é apenas para Arch Linux"
            exit 1
        fi
    fi
}

# Função para verificar privilégios sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo "Este script precisa ser executado com privilégios de superusuário"
        echo "Por favor, execute com: sudo $0"
        exit 1
    fi
}

# Função para verificar ambiente chroot/docker e pular sudo se necessário
skip_sudo_check() {
    # Verifica se estamos em ambiente chroot ou docker
    if [ -f /proc/1/root/.dockerenv ] || [ -f /.dockerenv ] || [ -n "$CHROOT" ]; then
        echo "⚠ Ambiente chroot/docker detectado, pulando verificação sudo..."
        echo "  (Assumindo que já está rodando como root)"
        return 0
    fi
    
    # Verifica se está em chroot por outros métodos
    if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
        echo "⚠ Ambiente chroot detectado, pulando verificação sudo..."
        return 0
    fi
    
    # Se não for chroot/docker, faz verificação normal
    check_sudo
}

# ============================
# MENUS PRINCIPAIS
# ============================

show_main_menu() {
    clear
    echo "========================================="
    echo "    SUPER SCRIPT - ARCH LINUX            "
    echo "    Otimizações Completas do Sistema     "
    echo "========================================="
    echo "1) Otimizações de Desempenho"
    echo "2) Otimizações de Qualidade de Vida"
    echo "3) Configurar Todos (Otimização Completa)"
    echo "4) Verificar Status do Sistema"
    echo "5) Sair"
    echo "========================================="
    read -p "Escolha uma opção [1-5]: " option
}

show_performance_menu() {
    clear
    echo "========================================="
    echo "    OTIMIZAÇÕES DE DESEMPENHO            "
    echo "========================================="
    echo "1) Configurar CPU Governor (ondemand)"
    echo "2) Criar Swapfile"
    echo "3) Otimizar Shaders (Shader Booster)"
    echo "4) Desativar Mitigação Split-Lock (dsplitm)"
    echo "5) Configurar MinFree (Memória Livre Mínima) (AI)"
    echo "6) Configurar Preload (Pré-carregamento) (AI)"
    echo "7) Configurar EarlyOOM (Previne OOM) (AI)"
    echo "8) Voltar ao Menu Principal"
    echo "========================================="
    read -p "Escolha uma opção [1-8]: " perf_option
}

show_quality_menu() {
    clear
    echo "========================================="
    echo "    OTIMIZAÇÕES DE QUALIDADE DE VIDA     "
    echo "========================================="
    echo "1) Configurar Firewall UFW"
    echo "2) Instalar LucidGlyph (Melhoria de Fontes)"
    echo "3) Power Saver (psaver) - Otimizações de Energia (AI)"
    echo "4) Configurar AppArmor (Sistema de Segurança)"
    echo "5) Configurar HWAccel para Flatpak (AI)"
    echo "6) Configurar DNSMasq (Cache DNS Local) (AI)"
    echo "7) Configurar GRUB-BTRFS (Snapshots no GRUB) (AI)"
    echo "8) Configurar Microsoft Core Fonts"
    echo "9) Configurar Thumbnailer (Miniaturas de Vídeo)"
    echo "10) Configurar BTRFS Assistant (Gerenciador BTRFS)"
    echo "11) Configurar IWD (iNet Wireless Daemon)"
    echo "12) Voltar ao Menu Principal"
    echo "========================================="
    read -p "Escolha uma opção [1-12]: " quality_option
}

# ============================
# FUNÇÕES DE DESEMPENHO
# ============================

# 1. CPU GOVERNOR
enable_ondemand() {
    echo "Habilitando governor ondemand..."
    
    cat > /etc/systemd/system/set-ondemand-governor.service << EOF
[Unit]
Description=Set CPU governor to ondemand
After=sysinit.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'echo ondemand | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'

[Install]
WantedBy=multi-user.target
EOF
    
    cat > /usr/local/bin/set-ondemand-governor.sh << 'EOF'
#!/bin/bash
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo ondemand > "$gov" 2>/dev/null || true
done
EOF
    
    chmod +x /usr/local/bin/set-ondemand-governor.sh
    systemctl enable set-ondemand-governor.service
    
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo ondemand > "$gov" 2>/dev/null || true
    done
    
    echo "✓ Governor ondemand habilitado com sucesso!"
}

disable_ondemand() {
    echo "Desabilitando governor ondemand..."
    systemctl disable set-ondemand-governor.service 2>/dev/null || true
    rm -f /etc/systemd/system/set-ondemand-governor.service
    rm -f /usr/local/bin/set-ondemand-governor.sh
    echo "✓ Governor ondemand desabilitado com sucesso!"
}

check_governor_status() {
    echo "=== Status do CPU Governor ==="
    if [ -f /etc/systemd/system/set-ondemand-governor.service ]; then
        echo "Status: Governor ondemand ATIVADO"
        echo "Serviço systemd: Presente"
    else
        echo "Status: Governor ondemand DESATIVADO"
    fi
    
    if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
        echo -n "Governor atual: "
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "Não disponível"
    fi
    echo
}

# 2. SWAPFILE
get_filesystem() {
    local mount_point=$1
    findmnt -n -o FSTYPE "$mount_point" 2>/dev/null || echo "unknown"
}

create_root_swap() {
    local size=$1
    echo "Criando swapfile de ${size}GB na raiz (/)..."
    
    local fs_type=$(get_filesystem "/")
    
    if [ "$fs_type" = "btrfs" ]; then
        echo "Sistema de arquivos BTRFS detectado..."
        btrfs subvolume create /swap 2>/dev/null || true
        btrfs filesystem mkswapfile --size ${size}g --uuid clear /swap/swapfile
        chmod 600 /swap/swapfile
        swapon /swap/swapfile
        echo "# swapfile" >> /etc/fstab
        echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab
    else
        echo "Criando swapfile em sistema de arquivos padrão..."
        fallocate -l ${size}G /swapfile
        chmod 600 /swapfile
        mkswap -U clear /swapfile
        swapon /swapfile
        echo "# swapfile" >> /etc/fstab
        echo "/swapfile none swap defaults 0 0" >> /etc/fstab
    fi
    
    echo "✓ Swapfile de ${size}GB criado com sucesso na raiz!"
}

create_home_swap() {
    local size=$1
    echo "Criando swapfile de ${size}GB em /home..."
    
    local fs_type=$(get_filesystem "/home")
    
    if [ "$fs_type" = "btrfs" ]; then
        echo "Sistema de arquivos BTRFS detectado..."
        btrfs subvolume create /home/swap 2>/dev/null || true
        btrfs filesystem mkswapfile --size ${size}g --uuid clear /home/swap/swapfile
        chmod 600 /home/swap/swapfile
        swapon /home/swap/swapfile
        echo "# swapfile" >> /etc/fstab
        echo "/home/swap/swapfile none swap defaults 0 0" >> /etc/fstab
    else
        echo "Criando swapfile em sistema de arquivos padrão..."
        fallocate -l ${size}G /home/swapfile
        chmod 600 /home/swapfile
        mkswap -U clear /home/swapfile
        swapon /home/swapfile
        echo "# swapfile" >> /etc/fstab
        echo "/home/swapfile none swap defaults 0 0" >> /etc/fstab
    fi
    
    echo "✓ Swapfile de ${size}GB criado com sucesso em /home!"
}

check_swap_exists() {
    if swapon --show | grep -q '^'; then
        echo "Swap já está habilitado no sistema:"
        swapon --show
        echo ""
        return 0
    else
        return 1
    fi
}

remove_swapfile() {
    echo "Removendo swapfile..."
    swapoff -a
    grep -v "swapfile" /etc/fstab > /tmp/fstab.tmp
    mv /tmp/fstab.tmp /etc/fstab
    rm -f /swapfile /home/swapfile
    rm -rf /swap /home/swap
    echo "✓ Swapfile removido com sucesso!"
}

configure_swap() {
    clear
    echo "=== CONFIGURAR SWAPFILE ==="
    echo ""
    
    if check_swap_exists; then
        echo "Swap já está configurado:"
        swapon --show
        echo ""
        read -p "Deseja: [1] Manter, [2] Remover e recriar, [3] Voltar: " choice
        case $choice in
            1)
                echo "Swap mantido."
                read -p "Pressione Enter para continuar..."
                return
                ;;
            2)
                remove_swapfile
                ;;
            3)
                return
                ;;
            *)
                echo "Opção inválida."
                return
                ;;
        esac
    fi
    
    echo "Onde deseja criar o swapfile?"
    echo "1) Na raiz (/) - 8GB"
    echo "2) Em /home - 8GB"
    echo "3) Personalizar tamanho e local"
    echo "4) Voltar"
    echo "========================================="
    read -p "Escolha uma opção [1-4]: " swap_option
    
    case $swap_option in
        1)
            read -p "Tamanho do swapfile em GB (padrão: 8): " custom_size
            size=${custom_size:-8}
            create_root_swap "$size"
            ;;
        2)
            read -p "Tamanho do swapfile em GB (padrão: 8): " custom_size
            size=${custom_size:-8}
            create_home_swap "$size"
            ;;
        3)
            echo ""
            read -p "Digite o caminho completo para o swapfile (ex: /mnt/swapfile): " swap_path
            read -p "Tamanho em GB (ex: 4, 8, 16): " swap_size
            
            if [ -z "$swap_path" ] || [ -z "$swap_size" ]; then
                echo "Erro: Caminho e tamanho são obrigatórios!"
            else
                echo "Criando swapfile de ${swap_size}GB em ${swap_path}..."
                fallocate -l ${swap_size}G "$swap_path"
                chmod 600 "$swap_path"
                mkswap -U clear "$swap_path"
                swapon "$swap_path"
                echo "# swapfile personalizado" >> /etc/fstab
                echo "$swap_path none swap defaults 0 0" >> /etc/fstab
                echo "✓ Swapfile criado com sucesso!"
            fi
            ;;
        4)
            return
            ;;
        *)
            echo "Opção inválida!"
            ;;
    esac
    
    read -p "Pressione Enter para continuar..."
}

check_swap_status() {
    echo "=== Status do Swap ==="
    if check_swap_exists; then
        echo ""
        free -h | grep -A1 "total"
        echo ""
        echo "Arquivos de swap no fstab:"
        grep -i swap /etc/fstab || echo "Nenhuma entrada encontrada"
    else
        echo "Status: Swap NÃO configurado"
    fi
    echo
}

# 3. SHADER BOOSTER
detect_gpu() {
    echo "=== Detectando Hardware Gráfico ==="
    HAS_NVIDIA=$(lspci | grep -i 'nvidia' | head -1)
    HAS_MESA=$(lspci | grep -Ei '(vga|3d)' | grep -vi nvidia | head -1)
    HAS_INTEL=$(lspci | grep -i 'intel' | grep -i 'vga\|graphics' | head -1)
    
    if [ -n "$HAS_NVIDIA" ]; then
        echo "✓ Placa NVIDIA detectada:"
        echo "  $HAS_NVIDIA"
    fi
    
    if [ -n "$HAS_INTEL" ]; then
        echo "✓ Placa Intel detectada:"
        echo "  $HAS_INTEL"
    fi
    
    if [ -n "$HAS_MESA" ] && [ -z "$HAS_INTEL" ]; then
        echo "✓ Placa Mesa (AMD) detectada:"
        echo "  $HAS_MESA"
    fi
    
    if [ -z "$HAS_NVIDIA" ] && [ -z "$HAS_INTEL" ] && [ -z "$HAS_MESA" ]; then
        echo "⚠ Nenhuma placa gráfica detectada"
    fi
    echo
}

download_patch() {
    local patch_type=$1
    local patch_url=""
    local patch_file="$HOME/patch-$patch_type"
    
    if [ "$patch_type" = "nvidia" ]; then
        patch_url="https://raw.githubusercontent.com/psygreg/shader-booster/main/patch-nvidia"
    elif [ "$patch_type" = "mesa" ]; then
        patch_url="https://raw.githubusercontent.com/psygreg/shader-booster/main/patch-mesa"
    else
        return 1
    fi
    
    echo "Baixando patch para $patch_type..."
    if curl -sSL "$patch_url" -o "$patch_file"; then
        echo "✓ Patch baixado com sucesso"
        return 0
    else
        echo "✗ Erro ao baixar patch"
        rm -f "$patch_file"
        return 1
    fi
}

apply_nvidia_patch() {
    echo "Aplicando otimizações para NVIDIA..."
    
    if download_patch "nvidia"; then
        if grep -q "shader-booster" "$DEST_FILE" 2>/dev/null; then
            echo "⚠ Otimizações já aplicadas anteriormente"
            rm -f "$HOME/patch-nvidia"
            return 1
        fi
        
        echo "" >> "$DEST_FILE"
        echo "# shader-booster NVIDIA optimizations" >> "$DEST_FILE"
        cat "$HOME/patch-nvidia" >> "$DEST_FILE"
        rm -f "$HOME/patch-nvidia"
        
        echo "✓ Otimizações NVIDIA aplicadas em $DEST_FILE"
        return 0
    fi
    return 1
}

apply_mesa_patch() {
    echo "Aplicando otimizações para Mesa..."
    
    if download_patch "mesa"; then
        if grep -q "shader-booster" "$DEST_FILE" 2>/dev/null; then
            echo "⚠ Otimizações já aplicadas anteriormente"
            rm -f "$HOME/patch-mesa"
            return 1
        fi
        
        echo "" >> "$DEST_FILE"
        echo "# shader-booster Mesa optimizations" >> "$DEST_FILE"
        cat "$HOME/patch-mesa" >> "$DEST_FILE"
        rm -f "$HOME/patch-mesa"
        
        echo "✓ Otimizações Mesa aplicadas em $DEST_FILE"
        return 0
    fi
    return 1
}

determine_shell_file() {
    if [ -f "${HOME}/.bash_profile" ]; then
        echo "${HOME}/.bash_profile"
    elif [ -f "${HOME}/.profile" ]; then
        echo "${HOME}/.profile"
    elif [ -f "${HOME}/.zshrc" ]; then
        echo "${HOME}/.zshrc"
    elif [ -f "${HOME}/.bashrc" ]; then
        echo "${HOME}/.bashrc"
    else
        echo "${HOME}/.profile"
    fi
}

configure_shader_booster() {
    clear
    echo "=== OTIMIZADOR DE SHADERS ==="
    echo ""
    
    detect_gpu
    
    # Verificar se já foi aplicado
    if [ -f "${HOME}/.booster" ]; then
        echo "⚠ Otimizações de shader já foram aplicadas anteriormente."
        read -p "Deseja remover as otimizações existentes? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            remove_shader_optimizations
            return
        else
            echo "Operação cancelada."
            return
        fi
    fi
    
    if [ -z "$HAS_NVIDIA" ] && [ -z "$HAS_MESA" ]; then
        echo "Não foi detectado hardware gráfico compatível."
        echo "Otimizações de shader não serão aplicadas."
        read -p "Pressione Enter para continuar..."
        return
    fi
    
    # Determinar arquivo de shell
    DEST_FILE=$(determine_shell_file)
    echo "Arquivo de configuração selecionado: $DEST_FILE"
    
    PATCH_APPLIED=0
    
    # Aplicar patches conforme hardware
    if [ -n "$HAS_NVIDIA" ]; then
        read -p "Aplicar otimizações para NVIDIA? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            if apply_nvidia_patch; then
                PATCH_APPLIED=1
            fi
        fi
    fi
    
    if [ -n "$HAS_MESA" ]; then
        read -p "Aplicar otimizações para Mesa (AMD/Intel)? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            if apply_mesa_patch; then
                PATCH_APPLIED=1
            fi
        fi
    fi
    
    if [ $PATCH_APPLIED -eq 1 ]; then
        echo "1" > "${HOME}/.booster"
        echo ""
        echo "✓ Otimizações aplicadas com sucesso!"
        echo ""
        echo "⚠ REINICIALIZAÇÃO NECESSÁRIA"
        echo "As otimizações serão aplicadas após o próximo login ou reinicialização."
        echo ""
        echo "Para remover as otimizações, execute este script novamente."
    else
        echo "Nenhuma otimização foi aplicada."
    fi
    
    read -p "Pressione Enter para continuar..."
}

remove_shader_optimizations() {
    echo "Removendo otimizações de shader..."
    
    # Remover de todos os possíveis arquivos de shell
    local shell_files=("${HOME}/.bash_profile" "${HOME}/.profile" "${HOME}/.zshrc" "${HOME}/.bashrc")
    
    for file in "${shell_files[@]}"; do
        if [ -f "$file" ]; then
            if grep -q "shader-booster" "$file" 2>/dev/null; then
                # Criar backup
                cp "$file" "${file}.backup-$(date +%Y%m%d%H%M%S)"
                
                # Remover linhas relacionadas ao shader-booster
                grep -v "shader-booster" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
                echo "✓ Removido de: $file"
            fi
        fi
    done
    
    # Remover arquivo de marcação
    rm -f "${HOME}/.booster"
    
    echo "✓ Todas as otimizações de shader foram removidas."
    echo "Um backup dos arquivos originais foi criado."
}

check_shader_status() {
    echo "=== Status das Otimizações de Shader ==="
    
    if [ -f "${HOME}/.booster" ]; then
        echo "Status: Otimizações APLICADAS"
        echo "Arquivo de marcação: ${HOME}/.booster"
    else
        echo "Status: Otimizações NÃO aplicadas"
    fi
    
    echo ""
    echo "Arquivos de shell verificados:"
    local shell_files=("${HOME}/.bash_profile" "${HOME}/.profile" "${HOME}/.zshrc" "${HOME}/.bashrc")
    local found=0
    
    for file in "${shell_files[@]}"; do
        if [ -f "$file" ] && grep -q "shader-booster" "$file" 2>/dev/null; then
            echo "  ✓ $file: CONTÉM otimizações"
            found=1
        fi
    done
    
    if [ $found -eq 0 ]; then
        echo "  Nenhum arquivo contém otimizações"
    fi
    echo
}

# 4. SPLIT-LOCK MITIGATION
check_splitlock_status() {
    echo "=== Status da Mitigação Split-Lock ==="
    
    if [ -f "/sys/devices/system/cpu/split_lock_mitigate" ]; then
        local current_status=$(cat /sys/devices/system/cpu/split_lock_mitigate 2>/dev/null)
        echo "Status atual do split-lock: $current_status"
        echo "(0 = desativado, 1 = ativado)"
    else
        echo "Interface split-lock não encontrada no sistema."
        echo "O kernel pode não suportar esta funcionalidade."
    fi
    
    echo ""
    echo "Parâmetros atuais do kernel:"
    cat /proc/cmdline
    
    if [ -f "$HOME/.local/.autopatch.state" ]; then
        echo ""
        echo "⚠ Mitigação já foi desativada anteriormente (arquivo de estado presente)"
    fi
    echo
}

disable_splitlock() {
    echo "=== DESATIVANDO MITIGAÇÃO SPLIT-LOCK ==="
    echo ""
    echo "AVISO: Esta operação pode melhorar o desempenho em alguns casos,"
    echo "mas reduz a proteção contra certos ataques de segurança."
    echo "Recomenda-se apenas para sistemas de uso pessoal/desempenho."
    echo ""
    
    read -p "Deseja continuar? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Operação cancelada."
        return
    fi
    
    if [ -f "$HOME/.local/.autopatch.state" ]; then
        echo "A mitigação já foi desativada anteriormente."
        read -p "Deseja reverter (reativar a mitigação)? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            enable_splitlock
            return
        else
            echo "Operação cancelada."
            return
        fi
    fi
    
    echo "Desativando mitigação split-lock..."
    
    # Método 1: Via sysfs (se disponível)
    if [ -f "/sys/devices/system/cpu/split_lock_mitigate" ]; then
        echo "0" | tee /sys/devices/system/cpu/split_lock_mitigate > /dev/null
        echo "✓ Mitigação desativada via sysfs"
    fi
    
    # Método 2: Configurar GRUB para persistência
    echo "Configurando GRUB para persistência após reinicialização..."
    
    local grub_cfg="/etc/default/grub"
    if [ -f "$grub_cfg" ]; then
        cp "$grub_cfg" "${grub_cfg}.backup.$(date +%Y%m%d%H%M%S)"
        
        if ! grep -q "split_lock_detect=off" "$grub_cfg"; then
            if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$grub_cfg"; then
                sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 split_lock_detect=off"/' "$grub_cfg"
            else
                echo 'GRUB_CMDLINE_LINUX_DEFAULT="split_lock_detect=off"' | tee -a "$grub_cfg"
            fi
            echo "✓ Parâmetro adicionado ao GRUB"
        else
            echo "✓ Parâmetro já presente no GRUB"
        fi
        
        echo "Atualizando configuração do GRUB..."
        grub-mkconfig -o /boot/grub/grub.cfg
        echo "✓ GRUB atualizado"
    else
        echo "⚠ Arquivo do GRUB não encontrado: $grub_cfg"
    fi
    
    # Método 3: Configurar systemd-boot (se usado)
    if [ -d "/boot/loader/entries" ]; then
        echo "Systemd-boot detectado, configurando..."
        for entry in /boot/loader/entries/*.conf; do
            if [ -f "$entry" ]; then
                cp "$entry" "${entry}.backup.$(date +%Y%m%d%H%M%S)"
                if ! grep -q "split_lock_detect=off" "$entry"; then
                    sed -i '/^options/ s/$/ split_lock_detect=off/' "$entry"
                    echo "✓ Configurado em: $(basename "$entry")"
                fi
            fi
        done
    fi
    
    # Criar arquivo de estado
    mkdir -p "$HOME/.local"
    echo "split_lock_disabled_on_$(date +%Y%m%d_%H%M%S)" > "$HOME/.local/.autopatch.state"
    
    echo ""
    echo "✓ Mitigação split-lock desativada com sucesso!"
    echo ""
    echo "⚠ REINICIALIZAÇÃO NECESSÁRIA"
    echo "Para que as mudanças tenham efeito completo, reinicie o sistema."
    echo ""
    echo "Para verificar o status atual:"
    echo "  cat /proc/cmdline | grep split_lock_detect"
}

enable_splitlock() {
    echo "=== REATIVANDO MITIGAÇÃO SPLIT-LOCK ==="
    echo ""
    
    if [ -f "/sys/devices/system/cpu/split_lock_mitigate" ]; then
        echo "1" | tee /sys/devices/system/cpu/split_lock_mitigate > /dev/null
        echo "✓ Mitigação reativada via sysfs"
    fi
    
    local grub_cfg="/etc/default/grub"
    if [ -f "$grub_cfg" ]; then
        sed -i 's/ split_lock_detect=off//g' "$grub_cfg"
        sed -i 's/split_lock_detect=off //g' "$grub_cfg"
        echo "✓ Parâmetro removido do GRUB"
        
        echo "Atualizando configuração do GRUB..."
        grub-mkconfig -o /boot/grub/grub.cfg
        echo "✓ GRUB atualizado"
    fi
    
    if [ -d "/boot/loader/entries" ]; then
        echo "Removendo de systemd-boot..."
        for entry in /boot/loader/entries/*.conf; do
            if [ -f "$entry" ]; then
                sed -i 's/ split_lock_detect=off//g' "$entry"
                sed -i 's/split_lock_detect=off //g' "$entry"
                echo "✓ Removido de: $(basename "$entry")"
            fi
        done
    fi
    
    rm -f "$HOME/.local/.autopatch.state"
    
    echo ""
    echo "✓ Mitigação split-lock reativada com sucesso!"
    echo "Reinicie o sistema para que as mudanças tenham efeito completo."
}

configure_splitlock() {
    clear
    echo "=== CONFIGURAÇÃO DE MITIGAÇÃO SPLIT-LOCK ==="
    echo ""
    
    check_splitlock_status
    
    if [ -f "$HOME/.local/.autopatch.state" ]; then
        echo "A mitigação está atualmente DESATIVADA."
        read -p "Deseja: [1] Manter desativada, [2] Reativar mitigação, [3] Ver detalhes: " choice
        case $choice in
            1)
                echo "Mitigação permanecerá desativada."
                ;;
            2)
                enable_splitlock
                ;;
            3)
                echo ""
                echo "Detalhes da configuração atual:"
                if [ -f "$HOME/.local/.autopatch.state" ]; then
                    echo "Arquivo de estado:"
                    cat "$HOME/.local/.autopatch.state"
                fi
                echo ""
                echo "Parâmetros do kernel ativos:"
                cat /proc/cmdline
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    else
        echo "A mitigação está atualmente ATIVADA (padrão do sistema)."
        read -p "Deseja desativar a mitigação split-lock? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            disable_splitlock
        else
            echo "Operação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# 5. MINFREE FIX (Memória Livre Mínima Dinâmica) - AI
check_minfree_status() {
    echo "=== Status do MinFree (Memória Livre Mínima) ==="
    
    echo "Configurações atuais do vm.min_free_kbytes:"
    sysctl vm.min_free_kbytes 2>/dev/null || echo "  Não disponível"
    
    echo ""
    echo "Configurações no sysctl.conf:"
    if [ -f "/etc/sysctl.conf" ]; then
        grep -i "vm.min_free_kbytes" /etc/sysctl.conf || echo "  Não configurado"
    else
        echo "  /etc/sysctl.conf não encontrado"
    fi
    
    echo ""
    echo "Configurações no sysctl.d:"
    if [ -d "/etc/sysctl.d" ]; then
        grep -r "vm.min_free_kbytes" /etc/sysctl.d/ 2>/dev/null || echo "  Não configurado"
    fi
    
    echo ""
    echo "Memória total do sistema:"
    free -h | grep "^Mem:"
    
    echo ""
    echo "Recomendações:"
    echo "  - Valores muito baixos podem causar falhas do OOM Killer"
    echo "  - Valores muito altos desperdiçam memória"
    echo "  - Ideal: 1-3% da memória total"
    echo
}

calculate_minfree() {
    local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local recommended=$((total_mem_kb / 100))  # 1% da memória total
    
    # Ajustar para valores razoáveis
    if [ $recommended -lt 65536 ]; then
        recommended=65536  # Mínimo 64MB
    elif [ $recommended -gt 524288 ]; then
        recommended=524288  # Máximo 512MB
    fi
    
    echo $recommended
}

configure_minfree() {
    clear
    echo "=== CONFIGURAÇÃO MINFREE (Memória Livre Mínima Dinâmica) ==="
    echo "Ajusta a quantidade mínima de memória livre no sistema"
    echo "para prevenir falhas do OOM Killer e melhorar responsividade."
    echo ""
    echo "Esta é uma implementação AI baseada no conceito do minfreefix."
    echo ""
    
    check_minfree_status
    
    local current_value=$(sysctl -n vm.min_free_kbytes 2>/dev/null || echo "0")
    local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local recommended=$(calculate_minfree)
    
    echo "Memória total: $((total_mem_kb / 1024)) MB"
    echo "Valor atual: $((current_value / 1024)) MB"
    echo "Valor recomendado: $((recommended / 1024)) MB (~1% da memória total)"
    echo ""
    
    read -p "Deseja: [1] Aplicar valor recomendado, [2] Configurar manualmente, [3] Restaurar padrão, [4] Voltar: " choice
    
    case $choice in
        1)
            echo "Aplicando valor recomendado de $((recommended / 1024)) MB..."
            sysctl -w vm.min_free_kbytes=$recommended
            
            # Tornar permanente
            echo "# MinFree configuration - Dynamic minimum free memory" | tee /etc/sysctl.d/10-minfree.conf
            echo "vm.min_free_kbytes = $recommended" | tee -a /etc/sysctl.d/10-minfree.conf
            
            # Aplicar também dirty ratios relacionadas
            echo "vm.vfs_cache_pressure = 50" | tee -a /etc/sysctl.d/10-minfree.conf
            echo "vm.dirty_background_ratio = 5" | tee -a /etc/sysctl.d/10-minfree.conf
            echo "vm.dirty_ratio = 10" | tee -a /etc/sysctl.d/10-minfree.conf
            echo "vm.swappiness = 60" | tee -a /etc/sysctl.d/10-minfree.conf
            
            sysctl -p /etc/sysctl.d/10-minfree.conf
            
            echo "✓ MinFree configurado com sucesso!"
            echo "  Valor aplicado: $((recommended / 1024)) MB"
            echo "  Configuração salva em: /etc/sysctl.d/10-minfree.conf"
            ;;
        
        2)
            read -p "Digite o valor em MB (ex: 64, 128, 256): " mb_value
            if [[ "$mb_value" =~ ^[0-9]+$ ]]; then
                local kb_value=$((mb_value * 1024))
                echo "Aplicando valor de ${mb_value} MB (${kb_value} KB)..."
                sysctl -w vm.min_free_kbytes=$kb_value
                echo "# MinFree configuration - Manual setting" | tee /etc/sysctl.d/10-minfree.conf
                echo "vm.min_free_kbytes = $kb_value" | tee -a /etc/sysctl.d/10-minfree.conf
                sysctl -p /etc/sysctl.d/10-minfree.conf
                echo "✓ MinFree configurado com sucesso!"
            else
                echo "✗ Valor inválido!"
            fi
            ;;
        
        3)
            echo "Restaurando configuração padrão..."
            # Remover configuração personalizada
            rm -f /etc/sysctl.d/10-minfree.conf
            # Restaurar valor padrão do kernel
            sysctl -w vm.min_free_kbytes=67584  # Valor padrão comum
            echo "✓ Configuração padrão restaurada"
            ;;
        
        4)
            return
            ;;
        
        *)
            echo "Opção inválida!"
            ;;
    esac
    
    echo ""
    echo "⚠ RECOMENDA-SE REINICIALIZAÇÃO"
    echo "Para que as mudanças tenham efeito completo em todas as aplicações,"
    echo "reinicie o sistema."
    
    read -p "Pressione Enter para continuar..."
}

# 6. PRELOAD (Pré-carregamento) - AI
check_preload_status() {
    echo "=== Status do Preload ==="
    
    # Verificar se preload está instalado
    if command -v preload &> /dev/null || systemctl is-active preload 2>/dev/null; then
        echo "Status: INSTALADO"
        
        # Verificar se serviço está ativo
        if systemctl is-active preload &> /dev/null; then
            echo "Serviço: ATIVO"
            systemctl status preload --no-pager -l | head -10
        else
            echo "Serviço: INATIVO"
        fi
        
        # Verificar configuração
        if [ -f "/etc/preload.conf" ]; then
            echo ""
            echo "Configuração do preload:"
            grep -v "^#" /etc/preload.conf | grep -v "^$" | head -10
        fi
    else
        echo "Status: NÃO INSTALADO"
    fi
    
    echo ""
    
    # Verificar memória disponível
    local total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_gb=$(( total_kb / 1024 / 1024 ))
    echo "Memória total do sistema: ${total_gb} GB"
    
    if [ $total_gb -le 12 ]; then
        echo "⚠ AVISO: Sistema tem ${total_gb} GB de RAM"
        echo "  Preload é recomendado apenas para sistemas com mais de 12 GB de RAM"
    else
        echo "✓ Sistema tem ${total_gb} GB de RAM - adequado para preload"
    fi
    echo
}

calculate_preload_memory() {
    local total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_gb=$(( total_kb / 1024 / 1024 ))
    
    # Calcular memória para preload baseado na RAM total
    if [ $total_gb -le 8 ]; then
        echo "128"  # 128MB para sistemas com até 8GB
    elif [ $total_gb -le 16 ]; then
        echo "256"  # 256MB para sistemas com 8-16GB
    elif [ $total_gb -le 32 ]; then
        echo "512"  # 512MB para sistemas com 16-32GB
    else
        echo "1024" # 1GB para sistemas com mais de 32GB
    fi
}

install_preload() {
    echo "Instalando e configurando Preload..."
    
    # Verificar memória primeiro
    local total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_gb=$(( total_kb / 1024 / 1024 ))
    
    if [ $total_gb -le 12 ]; then
        echo ""
        echo "⚠ AVISO: Sistema tem apenas ${total_gb} GB de RAM"
        echo "  Preload pode não ser benéfico e pode até causar problemas"
        echo "  Recomenda-se apenas para sistemas com mais de 12 GB de RAM"
        echo ""
        read -p "Deseja continuar mesmo assim? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            echo "Instalação cancelada."
            return 1
        fi
    fi
    
    # Instalar preload
    if ! command -v preload &> /dev/null; then
        echo "Instalando pacote preload..."
        pacman -S --noconfirm preload
    else
        echo "✓ Preload já está instalado"
    fi
    
    # Configurar preload
    echo "Configurando preload..."
    
    if [ -f "/etc/preload.conf" ]; then
        # Fazer backup da configuração original
        cp /etc/preload.conf /etc/preload.conf.backup.$(date +%Y%m%d%H%M%S)
        
        # Calcular configurações baseadas na memória
        local preload_mem=$(calculate_preload_memory)
        local modelist_size=$((preload_mem * 2))
        
        # Criar configuração otimizada
        cat > /etc/preload.conf << EOF
# Preload configuration - Optimized by Super Script
# Modelist size in MB (memory used for tracking files)
modelistsize = $modellist_size

# Percentage of system memory to use for preloading
# (default: 25, reduced for better performance)
percentphysicalram = 15

# Use adaptive preloading (learn from usage patterns)
usecorrelations = true

# Number of samples to keep in correlation matrix
samplenum = 200

# Time in seconds between learning runs
sleeptime = 20

# Whether to learn from all users or just current user
sharedlibs = true
programs = true

# Preload programs on startup
preloadonstartup = true

# Maximum number of programs to preload
maxprogs = 10

# Maximum number of shared libs to preload
maxlibs = 30

# Minimum file size to consider for preloading (in KB)
minsize = 50

# Maximum file size to consider for preloading (in KB)
maxsize = 10000
EOF
        
        echo "✓ Configuração otimizada aplicada"
        echo "  Memória alocada: ${preload_mem}MB"
        echo "  Modelist size: ${modelist_size}MB"
    fi
    
    # Habilitar e iniciar serviço
    echo "Habilitando serviço preload..."
    systemctl enable preload
    systemctl start preload
    
    # Verificar se está funcionando
    if systemctl is-active preload &> /dev/null; then
        echo "✓ Preload instalado e ativado com sucesso!"
        echo ""
        echo "O preload agora monitora seus padrões de uso e pré-carrega"
        echo "aplicações frequentemente usadas na memória, reduzindo"
        echo "tempos de inicialização."
    else
        echo "⚠ Preload instalado mas serviço não iniciou"
        echo "  Verifique com: systemctl status preload"
    fi
}

uninstall_preload() {
    echo "Desinstalando Preload..."
    
    # Parar e desabilitar serviço
    systemctl stop preload 2>/dev/null || true
    systemctl disable preload 2>/dev/null || true
    
    # Remover pacote
    pacman -Rns --noconfirm preload 2>/dev/null || true
    
    # Restaurar configuração original se existir backup
    if [ -f "/etc/preload.conf.backup" ]; then
        mv /etc/preload.conf.backup /etc/preload.conf
        echo "✓ Configuração original restaurada"
    elif [ -f "/etc/preload.conf" ]; then
        rm -f /etc/preload.conf
    fi
    
    echo "✓ Preload desinstalado com sucesso!"
}

configure_preload() {
    clear
    echo "=== PRELOAD (Pré-carregamento) - AI ==="
    echo "Pré-carrega aplicações frequentemente usadas na memória"
    echo "para reduzir tempos de inicialização e melhorar responsividade."
    echo ""
    echo "Recomendado apenas para sistemas com mais de 12 GB de RAM."
    echo ""
    
    check_preload_status
    
    if command -v preload &> /dev/null || systemctl is-active preload 2>/dev/null; then
        echo "Preload já está instalado/configurado."
        read -p "Deseja: [1] Reconfigurar, [2] Desinstalar, [3] Ver status detalhado, [4] Voltar: " choice
        case $choice in
            1)
                echo "Reconfigurando Preload..."
                install_preload
                ;;
            2)
                uninstall_preload
                ;;
            3)
                echo ""
                echo "Status detalhado do Preload:"
                if systemctl is-active preload &> /dev/null; then
                    systemctl status preload --no-pager -l
                    echo ""
                    echo "Últimas entradas do log:"
                    journalctl -u preload -n 20 --no-pager
                else
                    echo "Serviço não está ativo."
                fi
                ;;
            4)
                return
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    else
        echo "Preload não está instalado."
        read -p "Deseja instalar e configurar o Preload? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_preload
        else
            echo "Instalação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# 7. EARLYOOM (Previne OOM) - AI
check_earlyoom_status() {
    echo "=== Status do EarlyOOM ==="
    
    # Verificar se earlyoom está instalado
    if command -v earlyoom &> /dev/null || systemctl is-active earlyoom 2>/dev/null; then
        echo "Status: INSTALADO"
        
        # Verificar se serviço está ativo
        if systemctl is-active earlyoom &> /dev/null; then
            echo "Serviço: ATIVO"
            systemctl status earlyoom --no-pager -l | head -10
        else
            echo "Serviço: INATIVO"
        fi
        
        # Verificar configuração
        if [ -f "/etc/default/earlyoom" ]; then
            echo ""
            echo "Configuração do earlyoom:"
            grep -v "^#" /etc/default/earlyoom | grep -v "^$" | head -10
        fi
    else
        echo "Status: NÃO INSTALADO"
    fi
    
    echo ""
    echo "Memória do sistema:"
    free -h
    echo
}

install_earlyoom() {
    echo "Instalando e configurando EarlyOOM..."
    
    # Instalar earlyoom
    if ! command -v earlyoom &> /dev/null; then
        echo "Instalando pacote earlyoom..."
        pacman -S --noconfirm earlyoom
    else
        echo "✓ EarlyOOM já está instalado"
    fi
    
    # Configurar earlyoom
    echo "Configurando EarlyOOM..."
    
    if [ -f "/etc/default/earlyoom" ]; then
        # Fazer backup da configuração original
        cp /etc/default/earlyoom /etc/default/earlyoom.backup.$(date +%Y%m%d%H%M%S)
    fi
    
    # Calcular configurações baseadas na memória
    local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_mem_mb=$((total_mem_kb / 1024))
    
    # Calcular limites recomendados
    local memory_min=$((total_mem_mb * 5 / 100))  # 5% da memória
    local memory_max=$((total_mem_mb * 10 / 100)) # 10% da memória
    local swap_min=$((memory_min / 2))           # 50% do memory_min
    local swap_max=$((memory_max / 2))           # 50% do memory_max
    
    # Ajustar valores mínimos
    if [ $memory_min -lt 100 ]; then
        memory_min=100
    fi
    if [ $memory_max -lt 200 ]; then
        memory_max=200
    fi
    
    # Criar configuração otimizada
    cat > /etc/default/earlyoom << EOF
# EarlyOOM configuration - Optimized by Super Script
EARLYOOM_ARGS="--memory-min-percent=5 --memory-max-percent=10 --swap-min-percent=2 --swap-max-percent=5"
# Notifications (desative se não quiser notificações)
EARLYOOM_ARGS="\$EARLYOOM_ARGS --notify-ssh"
# Ignorar processos específicos (opcional)
# EARLYOOM_ARGS="\$EARLYOOM_ARGS --avoid '(^|/)(init|X|sshd|systemd|dbus-daemon|NetworkManager)$'"
# Opções avançadas
EARLYOOM_ARGS="\$EARLYOOM_ARGS --prefer '(^|/)(java|chromium|firefox|code|discord)$'"
EOF
    
    echo "✓ Configuração otimizada aplicada"
    echo "  Memória mínima: ${memory_min}MB (5%)"
    echo "  Memória máxima: ${memory_max}MB (10%)"
    
    # Habilitar e iniciar serviço
    echo "Habilitando serviço earlyoom..."
    systemctl enable earlyoom
    systemctl start earlyoom
    
    # Verificar se está funcionando
    if systemctl is-active earlyoom &> /dev/null; then
        echo "✓ EarlyOOM instalado e ativado com sucesso!"
        echo ""
        echo "O EarlyOOM monitora a memória e swap do sistema e mata processos"
        echo "antes que o sistema fique completamente sem memória, prevenindo"
        echo "travamentos causados pelo OOM Killer do kernel."
    else
        echo "⚠ EarlyOOM instalado mas serviço não iniciou"
        echo "  Verifique com: systemctl status earlyoom"
    fi
}

uninstall_earlyoom() {
    echo "Desinstalando EarlyOOM..."
    
    # Parar e desabilitar serviço
    systemctl stop earlyoom 2>/dev/null || true
    systemctl disable earlyoom 2>/dev/null || true
    
    # Remover pacote
    pacman -Rns --noconfirm earlyoom 2>/dev/null || true
    
    # Restaurar configuração original se existir backup
    if [ -f "/etc/default/earlyoom.backup" ]; then
        mv /etc/default/earlyoom.backup /etc/default/earlyoom
        echo "✓ Configuração original restaurada"
    elif [ -f "/etc/default/earlyoom" ]; then
        rm -f /etc/default/earlyoom
    fi
    
    echo "✓ EarlyOOM desinstalado com sucesso!"
}

configure_earlyoom() {
    clear
    echo "=== EARLYOOM (Previne OOM Killer) - AI ==="
    echo "Monitora e gerencia a memória do sistema, matando processos"
    echo "antes que o sistema fique completamente sem memória."
    echo ""
    echo "Isto previne travamentos causados pelo OOM Killer do kernel."
    echo ""
    
    check_earlyoom_status
    
    if command -v earlyoom &> /dev/null || systemctl is-active earlyoom 2>/dev/null; then
        echo "EarlyOOM já está instalado/configurado."
        read -p "Deseja: [1] Reconfigurar, [2] Desinstalar, [3] Ver status detalhado, [4] Voltar: " choice
        case $choice in
            1)
                echo "Reconfigurando EarlyOOM..."
                install_earlyoom
                ;;
            2)
                uninstall_earlyoom
                ;;
            3)
                echo ""
                echo "Status detalhado do EarlyOOM:"
                if systemctl is-active earlyoom &> /dev/null; then
                    systemctl status earlyoom --no-pager -l
                    echo ""
                    echo "Últimas entradas do log:"
                    journalctl -u earlyoom -n 20 --no-pager
                else
                    echo "Serviço não está ativo."
                fi
                ;;
            4)
                return
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    else
        echo "EarlyOOM não está instalado."
        read -p "Deseja instalar e configurar o EarlyOOM? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_earlyoom
        else
            echo "Instalação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# ============================
# FUNÇÕES DE QUALIDADE DE VIDA
# ============================

# 1. FIREWALL UFW
setup_ufw() {
    echo "Instalando e configurando UFW..."
    
    if ! command -v ufw &> /dev/null; then
        echo "Instalando pacotes necessários..."
        pacman -S --noconfirm ufw gufw
    fi
    
    ufw default deny incoming
    ufw default allow outgoing
    ufw --force enable
    systemctl enable ufw
    systemctl start ufw
    
    echo "✓ UFW configurado e ativado com sucesso!"
    echo "Regras: Entrada DENY, Saída ALLOW"
}

uninstall_ufw() {
    echo "Desinstalando UFW..."
    ufw --force disable 2>/dev/null || true
    systemctl stop ufw 2>/dev/null || true
    systemctl disable ufw 2>/dev/null || true
    pacman -Rns --noconfirm gufw ufw 2>/dev/null || true
    echo "✓ UFW desinstalado com sucesso!"
}

check_ufw_status() {
    echo "=== Status do Firewall UFW ==="
    if command -v ufw &> /dev/null; then
        echo "UFW: Instalado"
        ufw status verbose | head -10
    else
        echo "UFW: Não instalado"
    fi
    echo
}

configure_ufw() {
    clear
    echo "=== CONFIGURAR FIREWALL UFW ==="
    echo ""
    
    check_ufw_status
    
    if command -v ufw &> /dev/null; then
        echo "UFW já está instalado."
        read -p "Deseja: [1] Reconfigurar UFW, [2] Desinstalar UFW, [3] Voltar: " ufw_option
        case $ufw_option in
            1)
                setup_ufw
                ;;
            2)
                uninstall_ufw
                ;;
            3)
                return
                ;;
            *)
                echo "Opção inválida!"
                ;;
        esac
    else
        read -p "Deseja instalar e configurar o UFW? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            setup_ufw
        else
            echo "Operação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# 2. LUCIDGLYPH
detect_lucidglyph() {
    if [ -f "/usr/share/lucidglyph/info" ] || [ -f "/usr/share/freetype-envision/info" ]; then
        return 0
    fi
    
    if [ -f "$HOME/.local/share/lucidglyph/info" ]; then
        return 0
    fi
    
    if [ -d "/etc/fonts/conf.d" ]; then
        if find "/etc/fonts/conf.d" -name "*lucidglyph*" -o -name "*freetype-envision*" 2>/dev/null | grep -q .; then
            return 0
        fi
    fi
    
    if [ -d "$HOME/.config/fontconfig/conf.d" ]; then
        if find "$HOME/.config/fontconfig/conf.d" -name "*lucidglyph*" -o -name "*freetype-envision*" 2>/dev/null | grep -q .; then
            return 0
        fi
    fi
    
    if [ -f "/etc/environment" ] && grep -q "LUCIDGLYPH\|FREETYPE_ENVISION" "/etc/environment" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

get_latest_lucidglyph_version() {
    local tag_info=""
    
    if command -v curl &> /dev/null; then
        tag_info=$(curl -s "https://api.github.com/repos/maximilionus/lucidglyph/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")' 2>/dev/null)
    elif command -v wget &> /dev/null; then
        tag_info=$(wget -qO- "https://api.github.com/repos/maximilionus/lucidglyph/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")' 2>/dev/null)
    fi
    
    if [ -z "$tag_info" ]; then
        tag_info="v0.13.1"
    fi
    
    echo "$tag_info"
}

install_lucidglyph() {
    clear
    echo "=== INSTALAÇÃO DO LUCIDGLYPH ==="
    echo "Melhoria de renderização de fontes para Linux"
    echo ""
    
    if detect_lucidglyph; then
        echo "⚠ LucidGlyph já está instalado."
        read -p "Deseja desinstalar? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            uninstall_lucidglyph
            read -p "Deseja reinstalar a versão mais recente? (s/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                echo "Operação cancelada."
                return
            fi
        else
            echo "Operação cancelada."
            return
        fi
    fi
    
    echo "O LucidGlyph melhora a renderização de fontes no Linux."
    echo "Isso pode melhorar significativamente a legibilidade do texto."
    echo ""
    read -p "Deseja continuar com a instalação? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Instalação cancelada."
        return
    fi
    
    echo "Verificando última versão do LucidGlyph..."
    local tag=$(get_latest_lucidglyph_version)
    local ver="${tag#v}"
    
    echo "Versão selecionada: $tag"
    
    # Verificar dependências
    echo "Verificando dependências..."
    local missing_deps=""
    
    for dep in curl wget tar; do
        if ! command -v $dep &> /dev/null; then
            missing_deps="$missing_deps $dep"
        fi
    done
    
    if [ -n "$missing_deps" ]; then
        echo "Instalando dependências:$missing_deps"
        pacman -S --noconfirm $missing_deps
    fi
    
    # Baixar e instalar
    echo "Baixando LucidGlyph $tag..."
    cd "$HOME" || exit 1
    
    [ -f "${tag}.tar.gz" ] && rm -f "${tag}.tar.gz"
    [ -d "lucidglyph-${ver}" ] && rm -rf "lucidglyph-${ver}"
    
    local download_url="https://github.com/maximilionus/lucidglyph/archive/refs/tags/${tag}.tar.gz"
    echo "URL: $download_url"
    
    if ! wget -O "${tag}.tar.gz" "$download_url"; then
        echo "✗ Erro ao baixar LucidGlyph"
        return 1
    fi
    
    if [ ! -s "${tag}.tar.gz" ]; then
        echo "✗ Arquivo vazio ou corrompido"
        rm -f "${tag}.tar.gz"
        return 1
    fi
    
    echo "Extraindo arquivos..."
    if ! tar -xvzf "${tag}.tar.gz"; then
        echo "✗ Erro ao extrair arquivos"
        rm -f "${tag}.tar.gz"
        return 1
    fi
    
    # Verificar se o diretório foi criado
    if [ ! -d "lucidglyph-${ver}" ]; then
        local extracted_dir=$(ls -d lucidglyph-* 2>/dev/null | head -1)
        if [ -n "$extracted_dir" ]; then
            echo "Usando diretório encontrado: $extracted_dir"
            ver="${extracted_dir#lucidglyph-}"
        else
            rm -f "${tag}.tar.gz"
            return 1
        fi
    fi
    
    echo "Instalando LucidGlyph..."
    cd "lucidglyph-${ver}" || return 1
    
    if [ ! -f "lucidglyph.sh" ]; then
        echo "✗ Arquivo de instalação não encontrado"
        cd ..
        rm -rf "lucidglyph-${ver}"
        rm -f "${tag}.tar.gz"
        return 1
    fi
    
    chmod +x lucidglyph.sh
    
    echo "Executando script de instalação..."
    if ! ./lucidglyph.sh install; then
        echo "✗ Erro durante a instalação"
        cd ..
        rm -rf "lucidglyph-${ver}"
        rm -f "${tag}.tar.gz"
        return 1
    fi
    
    echo "Limpando arquivos temporários..."
    cd ..
    rm -rf "lucidglyph-${ver}"
    rm -f "${tag}.tar.gz"
    
    echo ""
    echo "✓ LucidGlyph instalado com sucesso!"
    echo ""
    echo "⚠ REINICIALIZAÇÃO RECOMENDADA"
    echo "Para que as mudanças na renderização de fontes tenham efeito completo,"
    echo "é recomendado reiniciar o sistema ou pelo menos as aplicações gráficas."
    
    read -p "Pressione Enter para continuar..."
}

uninstall_lucidglyph() {
    echo "Iniciando desinstalação do LucidGlyph..."
    
    local uninstalled=0
    
    if [ -f "/usr/share/lucidglyph/uninstaller.sh" ] && [ -x "/usr/share/lucidglyph/uninstaller.sh" ]; then
        echo "Executando desinstalador system-wide..."
        "/usr/share/lucidglyph/uninstaller.sh"
        uninstalled=1
    elif [ -f "/usr/share/freetype-envision/uninstaller.sh" ] && [ -x "/usr/share/freetype-envision/uninstaller.sh" ]; then
        echo "Executando desinstalador freetype-envision..."
        "/usr/share/freetype-envision/uninstaller.sh"
        uninstalled=1
    elif [ -f "$HOME/.local/share/lucidglyph/uninstaller.sh" ] && [ -x "$HOME/.local/share/lucidglyph/uninstaller.sh" ]; then
        echo "Executando desinstalador user..."
        "$HOME/.local/share/lucidglyph/uninstaller.sh"
        uninstalled=1
    fi
    
    if [ $uninstalled -eq 0 ]; then
        echo "Removendo arquivos do LucidGlyph manualmente..."
        
        if [ -d "/etc/fonts/conf.d" ]; then
            rm -f /etc/fonts/conf.d/*lucidglyph* 2>/dev/null
            rm -f /etc/fonts/conf.d/*freetype-envision* 2>/dev/null
        fi
        
        if [ -d "$HOME/.config/fontconfig/conf.d" ]; then
            rm -f "$HOME/.config/fontconfig/conf.d"/*lucidglyph* 2>/dev/null
            rm -f "$HOME/.config/fontconfig/conf.d"/*freetype-envision* 2>/dev/null
        fi
        
        rm -rf /usr/share/lucidglyph 2>/dev/null
        rm -rf /usr/share/freetype-envision 2>/dev/null
        rm -rf "$HOME/.local/share/lucidglyph" 2>/dev/null
        
        if [ -f "/etc/environment" ]; then
            grep -v "LUCIDGLYPH\|FREETYPE_ENVISION" /etc/environment > /tmp/environment.tmp
            mv /tmp/environment.tmp /etc/environment
        fi
    fi
    
    echo "✓ LucidGlyph desinstalado com sucesso!"
}

check_lucidglyph_status() {
    echo "=== Status do LucidGlyph ==="
    
    if detect_lucidglyph; then
        echo "Status: INSTALADO"
        
        if [ -f "/usr/share/lucidglyph/info" ]; then
            echo "Local: System-wide (/usr/share/lucidglyph/)"
            echo "Informações:"
            head -5 "/usr/share/lucidglyph/info" 2>/dev/null || echo "  Informações não disponíveis"
        elif [ -f "/usr/share/freetype-envision/info" ]; then
            echo "Local: System-wide (/usr/share/freetype-envision/)"
        elif [ -f "$HOME/.local/share/lucidglyph/info" ]; then
            echo "Local: User ($HOME/.local/share/lucidglyph/)"
        else
            echo "Local: Detectado por configurações de fontes"
        fi
    else
        echo "Status: NÃO INSTALADO"
    fi
    
    echo ""
    echo "Configurações de fontes encontradas:"
    
    local fontconfig_count=0
    if [ -d "/etc/fonts/conf.d" ]; then
        fontconfig_count=$(find "/etc/fonts/conf.d" -name "*lucidglyph*" -o -name "*freetype-envision*" 2>/dev/null | wc -l)
    fi
    
    local user_fontconfig_count=0
    if [ -d "$HOME/.config/fontconfig/conf.d" ]; then
        user_fontconfig_count=$(find "$HOME/.config/fontconfig/conf.d" -name "*lucidglyph*" -o -name "*freetype-envision*" 2>/dev/null | wc -l)
    fi
    
    echo "  Configurações system: $fontconfig_count"
    echo "  Configurações user: $user_fontconfig_count"
    echo
}

# 3. POWER SAVER (PSAVER) - MOVIDA PARA QUALIDADE DE VIDA - AI
check_psaver_status() {
    echo "=== Status do Power Saver (psaver) ==="
    
    echo "Configurações de energia atuais:"
    
    # Verificar governadores de CPU
    if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
        echo ""
        echo "CPU Governors:"
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            if [ -f "$cpu" ]; then
                cpu_num=$(echo "$cpu" | grep -o 'cpu[0-9]*')
                governor=$(cat "$cpu" 2>/dev/null || echo "N/A")
                echo "  $cpu_num: $governor"
            fi
        done
    fi
    
    # Verificar configurações de suspensão
    echo ""
    echo "Configurações de suspensão:"
    if command -v systemctl &> /dev/null; then
        systemctl status sleep.target 2>/dev/null | head -3
    fi
    
    # Verificar configurações de energia no GRUB
    echo ""
    echo "Parâmetros de energia no GRUB:"
    if [ -f "/etc/default/grub" ]; then
        grep -i "quiet\|mitigations\|mem_sleep\|processor" /etc/default/grub || echo "  Nenhum parâmetro específico encontrado"
    fi
    
    # Verificar se psaver já foi aplicado
    if [ -f "$HOME/.local/.psaver.state" ]; then
        echo ""
        echo "⚠ Power Saver já foi aplicado anteriormente (arquivo de estado presente)"
        cat "$HOME/.local/.psaver.state"
    fi
    echo
}

apply_power_saving_tweaks() {
    echo "Aplicando otimizações de energia..."
    
    # 1. Configurar governador powersave para CPU
    echo "1. Configurando CPU governor para powersave..."
    if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
        for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            if [ -f "$gov" ]; then
                echo "powersave" > "$gov" 2>/dev/null || true
            fi
        done
        
        # Criar serviço systemd para persistência
        cat > /etc/systemd/system/set-powersave-governor.service << EOF
[Unit]
Description=Set CPU governor to powersave
After=sysinit.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'

[Install]
WantedBy=multi-user.target
EOF
        
        cat > /usr/local/bin/set-powersave-governor.sh << 'EOF'
#!/bin/bash
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo powersave > "$gov" 2>/dev/null || true
done
EOF
        
        chmod +x /usr/local/bin/set-powersave-governor.sh
        systemctl enable set-powersave-governor.service
        echo "✓ Governor powersave habilitado"
    fi
    
    # 2. Configurar opções de energia no kernel (se não tiver split-lock desativado)
    echo "2. Configurando parâmetros de energia do kernel..."
    local grub_cfg="/etc/default/grub"
    if [ -f "$grub_cfg" ]; then
        cp "$grub_cfg" "${grub_cfg}.backup.psaver.$(date +%Y%m%d%H%M%S)"
        
        # Adicionar parâmetros de economia de energia
        if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$grub_cfg"; then
            current_cmdline=$(grep "GRUB_CMDLINE_LINUX_DEFAULT" "$grub_cfg" | cut -d'"' -f2)
            
            # Adicionar apenas parâmetros que não existem
            new_params=""
            for param in "processor.max_cstate=5" "intel_idle.max_cstate=9" "intel_pstate=passive" "mem_sleep_default=deep"; do
                if [[ ! "$current_cmdline" =~ "$param" ]]; then
                    new_params="$new_params $param"
                fi
            done
            
            if [ -n "$new_params" ]; then
                sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1$new_params\"/" "$grub_cfg"
                echo "✓ Parâmetros de energia adicionados ao GRUB"
            else
                echo "✓ Parâmetros de energia já presentes"
            fi
        fi
        
        grub-mkconfig -o /boot/grub/grub.cfg
        echo "✓ GRUB atualizado"
    fi
    
    # 3. Configurar TLP para laptops (se disponível/instalável)
    echo "3. Configurando gerenciamento de energia..."
    if ! command -v tlp &> /dev/null; then
        echo "Instalando TLP para gerenciamento de energia avançado..."
        pacman -S --noconfirm tlp tlp-rdw
        systemctl enable tlp
        systemctl start tlp
        echo "✓ TLP instalado e ativado"
    else
        systemctl enable tlp 2>/dev/null || true
        systemctl start tlp 2>/dev/null || true
        echo "✓ TLP já instalado"
    fi
    
    # 4. Configurar auto-cpufreq (opcional)
    echo "4. Configurando auto-cpufreq..."
    if ! command -v auto-cpufreq &> /dev/null; then
        echo "Instalando auto-cpufreq..."
        # Nota: auto-cpufreq não está nos repositórios oficiais do Arch
        # Esta é uma implementação simplificada
        cat > /usr/local/bin/auto-cpufreq-simple.sh << 'EOF'
#!/bin/bash
# Script simplificado de auto-cpufreq
while true; do
    # Verificar se está em AC ou bateria
    if [ -f /sys/class/power_supply/AC/online ]; then
        ac_status=$(cat /sys/class/power_supply/AC/online)
        if [ "$ac_status" -eq 1 ]; then
            # Conectado na tomada - usar performance
            governor="performance"
        else
            # Bateria - usar powersave
            governor="powersave"
        fi
    else
        # Não conseguiu detectar - usar conservative
        governor="conservative"
    fi
    
    # Aplicar governor
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -f "$gov" ]; then
            echo "$governor" > "$gov" 2>/dev/null || true
        fi
    done
    
    sleep 30
done
EOF
        
        chmod +x /usr/local/bin/auto-cpufreq-simple.sh
        
        # Criar serviço systemd
        cat > /etc/systemd/system/auto-cpufreq-simple.service << EOF
[Unit]
Description=Simple auto-cpufreq daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/auto-cpufreq-simple.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl enable auto-cpufreq-simple.service
        systemctl start auto-cpufreq-simple.service
        echo "✓ Auto-cpufreq simplificado configurado"
    else
        echo "✓ Auto-cpufreq já instalado"
    fi
    
    # 5. Configurar sysctl para economia de energia
    echo "5. Configurando parâmetros sysctl para energia..."
    cat > /etc/sysctl.d/99-powersave.conf << EOF
# Power saving optimizations
vm.dirty_writeback_centisecs = 1500
vm.dirty_expire_centisecs = 3000
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.swappiness = 10
vm.vfs_cache_pressure = 50

# Network power saving
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1

# Reduce VM stat interval
vm.stat_interval = 10
EOF
    
    sysctl -p /etc/sysctl.d/99-powersave.conf
    echo "✓ Parâmetros sysctl configurados"
    
    # 6. Configurar PCIe ASPM (Active State Power Management)
    echo "6. Configurando PCIe ASPM..."
    cat > /etc/udev/rules.d/90-pcie-aspm.rules << EOF
# Enable PCIe ASPM for power saving
ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"
EOF
    
    udevadm control --reload-rules
    echo "✓ PCIe ASPM configurado"
    
    # Criar arquivo de estado
    mkdir -p "$HOME/.local"
    echo "psaver_applied_on_$(date +%Y%m%d_%H%M%S)" > "$HOME/.local/.psaver.state"
    
    echo ""
    echo "✓ Power Saver configurado com sucesso!"
    echo ""
    echo "⚠ REINICIALIZAÇÃO NECESSÁRIA"
    echo "Para que todas as otimizações de energia tenham efeito completo,"
    echo "reinicie o sistema."
    echo ""
    echo "Otimizações aplicadas:"
    echo "  1. CPU governor powersave"
    echo "  2. Parâmetros de energia no kernel"
    echo "  3. TLP para gerenciamento de energia"
    echo "  4. Auto-cpufreq simplificado"
    echo "  5. Parâmetros sysctl otimizados"
    echo "  6. PCIe ASPM ativado"
}

remove_power_saving_tweaks() {
    echo "Removendo otimizações de energia..."
    
    # 1. Remover serviço powersave governor
    systemctl disable set-powersave-governor.service 2>/dev/null || true
    rm -f /etc/systemd/system/set-powersave-governor.service
    rm -f /usr/local/bin/set-powersave-governor.sh
    
    # 2. Remover parâmetros de energia do GRUB
    local grub_cfg="/etc/default/grub"
    if [ -f "$grub_cfg" ]; then
        sed -i 's/ processor.max_cstate=5//g' "$grub_cfg"
        sed -i 's/ intel_idle.max_cstate=9//g' "$grub_cfg"
        sed -i 's/ intel_pstate=passive//g' "$grub_cfg"
        sed -i 's/ mem_sleep_default=deep//g' "$grub_cfg"
        grub-mkconfig -o /boot/grub/grub.cfg
        echo "✓ Parâmetros de energia removidos do GRUB"
    fi
    
    # 3. Parar e desabilitar serviços
    systemctl disable auto-cpufreq-simple.service 2>/dev/null || true
    systemctl stop auto-cpufreq-simple.service 2>/dev/null || true
    rm -f /etc/systemd/system/auto-cpufreq-simple.service
    rm -f /usr/local/bin/auto-cpufreq-simple.sh
    
    # 4. Remover configurações sysctl
    rm -f /etc/sysctl.d/99-powersave.conf
    
    # 5. Remover regras udev
    rm -f /etc/udev/rules.d/90-pcie-aspm.rules
    
    # 6. Remover arquivo de estado
    rm -f "$HOME/.local/.psaver.state"
    
    echo "✓ Todas as otimizações de energia foram removidas"
}

configure_psaver() {
    clear
    echo "=== POWER SAVER (PSAVER) - OTIMIZAÇÕES DE ENERGIA (AI) ==="
    echo "Otimizações para reduzir consumo de energia e aumentar vida útil da bateria"
    echo ""
    
    check_psaver_status
    
    if [ -f "$HOME/.local/.psaver.state" ]; then
        echo "Power Saver já está configurado."
        read -p "Deseja: [1] Manter configuração, [2] Remover otimizações, [3] Ver detalhes: " choice
        case $choice in
            1)
                echo "Configuração mantida."
                ;;
            2)
                remove_power_saving_tweaks
                ;;
            3)
                echo ""
                echo "Detalhes da configuração atual:"
                if [ -f "$HOME/.local/.psaver.state" ]; then
                    echo "Arquivo de estado:"
                    cat "$HOME/.local/.psaver.state"
                fi
                echo ""
                echo "Serviços ativos:"
                systemctl is-active set-powersave-governor.service 2>/dev/null && echo "  ✓ set-powersave-governor.service: ATIVO"
                systemctl is-active auto-cpufreq-simple.service 2>/dev/null && echo "  ✓ auto-cpufreq-simple.service: ATIVO"
                systemctl is-active tlp.service 2>/dev/null && echo "  ✓ tlp.service: ATIVO"
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    else
        echo "Power Saver não está configurado."
        read -p "Deseja aplicar otimizações de energia? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            echo ""
            echo "AVISO: Estas otimizações podem reduzir levemente o desempenho"
            echo "em troca de economia de energia e maior vida útil da bateria."
            echo ""
            read -p "Continuar? (s/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                apply_power_saving_tweaks
            else
                echo "Operação cancelada."
            fi
        else
            echo "Operação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# 4. APPARMOR (Sistema de Segurança)
check_apparmor_status() {
    echo "=== Status do AppArmor ==="
    
    # Verificar se AppArmor está instalado
    if command -v aa-status &> /dev/null || pacman -Qi apparmor &> /dev/null; then
        echo "Status: INSTALADO"
        
        # Verificar se está ativo
        if systemctl is-active apparmor &> /dev/null; then
            echo "Serviço: ATIVO"
            echo ""
            echo "Perfis carregados:"
            aa-status 2>/dev/null | grep -A5 "profiles are loaded" || echo "  Não foi possível verificar perfis"
        else
            echo "Serviço: INATIVO"
        fi
        
        # Verificar se está habilitado no kernel
        echo ""
        echo "Parâmetros do kernel:"
        if grep -q "apparmor=1" /proc/cmdline 2>/dev/null; then
            echo "  ✓ AppArmor habilitado no kernel"
        else
            echo "  ✗ AppArmor NÃO habilitado no kernel"
        fi
    else
        echo "Status: NÃO INSTALADO"
    fi
    
    # Verificar configurações do GRUB
    echo ""
    echo "Configuração do GRUB:"
    if [ -f "/etc/default/grub" ]; then
        if grep -q "apparmor=1" /etc/default/grub 2>/dev/null; then
            echo "  ✓ AppArmor configurado no GRUB"
        else
            echo "  ✗ AppArmor NÃO configurado no GRUB"
        fi
    fi
    
    # Verificar systemd-boot
    if [ -d "/boot/loader/entries" ]; then
        echo ""
        echo "Systemd-boot detectado:"
        local found=0
        for entry in /boot/loader/entries/*.conf; do
            if [ -f "$entry" ] && grep -q "apparmor=1" "$entry" 2>/dev/null; then
                echo "  ✓ Configurado em: $(basename "$entry")"
                found=1
            fi
        done
        if [ $found -eq 0 ]; then
            echo "  ✗ Não configurado no systemd-boot"
        fi
    fi
    
    echo
}

install_apparmor() {
    echo "Instalando e configurando AppArmor..."
    
    # Verificar se AppArmor já está instalado
    if command -v aa-status &> /dev/null; then
        echo "✓ AppArmor já está instalado"
    else
        echo "Instalando pacote AppArmor..."
        pacman -S --noconfirm apparmor
        
        # Instalar utilitários adicionais se disponíveis
        echo "Instalando utilitários do AppArmor..."
        pacman -S --noconfirm apparmor-utils 2>/dev/null || echo "Utilitários adicionais não disponíveis"
    fi
    
    echo "Configurando AppArmor para inicialização..."
    
    # Configurar GRUB para habilitar AppArmor
    if [ -f "/etc/default/grub" ]; then
        echo "Configurando GRUB para habilitar AppArmor..."
        
        # Fazer backup do GRUB
        cp /etc/default/grub /etc/default/grub.backup.apparmor.$(date +%Y%m%d%H%M%S)
        
        # Adicionar parâmetros do AppArmor
        if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub; then
            current_cmdline=$(grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub | cut -d'"' -f2)
            
            # Verificar se já tem apparmor=1
            if [[ ! "$current_cmdline" =~ "apparmor=1" ]]; then
                # Verificar se já tem security=apparmor
                if [[ ! "$current_cmdline" =~ "security=apparmor" ]]; then
                    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 apparmor=1 security=apparmor"/' /etc/default/grub
                    echo "✓ Parâmetros do AppArmor adicionados ao GRUB"
                else
                    # Se já tem security=apparmor, adicionar apenas apparmor=1
                    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 apparmor=1"/' /etc/default/grub
                    echo "✓ Parâmetro apparmor=1 adicionado ao GRUB"
                fi
            else
                echo "✓ Parâmetros do AppArmor já presentes no GRUB"
            fi
        else
            # Se não encontrar GRUB_CMDLINE_LINUX_DEFAULT, adicionar
            echo 'GRUB_CMDLINE_LINUX_DEFAULT="apparmor=1 security=apparmor"' >> /etc/default/grub
            echo "✓ Linha GRUB_CMDLINE_LINUX_DEFAULT adicionada"
        fi
        
        # Atualizar GRUB
        echo "Atualizando configuração do GRUB..."
        grub-mkconfig -o /boot/grub/grub.cfg
        echo "✓ GRUB atualizado"
    fi
    
    # Configurar systemd-boot se estiver usando
    if [ -d "/boot/loader/entries" ]; then
        echo "Configurando AppArmor para systemd-boot..."
        for entry in /boot/loader/entries/*.conf; do
            if [ -f "$entry" ]; then
                # Fazer backup
                cp "$entry" "${entry}.backup.apparmor.$(date +%Y%m%d%H%M%S)"
                
                # Adicionar parâmetros
                if ! grep -q "apparmor=1" "$entry"; then
                    sed -i '/^options/ s/$/ apparmor=1 security=apparmor/' "$entry"
                    echo "✓ Configurado em: $(basename "$entry")"
                fi
            fi
        done
    fi
    
    # Habilitar e iniciar serviço do AppArmor
    echo "Habilitando serviço AppArmor..."
    systemctl enable apparmor
    systemctl start apparmor
    
    # Criar arquivo de estado
    mkdir -p "$HOME/.local"
    echo "apparmor_installed_on_$(date +%Y%m%d_%H%M%S)" > "$HOME/.local/.apparmor.state"
    
    echo ""
    echo "✓ AppArmor instalado e configurado com sucesso!"
    echo ""
    echo "⚠ REINICIALIZAÇÃO NECESSÁRIA"
    echo "Para que o AppArmor seja completamente habilitado,"
    echo "é necessário reiniciar o sistema."
    echo ""
    echo "Após reinicialização, verifique o status com:"
    echo "  sudo aa-status"
    echo ""
    echo "Para aprender perfis:"
    echo "  sudo aa-genprof <caminho_do_programa>"
    echo ""
    echo "Para aplicar um perfil:"
    echo "  sudo aa-enforce <nome_do_perfil>"
}

uninstall_apparmor() {
    echo "Desinstalando AppArmor..."
    
    # Parar e desabilitar serviço
    systemctl stop apparmor 2>/dev/null || true
    systemctl disable apparmor 2>/dev/null || true
    
    # Remover parâmetros do GRUB
    if [ -f "/etc/default/grub" ]; then
        echo "Removendo parâmetros do AppArmor do GRUB..."
        sed -i 's/ apparmor=1//g' /etc/default/grub
        sed -i 's/ security=apparmor//g' /etc/default/grub
        sed -i 's/apparmor=1 //g' /etc/default/grub
        sed -i 's/security=apparmor //g' /etc/default/grub
        
        # Atualizar GRUB
        grub-mkconfig -o /boot/grub/grub.cfg
        echo "✓ GRUB atualizado"
    fi
    
    # Remover de systemd-boot
    if [ -d "/boot/loader/entries" ]; then
        echo "Removendo de systemd-boot..."
        for entry in /boot/loader/entries/*.conf; do
            if [ -f "$entry" ]; then
                sed -i 's/ apparmor=1//g' "$entry"
                sed -i 's/ security=apparmor//g' "$entry"
                sed -i 's/apparmor=1 //g' "$entry"
                sed -i 's/security=apparmor //g' "$entry"
            fi
        done
    fi
    
    # Remover pacotes
    echo "Removendo pacotes do AppArmor..."
    pacman -Rns --noconfirm apparmor-utils 2>/dev/null || true
    pacman -Rns --noconfirm apparmor 2>/dev/null || true
    
    # Remover arquivo de estado
    rm -f "$HOME/.local/.apparmor.state"
    
    echo "✓ AppArmor desinstalado com sucesso!"
}

configure_apparmor() {
    clear
    echo "=== APPARMOR (Sistema de Segurança) ==="
    echo "Sistema de Controle de Acesso Mandatório (MAC) para Linux"
    echo "Fornece segurança baseada em perfis para aplicações"
    echo ""
    
    check_apparmor_status
    
    if [ -f "$HOME/.local/.apparmor.state" ] || command -v aa-status &> /dev/null; then
        echo "AppArmor já está instalado/configurado."
        read -p "Deseja: [1] Ver status detalhado, [2] Reconfigurar, [3] Desinstalar, [4] Voltar: " choice
        case $choice in
            1)
                echo ""
                echo "Status detalhado do AppArmor:"
                if command -v aa-status &> /dev/null; then
                    aa-status 2>/dev/null || echo "Não foi possível executar aa-status"
                else
                    echo "AppArmor não está instalado corretamente."
                fi
                echo ""
                echo "Perfis disponíveis:"
                find /etc/apparmor.d/ -name "*.profile" 2>/dev/null | head -10 | while read profile; do
                    echo "  $(basename "$profile")"
                done
                ;;
            2)
                echo "Reconfigurando AppArmor..."
                install_apparmor
                ;;
            3)
                uninstall_apparmor
                ;;
            4)
                return
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    else
        echo "AppArmor não está instalado."
        echo ""
        echo "O AppArmor fornece:"
        echo "  ✓ Controle de acesso mandatório para aplicações"
        echo "  ✓ Proteção contra vulnerabilidades"
        echo "  ✓ Isolamento de processos"
        echo "  ✓ Segurança baseada em perfis"
        echo ""
        echo "AVISO: O AppArmor pode causar conflitos com outras"
        echo "ferramentas de segurança como SELinux."
        echo ""
        read -p "Deseja instalar e configurar o AppArmor? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_apparmor
        else
            echo "Instalação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# 5. HWACCEL PARA FLATPAK (AI)
check_hwaccel_flatpak_status() {
    echo "=== Status do HWAccel para Flatpak ==="
    
    # Verificar se flatpak está instalado
    if ! command -v flatpak &> /dev/null; then
        echo "Flatpak: NÃO INSTALADO"
        echo "Esta otimização requer o Flatpak instalado."
        return 1
    fi
    
    echo "Flatpak: INSTALADO"
    
    # Verificar se as permissões já foram configuradas
    local hwaccel_config="$HOME/.config/hwaccel-flatpak.state"
    if [ -f "$hwaccel_config" ]; then
        echo "Status: CONFIGURADO"
        echo "Configuração aplicada em: $(cat "$hwaccel_config")"
    else
        echo "Status: NÃO CONFIGURADO"
    fi
    
    # Verificar permissões atuais
    echo ""
    echo "Permissões atuais do Flatpak:"
    flatpak list --app --columns=application | head -5 | while read app; do
        echo "  $app:"
        flatpak info "$app" | grep -E "(devel|filesystems|devices)" | head -3 || true
    done
    
    echo
}

install_hwaccel_flatpak() {
    echo "Configurando HWAccel para aplicações Flatpak..."
    
    # Verificar se flatpak está instalado
    if ! command -v flatpak &> /dev/null; then
        echo "Instalando Flatpak..."
        pacman -S --noconfirm flatpak
    fi
    
    echo "Configurando permissões para aceleração de hardware..."
    
    # Lista de aplicações comuns que se beneficiam de HWAccel
    local apps_to_configure=""
    
    # Obter lista de aplicações Flatpak instaladas
    local installed_apps=$(flatpak list --app --columns=application 2>/dev/null || true)
    
    if [ -n "$installed_apps" ]; then
        for app in $installed_apps; do
            # Configurar permissões para aceleração de hardware
            echo "Configurando $app..."
            
            # Adicionar permissões para acesso a dispositivos e arquivos
            flatpak override --user "$app" \
                --filesystem=host \
                --device=all \
                --share=network \
                --socket=wayland \
                --socket=x11 \
                --socket=pulseaudio \
                --socket=session-bus \
                --talk-name=org.freedesktop.Flatpak \
                --talk-name=org.freedesktop.Notifications \
                --env=GDK_BACKEND=x11 \
                --env=QT_QPA_PLATFORM=xcb \
                --env=MOZ_ENABLE_WAYLAND=1 \
                --env=SDL_VIDEODRIVER=wayland,x11 \
                --env=CLUTTER_BACKEND=wayland,x11 \
                --env=DISABLE_WAYLAND=0 2>/dev/null || true
        done
    else
        echo "Nenhuma aplicação Flatpak encontrada."
        echo "Instalando algumas aplicações comuns para configuração..."
        
        # Instalar algumas aplicações comuns
        local common_apps=(
            "org.mozilla.firefox"
            "com.spotify.Client"
            "org.videolan.VLC"
            "com.visualstudio.code"
            "com.discordapp.Discord"
        )
        
        for app in "${common_apps[@]}"; do
            echo "Instalando $app..."
            flatpak install --user --noninteractive flathub "$app" 2>/dev/null || true
            
            if flatpak list --app | grep -q "$app"; then
                # Configurar permissões
                flatpak override --user "$app" \
                    --filesystem=host \
                    --device=all \
                    --share=network \
                    --socket=wayland \
                    --socket=x11 \
                    --socket=pulseaudio \
                    --socket=session-bus \
                    --talk-name=org.freedesktop.Flatpak \
                    --talk-name=org.freedesktop.Notifications \
                    --env=GDK_BACKEND=x11 \
                    --env=QT_QPA_PLATFORM=xcb \
                    --env=MOZ_ENABLE_WAYLAND=1 \
                    --env=SDL_VIDEODRIVER=wayland,x11 \
                    --env=CLUTTER_BACKEND=wayland,x11 \
                    --env=DISABLE_WAYLAND=0 2>/dev/null || true
                
                apps_to_configure="$apps_to_configure $app"
            fi
        done
    fi
    
    # Configurar permissões globais para novas instalações
    echo "Configurando permissões globais..."
    
    flatpak override --user --filesystem=host 2>/dev/null || true
    flatpak override --user --device=all 2>/dev/null || true
    flatpak override --user --share=network 2>/dev/null || true
    flatpak override --user --socket=wayland --socket=x11 2>/dev/null || true
    
    # Criar arquivo de configuração personalizado para GPU
    local gpu_config="$HOME/.config/flatpak-hwaccel.conf"
    cat > "$gpu_config" << EOF
# Configuração de HWAccel para Flatpak
# Aplicações configuradas: $apps_to_configure

# Variáveis de ambiente para aceleração de hardware
export FLATPAK_GL_DRIVERS=host
export FLATPAK_ENABLE_HWACCEL=1

# Para NVIDIA
if [ -n "\$(lspci | grep -i nvidia)" ]; then
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __VK_LAYER_NV_optimus=NVIDIA_only
fi

# Para Intel
if [ -n "\$(lspci | grep -i intel.*graphics)" ]; then
    export MESA_LOADER_DRIVER_OVERRIDE=i965
    export INTEL_DEBUG=norbc
fi

# Para AMD
if [ -n "\$(lspci | grep -Ei 'amd.*(graphics|gpu)')" ]; then
    export AMD_DEBUG=nodcc
    export RADV_PERFTEST=aco
fi
EOF
    
    # Adicionar ao shell do usuário
    local shell_rc=""
    if [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    elif [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.profile" ]; then
        shell_rc="$HOME/.profile"
    fi
    
    if [ -n "$shell_rc" ]; then
        if ! grep -q "flatpak-hwaccel.conf" "$shell_rc"; then
            echo "" >> "$shell_rc"
            echo "# Configuração HWAccel para Flatpak" >> "$shell_rc"
            echo "if [ -f \"\$HOME/.config/flatpak-hwaccel.conf\" ]; then" >> "$shell_rc"
            echo "    source \"\$HOME/.config/flatpak-hwaccel.conf\"" >> "$shell_rc"
            echo "fi" >> "$shell_rc"
        fi
    fi
    
    # Criar arquivo de estado
    mkdir -p "$HOME/.config"
    echo "hwaccel_flatpak_configured_on_$(date +%Y%m%d_%H%M%S)" > "$HOME/.config/hwaccel-flatpak.state"
    
    echo ""
    echo "✓ HWAccel para Flatpak configurado com sucesso!"
    echo ""
    echo "Configurações aplicadas:"
    echo "  • Permissões de dispositivo e arquivos"
    echo "  • Sockets para Wayland/X11"
    echo "  • Variáveis de ambiente para GPU"
    echo "  • Configuração personalizada em: $gpu_config"
    echo ""
    echo "⚠ REINICIALIZAÇÃO OU NOVO LOGIN NECESSÁRIO"
    echo "Para que as mudanças tenham efeito, reinicie as aplicações Flatpak"
    echo "ou faça logout e login novamente."
}

uninstall_hwaccel_flatpak() {
    echo "Removendo configuração HWAccel para Flatpak..."
    
    # Remover overrides das aplicações
    local installed_apps=$(flatpak list --app --columns=application 2>/dev/null || true)
    
    if [ -n "$installed_apps" ]; then
        for app in $installed_apps; do
            echo "Removendo overrides de $app..."
            flatpak override --user --reset "$app" 2>/dev/null || true
        done
    fi
    
    # Remover overrides globais
    flatpak override --user --reset 2>/dev/null || true
    
    # Remover arquivo de configuração
    rm -f "$HOME/.config/flatpak-hwaccel.conf"
    rm -f "$HOME/.config/hwaccel-flatpak.state"
    
    # Remover do shell rc
    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ -f "$rc_file" ]; then
            sed -i '/# Configuração HWAccel para Flatpak/,+3d' "$rc_file"
            sed -i '/flatpak-hwaccel.conf/d' "$rc_file"
        fi
    done
    
    echo "✓ Configuração HWAccel para Flatpak removida com sucesso!"
}

configure_hwaccel_flatpak() {
    clear
    echo "=== HWACCEL PARA FLATPAK (Aceleração de Hardware) - AI ==="
    echo "Otimiza aplicações Flatpak para usar aceleração de hardware"
    echo "Melhora desempenho gráfico e de vídeo em aplicações empacotadas"
    echo ""
    
    check_hwaccel_flatpak_status
    
    local hwaccel_config="$HOME/.config/hwaccel-flatpak.state"
    
    if [ -f "$hwaccel_config" ]; then
        echo "HWAccel para Flatpak já está configurado."
        read -p "Deseja: [1] Manter configuração, [2] Reconfigurar, [3] Remover, [4] Ver detalhes: " choice
        case $choice in
            1)
                echo "Configuração mantida."
                ;;
            2)
                echo "Reconfigurando HWAccel para Flatpak..."
                install_hwaccel_flatpak
                ;;
            3)
                uninstall_hwaccel_flatpak
                ;;
            4)
                echo ""
                echo "Detalhes da configuração atual:"
                if [ -f "$hwaccel_config" ]; then
                    echo "Arquivo de estado:"
                    cat "$hwaccel_config"
                fi
                if [ -f "$HOME/.config/flatpak-hwaccel.conf" ]; then
                    echo ""
                    echo "Configuração de GPU:"
                    cat "$HOME/.config/flatpak-hwaccel.conf"
                fi
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    else
        echo "HWAccel para Flatpak não está configurado."
        read -p "Deseja configurar aceleração de hardware para aplicações Flatpak? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_hwaccel_flatpak
        else
            echo "Operação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# 6. DNSMASQ (Cache DNS Local) - AI
check_dnsmasq_status() {
    echo "=== Status do DNSMasq ==="
    
    # Verificar se dnsmasq está instalado
    if command -v dnsmasq &> /dev/null || systemctl is-active dnsmasq 2>/dev/null; then
        echo "Status: INSTALADO"
        
        # Verificar se serviço está ativo
        if systemctl is-active dnsmasq &> /dev/null; then
            echo "Serviço: ATIVO"
            systemctl status dnsmasq --no-pager -l | head -10
        else
            echo "Serviço: INATIVO"
        fi
        
        # Verificar configuração
        if [ -f "/etc/dnsmasq.conf" ]; then
            echo ""
            echo "Configuração do DNSMasq:"
            grep -v "^#" /etc/dnsmasq.conf | grep -v "^$" | head -10
        fi
        
        # Verificar se está sendo usado como cache DNS
        echo ""
        echo "Configuração de DNS do sistema:"
        cat /etc/resolv.conf | head -5
    else
        echo "Status: NÃO INSTALADO"
    fi
    
    echo
}

install_dnsmasq() {
    echo "Instalando e configurando DNSMasq..."
    
    # Instalar dnsmasq
    if ! command -v dnsmasq &> /dev/null; then
        echo "Instalando pacote dnsmasq..."
        pacman -S --noconfirm dnsmasq
    else
        echo "✓ DNSMasq já está instalado"
    fi
    
    # Fazer backup da configuração original
    if [ -f "/etc/dnsmasq.conf" ]; then
        cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup.$(date +%Y%m%d%H%M%S)
    fi
    
    # Criar configuração otimizada
    cat > /etc/dnsmasq.conf << EOF
# DNSMasq configuration - Optimized by Super Script
# Configuração básica
port=53
domain-needed
bogus-priv
no-resolv
no-poll

# Servidores DNS upstream (Cloudflare e Google)
server=1.1.1.1
server=1.0.0.1
server=8.8.8.8
server=8.8.4.4

# Cache
cache-size=10000
local-ttl=300
neg-ttl=60

# Performance
dns-forward-max=5000
stop-dns-rebind
rebind-localhost-ok
log-queries
log-async=20

# DHCP (desativado por padrão)
#dhcp-range=192.168.1.50,192.168.1.150,12h
#dhcp-option=3,192.168.1.1

# Local domains
local=/localnet/
domain=localnet
expand-hosts
EOF
    
    echo "✓ Configuração otimizada aplicada"
    
    # Configurar NetworkManager para usar DNSMasq
    echo "Configurando NetworkManager..."
    
    if [ -f "/etc/NetworkManager/NetworkManager.conf" ]; then
        cp /etc/NetworkManager/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf.backup.$(date +%Y%m%d%H%M%S)
        
        # Adicionar configuração para usar dnsmasq
        if ! grep -q "dnsmasq" /etc/NetworkManager/NetworkManager.conf; then
            sed -i '/^\[main\]/a dns=dnsmasq' /etc/NetworkManager/NetworkManager.conf
        fi
    fi
    
    # Criar configuração do NetworkManager para dnsmasq
    cat > /etc/NetworkManager/dnsmasq.d/01-super-script.conf << EOF
# DNSMasq configuration for NetworkManager
# Cache de DNS otimizado
cache-size=10000
no-resolv
server=1.1.1.1
server=1.0.0.1
server=8.8.8.8
server=8.8.4.4
EOF
    
    # Habilitar e iniciar serviço
    echo "Habilitando serviço dnsmasq..."
    systemctl enable dnsmasq
    systemctl start dnsmasq
    
    # Reiniciar NetworkManager
    systemctl restart NetworkManager
    
    # Criar arquivo de estado
    mkdir -p "$HOME/.local"
    echo "dnsmasq_installed_on_$(date +%Y%m%d_%H%M%S)" > "$HOME/.local/.dnsmasq.state"
    
    # Verificar se está funcionando
    sleep 2
    if systemctl is-active dnsmasq &> /dev/null; then
        echo "✓ DNSMasq instalado e ativado com sucesso!"
        echo ""
        echo "DNSMasq agora fornece:"
        echo "  • Cache DNS local (acelera resolução de nomes)"
        echo "  • Proteção contra domínios maliciosos"
        echo "  • Redução da dependência de DNS externos"
        echo ""
        echo "Para testar o cache DNS:"
        echo "  dig google.com | grep 'Query time'"
        echo ""
        echo "⚠ REINICIALIZAÇÃO OU NOVA CONEXÃO DE REDE NECESSÁRIA"
        echo "Para que as mudanças tenham efeito completo, reinicie o sistema"
        echo "ou reconecte-se à rede."
    else
        echo "⚠ DNSMasq instalado mas serviço não iniciou"
        echo "  Verifique com: systemctl status dnsmasq"
    fi
}

uninstall_dnsmasq() {
    echo "Desinstalando DNSMasq..."
    
    # Parar e desabilitar serviço
    systemctl stop dnsmasq 2>/dev/null || true
    systemctl disable dnsmasq 2>/dev/null || true
    
    # Remover configuração do NetworkManager
    if [ -f "/etc/NetworkManager/NetworkManager.conf" ]; then
        sed -i '/dns=dnsmasq/d' /etc/NetworkManager/NetworkManager.conf
    fi
    
    # Remover arquivos de configuração
    rm -f /etc/NetworkManager/dnsmasq.d/01-super-script.conf
    
    # Restaurar configuração original se existir backup
    if [ -f "/etc/dnsmasq.conf.backup" ]; then
        mv /etc/dnsmasq.conf.backup /etc/dnsmasq.conf
        echo "✓ Configuração original restaurada"
    elif [ -f "/etc/dnsmasq.conf" ]; then
        rm -f /etc/dnsmasq.conf
    fi
    
    # Reiniciar NetworkManager
    systemctl restart NetworkManager
    
    # Remover pacote
    pacman -Rns --noconfirm dnsmasq 2>/dev/null || true
    
    # Remover arquivo de estado
    rm -f "$HOME/.local/.dnsmasq.state"
    
    echo "✓ DNSMasq desinstalado com sucesso!"
}

configure_dnsmasq() {
    clear
    echo "=== DNSMASQ (Cache DNS Local) - AI ==="
    echo "Servidor de cache DNS local que acelera a resolução de nomes"
    echo "e fornece proteção adicional contra domínios maliciosos."
    echo ""
    
    check_dnsmasq_status
    
    if command -v dnsmasq &> /dev/null || systemctl is-active dnsmasq 2>/dev/null; then
        echo "DNSMasq já está instalado/configurado."
        read -p "Deseja: [1] Reconfigurar, [2] Desinstalar, [3] Ver status detalhado, [4] Voltar: " choice
        case $choice in
            1)
                echo "Reconfigurando DNSMasq..."
                install_dnsmasq
                ;;
            2)
                uninstall_dnsmasq
                ;;
            3)
                echo ""
                echo "Status detalhado do DNSMasq:"
                if systemctl is-active dnsmasq &> /dev/null; then
                    systemctl status dnsmasq --no-pager -l
                    echo ""
                    echo "Últimas consultas DNS:"
                    journalctl -u dnsmasq -n 20 --no-pager | grep "query" || echo "  Nenhuma consulta registrada"
                    echo ""
                    echo "Estatísticas de cache:"
                    echo "  Para ver estatísticas: dig @127.0.0.1 google.com | grep -A1 'SERVER'"
                else
                    echo "Serviço não está ativo."
                fi
                ;;
            4)
                return
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    else
        echo "DNSMasq não está instalado."
        read -p "Deseja instalar e configurar o DNSMasq? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_dnsmasq
        else
            echo "Instalação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# 7. GRUB-BTRFS (Snapshots no GRUB) - AI
check_grub_btrfs_status() {
    echo "=== Status do GRUB-BTRFS ==="
    
    # Verificar se o sistema de arquivos é BTRFS
    local root_fs=$(findmnt -n -o FSTYPE /)
    if [ "$root_fs" != "btrfs" ]; then
        echo "Sistema de arquivos raiz: $root_fs"
        echo "⚠ GRUB-BTRFS requer sistema de arquivos BTRFS na raiz (/)."
        return 1
    fi
    
    echo "Sistema de arquivos raiz: BTRFS ✓"
    
    # Verificar se grub-btrfs está instalado
    if command -v grub-btrfs &> /dev/null || pacman -Qi grub-btrfs &> /dev/null; then
        echo "Status: INSTALADO"
        
        # Verificar se serviço está ativo
        if systemctl is-active grub-btrfsd &> /dev/null; then
            echo "Serviço: ATIVO"
            systemctl status grub-btrfsd --no-pager -l | head -10
        else
            echo "Serviço: INATIVO"
        fi
        
        # Verificar snapshots disponíveis
        echo ""
        echo "Snapshots BTRFS disponíveis:"
        if command -v snapper &> /dev/null; then
            snapper list 2>/dev/null | head -10 || echo "  Nenhum snapshot encontrado (snapper não configurado)"
        else
            echo "  Snapper não instalado"
        fi
        
        # Verificar configuração do GRUB
        echo ""
        echo "Configuração do GRUB:"
        if [ -f "/etc/default/grub-btrfs/config" ]; then
            grep -v "^#" /etc/default/grub-btrfs/config | grep -v "^$" | head -10
        fi
    else
        echo "Status: NÃO INSTALADO"
    fi
    
    echo
}

install_grub_btrfs() {
    echo "Instalando e configurando GRUB-BTRFS..."
    
    # Verificar se o sistema de arquivos é BTRFS
    local root_fs=$(findmnt -n -o FSTYPE /)
    if [ "$root_fs" != "btrfs" ]; then
        echo "✗ Erro: Sistema de arquivos raiz não é BTRFS ($root_fs)"
        echo "GRUB-BTRFS requer sistema de arquivos BTRFS na raiz (/)."
        return 1
    fi
    
    # Instalar dependências
    echo "Instalando dependências..."
    pacman -S --noconfirm grub-btrfs snapper inotify-tools
    
    # Configurar snapper para a raiz
    echo "Configurando Snapper..."
    
    # Parar serviço snapper se estiver rodando
    systemctl stop snapper-timeline.timer 2>/dev/null || true
    systemctl stop snapper-cleanup.timer 2>/dev/null || true
    
    # Remover subvolume .snapshots existente se houver
    if [ -d "/.snapshots" ]; then
        echo "Removendo subvolume .snapshots existente..."
        btrfs subvolume delete -r /.snapshots 2>/dev/null || true
    fi
    
    # Criar configuração do snapper para a raiz
    snapper -c root create-config /
    
    # Configurar snapper
    echo "Configurando política de snapshots..."
    
    # Desativar snapshots automáticos por timeline
    snapper -c root set-config "TIMELINE_CREATE=no"
    
    # Configurar limites
    snapper -c root set-config "NUMBER_LIMIT=5"
    snapper -c root set-config "NUMBER_LIMIT_IMPORTANT=5"
    snapper -c root set-config "NUMBER_CLEANUP=yes"
    snapper -c root set-config "EMPTY_PRE_POST_CLEANUP=yes"
    
    # Criar snapshot inicial
    echo "Criando snapshot inicial..."
    snapper -c root create --description "Snapshot inicial - Super Script"
    
    # Configurar grub-btrfs
    echo "Configurando GRUB-BTRFS..."
    
    # Habilitar serviço grub-btrfsd
    systemctl enable grub-btrfsd
    systemctl start grub-btrfsd
    
    # Atualizar GRUB para incluir snapshots
    echo "Atualizando GRUB..."
    grub-mkconfig -o /boot/grub/grub.cfg
    
    # Criar arquivo de estado
    mkdir -p "$HOME/.local"
    echo "grub_btrfs_installed_on_$(date +%Y%m%d_%H%M%S)" > "$HOME/.local/.grub-btrfs.state"
    
    echo ""
    echo "✓ GRUB-BTRFS instalado e configurado com sucesso!"
    echo ""
    echo "Funcionalidades ativadas:"
    echo "  • Snapshots BTRFS gerenciados pelo snapper"
    echo "  • Snapshots listados no menu do GRUB"
    echo "  • Serviço automático para atualizar GRUB com novos snapshots"
    echo ""
    echo "Para criar um snapshot manualmente:"
    echo "  sudo snapper -c root create --description 'Meu snapshot'"
    echo ""
    echo "Para listar snapshots:"
    echo "  sudo snapper -c root list"
    echo ""
    echo "⚠ REINICIALIZAÇÃO RECOMENDADA"
    echo "Reinicie o sistema para ver os snapshots no menu do GRUB."
}

uninstall_grub_btrfs() {
    echo "Desinstalando GRUB-BTRFS..."
    
    # Parar e desabilitar serviços
    systemctl stop grub-btrfsd 2>/dev/null || true
    systemctl disable grub-btrfsd 2>/dev/null || true
    
    systemctl stop snapper-timeline.timer 2>/dev/null || true
    systemctl stop snapper-cleanup.timer 2>/dev/null || true
    systemctl disable snapper-timeline.timer 2>/dev/null || true
    systemctl disable snapper-cleanup.timer 2>/dev/null || true
    
    # Remover snapshots
    if command -v snapper &> /dev/null; then
        echo "Removendo snapshots..."
        snapper -c root list | awk 'NR>2 {print $1}' | while read snapshot; do
            snapper -c root delete "$snapshot" 2>/dev/null || true
        done
    fi
    
    # Remover configuração do snapper
    if [ -d "/etc/snapper/configs" ]; then
        rm -rf /etc/snapper/configs/root
    fi
    
    # Remover subvolume .snapshots
    if [ -d "/.snapshots" ]; then
        btrfs subvolume delete -r /.snapshots 2>/dev/null || true
    fi
    
    # Remover pacotes
    pacman -Rns --noconfirm grub-btrfs snapper 2>/dev/null || true
    
    # Atualizar GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    
    # Remover arquivo de estado
    rm -f "$HOME/.local/.grub-btrfs.state"
    
    echo "✓ GRUB-BTRFS desinstalado com sucesso!"
}

configure_grub_btrfs() {
    clear
    echo "=== GRUB-BTRFS (Snapshots no GRUB) - AI ==="
    echo "Integra snapshots BTRFS com o GRUB para boot a partir de snapshots"
    echo "Permite reverter para snapshots anteriores diretamente pelo bootloader"
    echo ""
    
    check_grub_btrfs_status
    
    if [ -f "$HOME/.local/.grub-btrfs.state" ] || command -v grub-btrfs &> /dev/null; then
        echo "GRUB-BTRFS já está instalado/configurado."
        read -p "Deseja: [1] Ver status detalhado, [2] Reconfigurar, [3] Desinstalar, [4] Voltar: " choice
        case $choice in
            1)
                echo ""
                echo "Status detalhado do GRUB-BTRFS:"
                if systemctl is-active grub-btrfsd &> /dev/null; then
                    systemctl status grub-btrfsd --no-pager -l
                    echo ""
                    echo "Snapshots disponíveis:"
                    snapper -c root list 2>/dev/null || echo "  Snapper não configurado ou sem snapshots"
                else
                    echo "Serviço não está ativo."
                fi
                ;;
            2)
                echo "Reconfigurando GRUB-BTRFS..."
                install_grub_btrfs
                ;;
            3)
                uninstall_grub_btrfs
                ;;
            4)
                return
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    else
        local root_fs=$(findmnt -n -o FSTYPE /)
        if [ "$root_fs" != "btrfs" ]; then
            echo "⚠ AVISO: Sistema de arquivos raiz não é BTRFS ($root_fs)"
            echo "GRUB-BTRFS requer sistema de arquivos BTRFS na raiz (/)."
            read -p "Pressione Enter para continuar..."
            return
        fi
        
        echo "GRUB-BTRFS não está instalado."
        echo ""
        echo "Esta funcionalidade requer:"
        echo "  • Sistema de arquivos BTRFS na raiz (/)"
        echo "  • GRUB como bootloader"
        echo "  • Snapper para gerenciamento de snapshots"
        echo ""
        echo "Benefícios:"
        echo "  • Boot a partir de snapshots BTRFS"
        echo "  • Reversão fácil para snapshots anteriores"
        echo "  • Backup automático do sistema"
        echo ""
        
        read -p "Deseja instalar e configurar o GRUB-BTRFS? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_grub_btrfs
        else
            echo "Instalação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# 8. MICROSOFT CORE FONTS
check_mscorefonts_status() {
    echo "=== Status do Microsoft Core Fonts ==="
    
    # Verificar se as fontes estão instaladas
    local fonts_dir="$HOME/.local/share/fonts/mscorefonts"
    local system_fonts_dir="/usr/share/fonts/mscorefonts"
    
    if [ -d "$fonts_dir" ] || [ -d "$system_fonts_dir" ]; then
        echo "Status: INSTALADO"
        
        if [ -d "$fonts_dir" ]; then
            echo "Local: User ($fonts_dir)"
            echo "Fontes encontradas:"
            find "$fonts_dir" -name "*.ttf" -o -name "*.TTF" | head -5 | while read font; do
                echo "  $(basename "$font")"
            done
            local count=$(find "$fonts_dir" -name "*.ttf" -o -name "*.TTF" 2>/dev/null | wc -l)
            echo "  Total: $count fontes"
        fi
        
        if [ -d "$system_fonts_dir" ]; then
            echo "Local: System ($system_fonts_dir)"
        fi
    else
        echo "Status: NÃO INSTALADO"
    fi
    
    echo
}

install_mscorefonts() {
    echo "Instalando Microsoft Core Fonts..."
    
    # Instalar dependências
    echo "Instalando dependências..."
    pacman -S --noconfirm cabextract wget
    
    # Criar diretório para fontes
    local fonts_dir="$HOME/.local/share/fonts/mscorefonts"
    mkdir -p "$fonts_dir"
    mkdir -p /tmp/mscorefonts
    
    echo "Baixando Microsoft Core Fonts..."
    
    # Lista de fontes a serem baixadas
    local fonts=(
        "https://sourceforge.net/projects/corefonts/files/the%20fonts/final/andale32.exe"
        "https://sourceforge.net/projects/corefonts/files/the%20fonts/final/arial32.exe"
        "https://sourceforge.net/projects/corefonts/files/the%20fonts/final/arialb32.exe"
        "https://sourceforge.net/projects/corefonts/files/the%20fonts/final/comic32.exe"
        "https://sourceforge.net/projects/corefonts/files/the%20fonts/final/courie32.exe"
        "https://sourceforge.net/projects/corefonts/files/the%20fonts/final/georgi32.exe"
        "https://sourceforge.net/projects/corefonts/files/the%20fonts/final/impact32.exe"
        "https://sourceforge.net/projects/corefonts/files/the%20fonts/final/times32.exe"
        "https://sourceforge.net/projects/corefonts/files/the%20fonts/final/trebuc32.exe"
        "https://sourceforge.net/projects/corefonts/files/the%20fonts/final/verdan32.exe"
        "https://sourceforge.net/projects/corefonts/files/the%20fonts/final/webdin32.exe"
    )
    
    # Baixar e extrair cada fonte
    for font_url in "${fonts[@]}"; do
        local font_file=$(basename "$font_url")
        echo "Processando $font_file..."
        
        # Baixar
        wget -q "$font_url" -O "/tmp/mscorefonts/$font_file"
        
        # Extrair arquivos .ttf
        cabextract -q -d "/tmp/mscorefonts" -F "*.ttf" "/tmp/mscorefonts/$font_file" 2>/dev/null || true
        cabextract -q -d "/tmp/mscorefonts" -F "*.TTF" "/tmp/mscorefonts/$font_file" 2>/dev/null || true
    done
    
    # Copiar fontes para o diretório do usuário
    echo "Instalando fontes..."
    find /tmp/mscorefonts -name "*.ttf" -o -name "*.TTF" | while read font; do
        cp "$font" "$fonts_dir/"
    done
    
    # Atualizar cache de fontes
    echo "Atualizando cache de fontes..."
    fc-cache -f "$fonts_dir"
    
    # Limpar arquivos temporários
    rm -rf /tmp/mscorefonts
    
    # Criar arquivo de estado
    mkdir -p "$HOME/.local"
    echo "mscorefonts_installed_on_$(date +%Y%m%d_%H%M%S)" > "$HOME/.local/.mscorefonts.state"
    
    echo ""
    echo "✓ Microsoft Core Fonts instaladas com sucesso!"
    echo "Fontes instaladas em: $fonts_dir"
    echo ""
    echo "Fontes incluídas:"
    echo "  • Andale Mono"
    echo "  • Arial"
    echo "  • Arial Black"
    echo "  • Comic Sans MS"
    echo "  • Courier New"
    echo "  • Georgia"
    echo "  • Impact"
    echo "  • Times New Roman"
    echo "  • Trebuchet MS"
    echo "  • Verdana"
    echo "  • Webdings"
    echo ""
    echo "⚠ REINICIALIZAÇÃO DE APLICAÇÕES NECESSÁRIA"
    echo "Para que as fontes sejam reconhecidas, reinicie suas aplicações."
}

uninstall_mscorefonts() {
    echo "Desinstalando Microsoft Core Fonts..."
    
    # Remover diretório de fontes do usuário
    local fonts_dir="$HOME/.local/share/fonts/mscorefonts"
    if [ -d "$fonts_dir" ]; then
        rm -rf "$fonts_dir"
        echo "✓ Fontes do usuário removidas"
    fi
    
    # Remover diretório de fontes do sistema (se instalado lá)
    local system_fonts_dir="/usr/share/fonts/mscorefonts"
    if [ -d "$system_fonts_dir" ]; then
        rm -rf "$system_fonts_dir"
        echo "✓ Fontes do sistema removidas"
    fi
    
    # Atualizar cache de fontes
    fc-cache -f
    
    # Remover arquivo de estado
    rm -f "$HOME/.local/.mscorefonts.state"
    
    echo "✓ Microsoft Core Fonts desinstaladas com sucesso!"
}

configure_mscorefonts() {
    clear
    echo "=== MICROSOFT CORE FONTS ==="
    echo "Instala as fontes padrão da Microsoft para melhor compatibilidade"
    echo "com documentos e aplicações que esperam essas fontes."
    echo ""
    
    check_mscorefonts_status
    
    local fonts_dir="$HOME/.local/share/fonts/mscorefonts"
    
    if [ -d "$fonts_dir" ] || [ -f "$HOME/.local/.mscorefonts.state" ]; then
        echo "Microsoft Core Fonts já estão instaladas."
        read -p "Deseja: [1] Manter instalação, [2] Reinstalar, [3] Desinstalar, [4] Ver fontes instaladas: " choice
        case $choice in
            1)
                echo "Instalação mantida."
                ;;
            2)
                echo "Reinstalando Microsoft Core Fonts..."
                uninstall_mscorefonts
                install_mscorefonts
                ;;
            3)
                uninstall_mscorefonts
                ;;
            4)
                echo ""
                echo "Fontes instaladas:"
                if [ -d "$fonts_dir" ]; then
                    find "$fonts_dir" -name "*.ttf" -o -name "*.TTF" | while read font; do
                        echo "  • $(basename "$font")"
                    done
                    echo ""
                    echo "Total: $(find "$fonts_dir" -name "*.ttf" -o -name "*.TTF" 2>/dev/null | wc -l) fontes"
                else
                    echo "  Nenhuma fonte encontrada."
                fi
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    else
        echo "Microsoft Core Fonts não estão instaladas."
        echo ""
        echo "Fontes incluídas na instalação:"
        echo "  • Andale Mono, Arial, Arial Black"
        echo "  • Comic Sans MS, Courier New"
        echo "  • Georgia, Impact, Times New Roman"
        echo "  • Trebuchet MS, Verdana, Webdings"
        echo ""
        read -p "Deseja instalar as Microsoft Core Fonts? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_mscorefonts
        else
            echo "Instalação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# 9. THUMBNAILER (Miniaturas de Vídeo)
check_thumbnailer_status() {
    echo "=== Status do Thumbnailer ==="
    
    # Verificar se ffmpegthumbnailer está instalado
    if command -v ffmpegthumbnailer &> /dev/null; then
        echo "Status: INSTALADO"
        echo "Versão: $(ffmpegthumbnailer --version 2>/dev/null | head -1 || echo "Desconhecida")"
        
        # Verificar se está configurado como thumbnailer padrão
        if [ -f "/usr/share/thumbnailers/ffmpegthumbnailer.thumbnailer" ]; then
            echo "Thumbnailer padrão: CONFIGURADO"
        else
            echo "Thumbnailer padrão: NÃO CONFIGURADO"
        fi
    else
        echo "Status: NÃO INSTALADO"
    fi
    
    echo
}

install_thumbnailer() {
    echo "Instalando e configurando Thumbnailer..."
    
    # Instalar ffmpegthumbnailer
    if ! command -v ffmpegthumbnailer &> /dev/null; then
        echo "Instalando ffmpegthumbnailer..."
        pacman -S --noconfirm ffmpegthumbnailer
    else
        echo "✓ ffmpegthumbnailer já está instalado"
    fi
    
    # Criar arquivo de configuração para thumbnailer
    echo "Configurando thumbnailer padrão..."
    
    local thumbnailer_dir="/usr/share/thumbnailers"
    local thumbnailer_file="$thumbnailer_dir/ffmpegthumbnailer.thumbnailer"
    
    if [ ! -f "$thumbnailer_file" ]; then
        sudo tee "$thumbnailer_file" > /dev/null << EOF
[Thumbnailer Entry]
TryExec=ffmpegthumbnailer
Exec=ffmpegthumbnailer -s %s -i %i -o %o -c png -f
MimeType=video/mp4;video/quicktime;video/x-msvideo;video/x-ms-wmv;video/x-flv;video/x-matroska;video/webm;video/3gpp;video/3gpp2;video/dv;video/mpeg;video/ogg;video/x-ogm+ogg;application/ogg;application/x-ogg;video/x-ms-asf;audio/x-ms-wma;audio/x-ms-asf;
EOF
        echo "✓ Thumbnailer configurado para formatos de vídeo"
    fi
    
    # Configurar GNOME thumbnailer se estiver em uso
    if [ -d "/usr/share/gnome-shell" ]; then
        echo "Configurando para GNOME..."
        gsettings set org.gnome.desktop.thumbnailers disable-all false
        gsettings set org.gnome.desktop.thumbnail-cache maximum-size 512
    fi
    
    # Configurar cache maior para thumbnails
    local user_thumbnail_cache="$HOME/.cache/thumbnails"
    mkdir -p "$user_thumbnail_cache"
    
    # Criar arquivo de estado
    mkdir -p "$HOME/.local"
    echo "thumbnailer_installed_on_$(date +%Y%m%d_%H%M%S)" > "$HOME/.local/.thumbnailer.state"
    
    echo ""
    echo "✓ Thumbnailer instalado e configurado com sucesso!"
    echo ""
    echo "Formatos suportados:"
    echo "  • MP4, AVI, MKV, WebM, MOV, WMV, FLV"
    echo "  • MPEG, OGG, 3GP, ASF, WMA"
    echo ""
    echo "Para forçar regeneração de miniaturas:"
    echo "  rm -rf ~/.cache/thumbnails/*"
    echo ""
    echo "⚠ REINICIALIZAÇÃO DO GERENCIADOR DE ARQUIVOS NECESSÁRIA"
    echo "Reinicie o gerenciador de arquivos (nautilus, nemo, thunar, etc.)"
    echo "para que as miniaturas sejam geradas automaticamente."
}

uninstall_thumbnailer() {
    echo "Desinstalando Thumbnailer..."
    
    # Remover arquivo de configuração do thumbnailer
    local thumbnailer_file="/usr/share/thumbnailers/ffmpegthumbnailer.thumbnailer"
    if [ -f "$thumbnailer_file" ]; then
        sudo rm -f "$thumbnailer_file"
        echo "✓ Configuração do thumbnailer removida"
    fi
    
    # Remover pacote
    pacman -Rns --noconfirm ffmpegthumbnailer 2>/dev/null || true
    
    # Limpar cache de thumbnails
    rm -rf "$HOME/.cache/thumbnails" 2>/dev/null || true
    
    # Remover arquivo de estado
    rm -f "$HOME/.local/.thumbnailer.state"
    
    echo "✓ Thumbnailer desinstalado com sucesso!"
}

configure_thumbnailer() {
    clear
    echo "=== THUMBNAILER (Miniaturas de Vídeo) ==="
    echo "Gera miniaturas (thumbnails) para arquivos de vídeo"
    echo "em gerenciadores de arquivos como Nautilus, Nemo, Thunar, etc."
    echo ""
    
    check_thumbnailer_status
    
    if command -v ffmpegthumbnailer &> /dev/null || [ -f "$HOME/.local/.thumbnailer.state" ]; then
        echo "Thumbnailer já está instalado/configurado."
        read -p "Deseja: [1] Reconfigurar, [2] Desinstalar, [3] Ver status detalhado, [4] Voltar: " choice
        case $choice in
            1)
                echo "Reconfigurando Thumbnailer..."
                install_thumbnailer
                ;;
            2)
                uninstall_thumbnailer
                ;;
            3)
                echo ""
                echo "Status detalhado do Thumbnailer:"
                if command -v ffmpegthumbnailer &> /dev/null; then
                    echo "Versão detalhada:"
                    ffmpegthumbnailer --version
                    echo ""
                    echo "Formatos suportados:"
                    ffmpegthumbnailer --help 2>/dev/null | grep -A5 "formats" || true
                fi
                ;;
            4)
                return
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    else
        echo "Thumbnailer não está instalado."
        echo ""
        echo "Benefícios da instalação:"
        echo "  • Miniaturas para arquivos de vídeo no gerenciador de arquivos"
        echo "  • Suporte a múltiplos formatos (MP4, AVI, MKV, etc.)"
        echo "  • Integração automática com GNOME, KDE, XFCE"
        echo ""
        read -p "Deseja instalar o Thumbnailer? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_thumbnailer
        else
            echo "Instalação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# 10. BTRFS ASSISTANT (Gerenciador BTRFS)
check_btrfs_assistant_status() {
    echo "=== Status do BTRFS Assistant ==="
    
    # Verificar se o sistema de arquivos é BTRFS
    local root_fs=$(findmnt -n -o FSTYPE /)
    if [ "$root_fs" != "btrfs" ]; then
        echo "Sistema de arquivos raiz: $root_fs"
        echo "⚠ BTRFS Assistant requer sistema de arquivos BTRFS."
        return 1
    fi
    
    echo "Sistema de arquivos raiz: BTRFS ✓"
    
    # Verificar se btrfs-assistant está instalado
    if command -v btrfs-assistant &> /dev/null || pacman -Qi btrfs-assistant &> /dev/null; then
        echo "Status: INSTALADO"
        
        # Verificar se snapper também está instalado
        if command -v snapper &> /dev/null; then
            echo "Snapper: INSTALADO"
        else
            echo "Snapper: NÃO INSTALADO (recomendado)"
        fi
    else
        echo "Status: NÃO INSTALADO"
    fi
    
    # Verificar subvolumes BTRFS
    echo ""
    echo "Subvolumes BTRFS atuais:"
    btrfs subvolume list / 2>/dev/null | head -5 || echo "  Não foi possível listar subvolumes"
    
    echo
}

install_btrfs_assistant() {
    echo "Instalando e configurando BTRFS Assistant..."
    
    # Verificar se o sistema de arquivos é BTRFS
    local root_fs=$(findmnt -n -o FSTYPE /)
    if [ "$root_fs" != "btrfs" ]; then
        echo "✗ Erro: Sistema de arquivos raiz não é BTRFS ($root_fs)"
        echo "BTRFS Assistant requer sistema de arquivos BTRFS."
        return 1
    fi
    
    # Instalar btrfs-assistant e snapper
    echo "Instalando pacotes..."
    pacman -S --noconfirm btrfs-assistant snapper
    
    # Configurar snapper para a raiz se não estiver configurado
    if ! snapper -c root list-config 2>/dev/null; then
        echo "Configurando Snapper para a raiz..."
        
        # Parar serviços do snapper se estiverem rodando
        systemctl stop snapper-timeline.timer 2>/dev/null || true
        systemctl stop snapper-cleanup.timer 2>/dev/null || true
        
        # Remover subvolume .snapshots existente se houver
        if [ -d "/.snapshots" ]; then
            btrfs subvolume delete -r /.snapshots 2>/dev/null || true
        fi
        
        # Criar configuração do snapper
        snapper -c root create-config /
        
        # Configurar política de snapshots
        snapper -c root set-config "TIMELINE_CREATE=no"
        snapper -c root set-config "NUMBER_LIMIT=10"
        snapper -c root set-config "NUMBER_LIMIT_IMPORTANT=10"
        snapper -c root set-config "NUMBER_CLEANUP=yes"
        snapper -c root set-config "EMPTY_PRE_POST_CLEANUP=yes"
        
        # Criar snapshot inicial
        snapper -c root create --description "Configuração inicial - BTRFS Assistant"
        
        # Habilitar serviços do snapper
        systemctl enable snapper-cleanup.timer
        systemctl start snapper-cleanup.timer
    fi
    
    # Criar arquivo de estado
    mkdir -p "$HOME/.local"
    echo "btrfs_assistant_installed_on_$(date +%Y%m%d_%H%M%S)" > "$HOME/.local/.btrfs-assistant.state"
    
    echo ""
    echo "✓ BTRFS Assistant instalado e configurado com sucesso!"
    echo ""
    echo "Funcionalidades disponíveis:"
    echo "  • Interface gráfica para gerenciamento BTRFS"
    echo "  • Criação e restauração de snapshots"
    echo "  • Balanceamento de dados"
    echo "  • Defrag e scrub"
    echo "  • Gerenciamento de subvolumes"
    echo ""
    echo "Para iniciar o BTRFS Assistant:"
    echo "  btrfs-assistant"
    echo ""
    echo "Ou procure por 'BTRFS Assistant' no menu de aplicações."
}

uninstall_btrfs_assistant() {
    echo "Desinstalando BTRFS Assistant..."
    
    # Parar serviços do snapper
    systemctl stop snapper-timeline.timer 2>/dev/null || true
    systemctl stop snapper-cleanup.timer 2>/dev/null || true
    systemctl disable snapper-timeline.timer 2>/dev/null || true
    systemctl disable snapper-cleanup.timer 2>/dev/null || true
    
    # Remover configuração do snapper
    if [ -d "/etc/snapper/configs" ]; then
        rm -rf /etc/snapper/configs/root
    fi
    
    # Remover subvolume .snapshots (cuidado!)
    echo "AVISO: Isto removerá todos os snapshots BTRFS."
    read -p "Deseja remover o subvolume .snapshots? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        if [ -d "/.snapshots" ]; then
            btrfs subvolume delete -r /.snapshots 2>/dev/null || true
            echo "✓ Subvolume .snapshots removido"
        fi
    fi
    
    # Remover pacotes
    pacman -Rns --noconfirm btrfs-assistant snapper 2>/dev/null || true
    
    # Remover arquivo de estado
    rm -f "$HOME/.local/.btrfs-assistant.state"
    
    echo "✓ BTRFS Assistant desinstalado com sucesso!"
}

configure_btrfs_assistant() {
    clear
    echo "=== BTRFS ASSISTANT (Gerenciador BTRFS) ==="
    echo "Interface gráfica para gerenciamento avançado de sistemas de arquivos BTRFS"
    echo "Inclui snapshots, balanceamento, defrag e muito mais."
    echo ""
    
    check_btrfs_assistant_status
    
    if [ -f "$HOME/.local/.btrfs-assistant.state" ] || command -v btrfs-assistant &> /dev/null; then
        echo "BTRFS Assistant já está instalado/configurado."
        read -p "Deseja: [1] Ver status detalhado, [2] Reconfigurar, [3] Desinstalar, [4] Voltar: " choice
        case $choice in
            1)
                echo ""
                echo "Status detalhado do BTRFS Assistant:"
                if command -v btrfs-assistant &> /dev/null; then
                    echo "Versão: $(btrfs-assistant --version 2>/dev/null || echo "Desconhecida")"
                fi
                if command -v snapper &> /dev/null; then
                    echo ""
                    echo "Snapshots disponíveis:"
                    snapper -c root list 2>/dev/null | head -10 || echo "  Nenhum snapshot encontrado"
                fi
                echo ""
                echo "Uso do sistema de arquivos BTRFS:"
                btrfs filesystem usage / 2>/dev/null | head -10 || echo "  Não foi possível obter informações"
                ;;
            2)
                echo "Reconfigurando BTRFS Assistant..."
                install_btrfs_assistant
                ;;
            3)
                uninstall_btrfs_assistant
                ;;
            4)
                return
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    else
        local root_fs=$(findmnt -n -o FSTYPE /)
        if [ "$root_fs" != "btrfs" ]; then
            echo "⚠ AVISO: Sistema de arquivos raiz não é BTRFS ($root_fs)"
            echo "BTRFS Assistant requer sistema de arquivos BTRFS."
            read -p "Pressione Enter para continuar..."
            return
        fi
        
        echo "BTRFS Assistant não está instalado."
        echo ""
        echo "Esta ferramenta fornece:"
        echo "  • Interface gráfica amigável para BTRFS"
        echo "  • Gerenciamento de snapshots com Snapper"
        echo "  • Balanceamento e otimização do sistema de arquivos"
        echo "  • Monitoramento de integridade dos dados"
        echo "  • Gerenciamento de subvolumes e quotas"
        echo ""
        read -p "Deseja instalar o BTRFS Assistant? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_btrfs_assistant
        else
            echo "Instalação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# 11. IWD (iNet Wireless Daemon)
check_iwd_status() {
    echo "=== Status do IWD (iNet Wireless Daemon) ==="
    
    # Verificar se há adaptador WiFi
    local has_wifi=0
    for iface in /sys/class/net/*; do
        if [ -d "$iface/wireless" ]; then
            has_wifi=1
            break
        fi
    done
    
    if [ $has_wifi -eq 0 ]; then
        echo "Adaptador WiFi: NÃO DETECTADO"
        echo "IWD não é necessário neste sistema."
        return 1
    fi
    
    echo "Adaptador WiFi: DETECTADO ✓"
    
    # Verificar se iwd está instalado
    if command -v iwd &> /dev/null || systemctl is-active iwd 2>/dev/null; then
        echo "Status: INSTALADO"
        
        # Verificar se serviço está ativo
        if systemctl is-active iwd &> /dev/null; then
            echo "Serviço: ATIVO"
            systemctl status iwd --no-pager -l | head -10
        else
            echo "Serviço: INATIVO"
        fi
        
        # Verificar backend do NetworkManager
        echo ""
        echo "Backend do NetworkManager:"
        if [ -f "/etc/NetworkManager/conf.d/iwd.conf" ]; then
            echo "  ✓ Configurado para usar IWD"
            cat /etc/NetworkManager/conf.d/iwd.conf
        else
            echo "  ✗ Usando wpa_supplicant (padrão)"
        fi
    else
        echo "Status: NÃO INSTALADO"
    fi
    
    # Verificar status do wpa_supplicant
    echo ""
    echo "Status do wpa_supplicant:"
    if systemctl is-active wpa_supplicant &> /dev/null; then
        echo "  ✓ ATIVO (será desativado se IWD for instalado)"
    else
        echo "  ✗ INATIVO"
    fi
    
    echo
}

install_iwd() {
    echo "Instalando e configurando IWD..."
    
    # Verificar se há adaptador WiFi
    local has_wifi=0
    for iface in /sys/class/net/*; do
        if [ -d "$iface/wireless" ]; then
            has_wifi=1
            break
        fi
    done
    
    if [ $has_wifi -eq 0 ]; then
        echo "✗ Erro: Nenhum adaptador WiFi detectado."
        echo "IWD não é necessário neste sistema."
        return 1
    fi
    
    # Instalar iwd
    echo "Instalando pacote iwd..."
    pacman -S --noconfirm iwd
    
    # Parar wpa_supplicant
    echo "Parando wpa_supplicant..."
    systemctl stop wpa_supplicant 2>/dev/null || true
    systemctl disable wpa_supplicant 2>/dev/null || true
    
    # Configurar NetworkManager para usar IWD
    echo "Configurando NetworkManager para usar IWD..."
    
    local nm_conf_dir="/etc/NetworkManager/conf.d"
    local iwd_conf="$nm_conf_dir/iwd.conf"
    
    mkdir -p "$nm_conf_dir"
    
    cat > "$iwd_conf" << EOF
# Configuração para usar IWD como backend do NetworkManager
[device]
wifi.backend=iwd

[connection]
wifi.backend=iwd
EOF
    
    # Habilitar e iniciar iwd
    echo "Habilitando serviço iwd..."
    systemctl enable iwd
    systemctl start iwd
    
    # Reiniciar NetworkManager
    echo "Reiniciando NetworkManager..."
    systemctl restart NetworkManager
    
    # Criar arquivo de estado
    mkdir -p "$HOME/.local"
    echo "iwd_installed_on_$(date +%Y%m%d_%H%M%S)" > "$HOME/.local/.iwd.state"
    
    echo ""
    echo "✓ IWD instalado e configurado com sucesso!"
    echo ""
    echo "Benefícios do IWD:"
    echo "  • Mais rápido que wpa_supplicant"
    echo "  • Menor consumo de CPU e memória"
    echo "  • Suporte nativo a WPA3"
    echo "  • Melhor suporte a redes enterprise"
    echo ""
    echo "⚠ REINICIALIZAÇÃO OU RECONEXÃO DE REDE NECESSÁRIA"
    echo "Reconecte-se às suas redes WiFi para usar o novo backend."
}

uninstall_iwd() {
    echo "Desinstalando IWD..."
    
    # Restaurar wpa_supplicant
    echo "Restaurando wpa_supplicant..."
    systemctl enable wpa_supplicant 2>/dev/null || true
    systemctl start wpa_supplicant 2>/dev/null || true
    
    # Remover configuração do IWD do NetworkManager
    local iwd_conf="/etc/NetworkManager/conf.d/iwd.conf"
    if [ -f "$iwd_conf" ]; then
        rm -f "$iwd_conf"
        echo "✓ Configuração do IWD removida"
    fi
    
    # Parar e desabilitar iwd
    systemctl stop iwd 2>/dev/null || true
    systemctl disable iwd 2>/dev/null || true
    
    # Reiniciar NetworkManager
    systemctl restart NetworkManager
    
    # Remover pacote
    pacman -Rns --noconfirm iwd 2>/dev/null || true
    
    # Remover arquivo de estado
    rm -f "$HOME/.local/.iwd.state"
    
    echo "✓ IWD desinstalado com sucesso!"
}

configure_iwd() {
    clear
    echo "=== IWD (iNet Wireless Daemon) ==="
    echo "Substituto mais moderno e eficiente para wpa_supplicant"
    echo "Oferece melhor desempenho e suporte a padrões WiFi mais recentes."
    echo ""
    
    check_iwd_status
    
    if [ -f "$HOME/.local/.iwd.state" ] || command -v iwd &> /dev/null; then
        echo "IWD já está instalado/configurado."
        read -p "Deseja: [1] Ver status detalhado, [2] Reconfigurar, [3] Desinstalar, [4] Voltar: " choice
        case $choice in
            1)
                echo ""
                echo "Status detalhado do IWD:"
                if command -v iwd &> /dev/null; then
                    echo "Versão: $(iwd --version 2>/dev/null || echo "Desconhecida")"
                fi
                echo ""
                echo "Redes WiFi disponíveis:"
                iwctl station wlan0 scan 2>/dev/null && sleep 2
                iwctl station wlan0 get-networks 2>/dev/null | head -10 || echo "  Não foi possível scanear redes"
                ;;
            2)
                echo "Reconfigurando IWD..."
                uninstall_iwd
                install_iwd
                ;;
            3)
                uninstall_iwd
                ;;
            4)
                return
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    else
        local has_wifi=0
        for iface in /sys/class/net/*; do
            if [ -d "$iface/wireless" ]; then
                has_wifi=1
                break
            fi
        done
        
        if [ $has_wifi -eq 0 ]; then
            echo "⚠ AVISO: Nenhum adaptador WiFi detectado."
            echo "IWD não é necessário neste sistema."
            read -p "Pressione Enter para continuar..."
            return
        fi
        
        echo "IWD não está instalado."
        echo ""
        echo "Comparação com wpa_supplicant:"
        echo "  ✓ Mais rápido e eficiente"
        echo "  ✓ Suporte nativo a WPA3"
        echo "  ✓ Menor consumo de recursos"
        echo "  ✓ Melhor para laptops (bateria)"
        echo ""
        echo "AVISO: Isto substituirá o wpa_supplicant."
        echo "Todas as redes WiFi precisarão ser reconectadas."
        echo ""
        
        read -p "Deseja instalar o IWD? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_iwd
        else
            echo "Instalação cancelada."
        fi
    fi
    
    read -p "Pressione Enter para continuar..."
}

# ============================
# FUNÇÃO DE CONFIGURAÇÃO COMPLETA (ATUALIZADA)
# ============================

configure_all() {
    echo "=== CONFIGURAÇÃO COMPLETA DO SISTEMA ==="
    echo "Aplicando todas as otimizações..."
    echo ""
    
    # 1. CPU Governor
    echo "1. Configurando CPU Governor..."
    if [ ! -f /etc/systemd/system/set-ondemand-governor.service ]; then
        enable_ondemand
        echo "✓ Governor configurado"
    else
        echo "✓ Governor já configurado"
    fi
    
    # 2. Swapfile
    echo ""
    echo "2. Configurando Swapfile..."
    if ! check_swap_exists; then
        create_root_swap 8
        echo "✓ Swapfile configurado"
    else
        echo "✓ Swap já configurado"
    fi
    
    # 3. Shader Booster
    echo ""
    echo "3. Aplicando Otimizações de Shader..."
    if [ ! -f "${HOME}/.booster" ]; then
        DEST_FILE=$(determine_shell_file)
        PATCH_APPLIED=0
        
        HAS_NVIDIA=$(lspci | grep -i 'nvidia')
        HAS_MESA=$(lspci | grep -Ei '(vga|3d)' | grep -vi nvidia)
        
        if [ -n "$HAS_NVIDIA" ]; then
            if download_patch "nvidia"; then
                echo "" >> "$DEST_FILE"
                echo "# shader-booster NVIDIA optimizations" >> "$DEST_FILE"
                cat "$HOME/patch-nvidia" >> "$DEST_FILE"
                rm -f "$HOME/patch-nvidia"
                PATCH_APPLIED=1
            fi
        fi
        
        if [ -n "$HAS_MESA" ]; then
            if download_patch "mesa"; then
                echo "" >> "$DEST_FILE"
                echo "# shader-booster Mesa optimizations" >> "$DEST_FILE"
                cat "$HOME/patch-mesa" >> "$DEST_FILE"
                rm -f "$HOME/patch-mesa"
                PATCH_APPLIED=1
            fi
        fi
        
        if [ $PATCH_APPLIED -eq 1 ]; then
            echo "1" > "${HOME}/.booster"
            echo "✓ Otimizações de shader aplicadas"
        else
            echo "⚠ Nenhuma otimização de shader aplicada"
        fi
    else
        echo "✓ Otimizações de shader já aplicadas"
    fi
    
    # 4. Split-Lock
    echo ""
    echo "4. Desativando Mitigação Split-Lock..."
    if [ ! -f "$HOME/.local/.autopatch.state" ]; then
        local grub_cfg="/etc/default/grub"
        if [ -f "$grub_cfg" ]; then
            if ! grep -q "split_lock_detect=off" "$grub_cfg"; then
                if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$grub_cfg"; then
                    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 split_lock_detect=off"/' "$grub_cfg"
                    grub-mkconfig -o /boot/grub/grub.cfg
                    mkdir -p "$HOME/.local"
                    echo "split_lock_disabled_on_$(date +%Y%m%d_%H%M%S)" > "$HOME/.local/.autopatch.state"
                    echo "✓ Mitigação split-lock desativada"
                fi
            else
                echo "✓ Mitigação split-lock já desativada"
            fi
        fi
    else
        echo "✓ Mitigação split-lock já desativada"
    fi
    
    # 5. MinFree
    echo ""
    echo "5. Configurando MinFree (Memória Livre Mínima)..."
    local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local recommended=$((total_mem_kb / 100))
    
    if [ $recommended -lt 65536 ]; then
        recommended=65536
    elif [ $recommended -gt 524288 ]; then
        recommended=524288
    fi
    
    sysctl -w vm.min_free_kbytes=$recommended
    echo "# MinFree configuration - Dynamic minimum free memory" | tee /etc/sysctl.d/10-minfree.conf
    echo "vm.min_free_kbytes = $recommended" | tee -a /etc/sysctl.d/10-minfree.conf
    echo "vm.vfs_cache_pressure = 50" | tee -a /etc/sysctl.d/10-minfree.conf
    echo "vm.dirty_background_ratio = 5" | tee -a /etc/sysctl.d/10-minfree.conf
    echo "vm.dirty_ratio = 10" | tee -a /etc/sysctl.d/10-minfree.conf
    echo "vm.swappiness = 60" | tee -a /etc/sysctl.d/10-minfree.conf
    sysctl -p /etc/sysctl.d/10-minfree.conf
    echo "✓ MinFree configurado"
    
    # 6. Preload
    echo ""
    echo "6. Configurando Preload..."
    local total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_gb=$(( total_kb / 1024 / 1024 ))
    
    if [ $total_gb -gt 12 ]; then
        if ! command -v preload &> /dev/null; then
            echo "Instalando Preload (sistema tem ${total_gb} GB de RAM)..."
            pacman -S --noconfirm preload
            systemctl enable preload
            systemctl start preload
            echo "✓ Preload instalado e ativado"
        else
            systemctl enable preload 2>/dev/null || true
            systemctl start preload 2>/dev/null || true
            echo "✓ Preload já instalado"
        fi
    else
        echo "⚠ Sistema tem apenas ${total_gb} GB de RAM"
        echo "  Preload não será instalado (recomendado > 12 GB)"
    fi
    
    # 7. EarlyOOM
    echo ""
    echo "7. Configurando EarlyOOM..."
    if ! command -v earlyoom &> /dev/null; then
        pacman -S --noconfirm earlyoom
        systemctl enable earlyoom
        systemctl start earlyoom
        echo "✓ EarlyOOM instalado e ativado"
    else
        systemctl enable earlyoom 2>/dev/null || true
        systemctl start earlyoom 2>/dev/null || true
        echo "✓ EarlyOOM já instalado"
    fi
    
    # 8. UFW
    echo ""
    echo "8. Configurando Firewall UFW..."
    if ! command -v ufw &> /dev/null; then
        pacman -S --noconfirm ufw gufw
    fi
    ufw default deny incoming
    ufw default allow outgoing
    ufw --force enable
    systemctl enable ufw
    systemctl start ufw
    echo "✓ UFW configurado"
    
    # 9. LucidGlyph
    echo ""
    echo "9. Instalando LucidGlyph..."
    if ! detect_lucidglyph; then
        local tag=$(get_latest_lucidglyph_version)
        local ver="${tag#v}"
        
        cd "$HOME" || exit 1
        if wget -O "${tag}.tar.gz" "https://github.com/maximilionus/lucidglyph/archive/refs/tags/${tag}.tar.gz" 2>/dev/null; then
            tar -xvzf "${tag}.tar.gz"
            local extracted_dir=$(ls -d lucidglyph-* 2>/dev/null | head -1)
            if [ -n "$extracted_dir" ]; then
                cd "$extracted_dir"
                chmod +x lucidglyph.sh
                ./lucidglyph.sh install
                cd ..
                rm -rf "$extracted_dir"
                rm -f "${tag}.tar.gz"
                echo "✓ LucidGlyph instalado"
            else
                echo "⚠ Não foi possível instalar o LucidGlyph"
            fi
        else
            echo "⚠ Não foi possível instalar o LucidGlyph"
        fi
    else
        echo "✓ LucidGlyph já instalado"
    fi
    
    # 10. Power Saver
    echo ""
    echo "10. Aplicando Power Saver..."
    if [ ! -f "$HOME/.local/.psaver.state" ]; then
        echo "Aplicando otimizações básicas de energia..."
        
        # Configurar governador powersave
        if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
            for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                if [ -f "$gov" ]; then
                    echo "powersave" > "$gov" 2>/dev/null || true
                fi
            done
        fi
        
        # Instalar TLP se não estiver instalado
        if ! command -v tlp &> /dev/null; then
            pacman -S --noconfirm tlp tlp-rdw 2>/dev/null || true
            systemctl enable tlp 2>/dev/null || true
            systemctl start tlp 2>/dev/null || true
        fi
        
        mkdir -p "$HOME/.local"
        echo "psaver_basic_applied_on_$(date +%Y%m%d_%H%M%S)" > "$HOME/.local/.psaver.state"
        echo "✓ Power Saver básico aplicado"
    else
        echo "✓ Power Saver já configurado"
    fi
    
    # 11. AppArmor
    echo ""
    echo "11. Configurando AppArmor..."
    if ! command -v aa-status &> /dev/null; then
        pacman -S --noconfirm apparmor
        local grub_cfg="/etc/default/grub"
        if [ -f "$grub_cfg" ]; then
            if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$grub_cfg"; then
                current_cmdline=$(grep "GRUB_CMDLINE_LINUX_DEFAULT" "$grub_cfg" | cut -d'"' -f2)
                if [[ ! "$current_cmdline" =~ "apparmor=1" ]]; then
                    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 apparmor=1 security=apparmor"/' "$grub_cfg"
                    grub-mkconfig -o /boot/grub/grub.cfg
                fi
            fi
        fi
        systemctl enable apparmor
        systemctl start apparmor
        echo "✓ AppArmor configurado"
    else
        echo "✓ AppArmor já configurado"
    fi
    
    # 12. HWAccel Flatpak
    echo ""
    echo "12. Configurando HWAccel para Flatpak..."
    if ! command -v flatpak &> /dev/null; then
        pacman -S --noconfirm flatpak
    fi
    install_hwaccel_flatpak
    echo "✓ HWAccel para Flatpak configurado"
    
    # 13. DNSMasq
    echo ""
    echo "13. Configurando DNSMasq..."
    if ! command -v dnsmasq &> /dev/null; then
        pacman -S --noconfirm dnsmasq
        systemctl enable dnsmasq
        systemctl start dnsmasq
        echo "✓ DNSMasq configurado"
    else
        systemctl enable dnsmasq 2>/dev/null || true
        systemctl start dnsmasq 2>/dev/null || true
        echo "✓ DNSMasq já configurado"
    fi
    
    # 14. GRUB-BTRFS (apenas se BTRFS)
    echo ""
    echo "14. Configurando GRUB-BTRFS..."
    local root_fs=$(findmnt -n -o FSTYPE /)
    if [ "$root_fs" = "btrfs" ]; then
        if ! command -v grub-btrfs &> /dev/null; then
            pacman -S --noconfirm grub-btrfs snapper
            systemctl enable grub-btrfsd
            systemctl start grub-btrfsd
            echo "✓ GRUB-BTRFS configurado"
        else
            echo "✓ GRUB-BTRFS já configurado"
        fi
    else
        echo "⚠ Sistema de arquivos não é BTRFS, GRUB-BTRFS não aplicado"
    fi
    
    # 15. Microsoft Core Fonts
    echo ""
    echo "15. Instalando Microsoft Core Fonts..."
    local fonts_dir="$HOME/.local/share/fonts/mscorefonts"
    if [ ! -d "$fonts_dir" ]; then
        install_mscorefonts
        echo "✓ Microsoft Core Fonts instaladas"
    else
        echo "✓ Microsoft Core Fonts já instaladas"
    fi
    
    # 16. Thumbnailer
    echo ""
    echo "16. Configurando Thumbnailer..."
    if ! command -v ffmpegthumbnailer &> /dev/null; then
        pacman -S --noconfirm ffmpegthumbnailer
        echo "✓ Thumbnailer configurado"
    else
        echo "✓ Thumbnailer já configurado"
    fi
    
    # 17. BTRFS Assistant (apenas se BTRFS)
    echo ""
    echo "17. Configurando BTRFS Assistant..."
    if [ "$root_fs" = "btrfs" ]; then
        if ! command -v btrfs-assistant &> /dev/null; then
            pacman -S --noconfirm btrfs-assistant
            echo "✓ BTRFS Assistant configurado"
        else
            echo "✓ BTRFS Assistant já configurado"
        fi
    else
        echo "⚠ Sistema de arquivos não é BTRFS, BTRFS Assistant não aplicado"
    fi
    
    # 18. IWD (apenas se tiver WiFi)
    echo ""
    echo "18. Configurando IWD..."
    local has_wifi=0
    for iface in /sys/class/net/*; do
        if [ -d "$iface/wireless" ]; then
            has_wifi=1
            break
        fi
    done
    
    if [ $has_wifi -eq 1 ]; then
        if ! command -v iwd &> /dev/null; then
            pacman -S --noconfirm iwd
            systemctl enable iwd
            systemctl start iwd
            echo "✓ IWD configurado"
        else
            echo "✓ IWD já configurado"
        fi
    else
        echo "⚠ Nenhum adaptador WiFi detectado, IWD não aplicado"
    fi
    
    echo ""
    echo "========================================="
    echo "✓ CONFIGURAÇÃO COMPLETA FINALIZADA!"
    echo "========================================="
    echo ""
    echo "⚠ ATENÇÃO: ALGUMAS OTIMIZAÇÕES REQUEREM REINICIALIZAÇÃO"
    echo "Reinicie o sistema para aplicar todas as mudanças:"
    echo "  sudo reboot"
    echo ""
    echo "Otimizações aplicadas:"
    echo "  1. CPU Governor (ondemand)"
    echo "  2. Swapfile (8GB)"
    echo "  3. Shader Booster"
    echo "  4. Mitigação Split-Lock desativada"
    echo "  5. MinFree (memória livre mínima)"
    echo "  6. Preload (pré-carregamento)"
    echo "  7. EarlyOOM (prevenção OOM)"
    echo "  8. Firewall UFW"
    echo "  9. LucidGlyph (melhoria de fontes)"
    echo "  10. Power Saver (otimizações de energia)"
    echo "  11. AppArmor (segurança)"
    echo "  12. HWAccel para Flatpak"
    echo "  13. DNSMasq (cache DNS)"
    echo "  14. GRUB-BTRFS (snapshots)"
    echo "  15. Microsoft Core Fonts"
    echo "  16. Thumbnailer (miniaturas de vídeo)"
    echo "  17. BTRFS Assistant (gerenciador BTRFS)"
    echo "  18. IWD (WiFi moderno)"
    
    read -p "Pressione Enter para continuar..."
}

# ============================
# VERIFICAÇÃO DE STATUS COMPLETA (ATUALIZADA)
# ============================

check_all_status() {
    clear
    echo "=== STATUS DO SISTEMA ==="
    echo ""
    
    echo "--- OTIMIZAÇÕES DE DESEMPENHO ---"
    check_governor_status
    check_swap_status
    
    echo "Shader Booster:"
    if [ -f "${HOME}/.booster" ]; then
        echo "  Status: APLICADO"
    else
        echo "  Status: NÃO APLICADO"
    fi
    
    echo ""
    echo "Split-Lock Mitigation:"
    if [ -f "$HOME/.local/.autopatch.state" ]; then
        echo "  Status: DESATIVADA"
    else
        echo "  Status: ATIVADA (padrão)"
    fi
    
    echo ""
    echo "MinFree (Memória Livre Mínima):"
    sysctl vm.min_free_kbytes 2>/dev/null || echo "  Não disponível"
    
    echo ""
    echo "Preload:"
    if command -v preload &> /dev/null || systemctl is-active preload 2>/dev/null; then
        echo "  Status: INSTALADO"
        if systemctl is-active preload &> /dev/null; then
            echo "  Serviço: ATIVO"
        else
            echo "  Serviço: INATIVO"
        fi
    else
        echo "  Status: NÃO INSTALADO"
    fi
    
    echo ""
    echo "EarlyOOM:"
    if command -v earlyoom &> /dev/null || systemctl is-active earlyoom 2>/dev/null; then
        echo "  Status: INSTALADO"
        if systemctl is-active earlyoom &> /dev/null; then
            echo "  Serviço: ATIVO"
        else
            echo "  Serviço: INATIVO"
        fi
    else
        echo "  Status: NÃO INSTALADO"
    fi
    
    echo ""
    echo "--- OTIMIZAÇÕES DE QUALIDADE DE VIDA ---"
    check_ufw_status
    
    echo "LucidGlyph:"
    if detect_lucidglyph; then
        echo "  Status: INSTALADO"
    else
        echo "  Status: NÃO INSTALADO"
    fi
    
    echo ""
    echo "Power Saver (psaver):"
    if [ -f "$HOME/.local/.psaver.state" ]; then
        echo "  Status: APLICADO"
    else
        echo "  Status: NÃO APLICADO"
    fi
    
    echo ""
    echo "AppArmor:"
    if [ -f "$HOME/.local/.apparmor.state" ] || command -v aa-status &> /dev/null; then
        echo "  Status: INSTALADO"
        if systemctl is-active apparmor &> /dev/null; then
            echo "  Serviço: ATIVO"
        else
            echo "  Serviço: INATIVO"
        fi
    else
        echo "  Status: NÃO INSTALADO"
    fi
    
    echo ""
    echo "HWAccel Flatpak:"
    if [ -f "$HOME/.config/hwaccel-flatpak.state" ]; then
        echo "  Status: CONFIGURADO"
    else
        echo "  Status: NÃO CONFIGURADO"
    fi
    
    echo ""
    echo "DNSMasq:"
    if command -v dnsmasq &> /dev/null || systemctl is-active dnsmasq 2>/dev/null; then
        echo "  Status: INSTALADO"
        if systemctl is-active dnsmasq &> /dev/null; then
            echo "  Serviço: ATIVO"
        else
            echo "  Serviço: INATIVO"
        fi
    else
        echo "  Status: NÃO INSTALADO"
    fi
    
    echo ""
    echo "GRUB-BTRFS:"
    local root_fs=$(findmnt -n -o FSTYPE /)
    if [ "$root_fs" = "btrfs" ]; then
        if command -v grub-btrfs &> /dev/null || pacman -Qi grub-btrfs &> /dev/null; then
            echo "  Status: INSTALADO"
            if systemctl is-active grub-btrfsd &> /dev/null; then
                echo "  Serviço: ATIVO"
            else
                echo "  Serviço: INATIVO"
            fi
        else
            echo "  Status: NÃO INSTALADO"
        fi
    else
        echo "  Status: NÃO APLICÁVEL (sistema não é BTRFS)"
    fi
    
    echo ""
    echo "Microsoft Core Fonts:"
    local fonts_dir="$HOME/.local/share/fonts/mscorefonts"
    if [ -d "$fonts_dir" ] || [ -f "$HOME/.local/.mscorefonts.state" ]; then
        echo "  Status: INSTALADO"
    else
        echo "  Status: NÃO INSTALADO"
    fi
    
    echo ""
    echo "Thumbnailer:"
    if command -v ffmpegthumbnailer &> /dev/null || [ -f "$HOME/.local/.thumbnailer.state" ]; then
        echo "  Status: INSTALADO"
    else
        echo "  Status: NÃO INSTALADO"
    fi
    
    echo ""
    echo "BTRFS Assistant:"
    if [ "$root_fs" = "btrfs" ]; then
        if command -v btrfs-assistant &> /dev/null || pacman -Qi btrfs-assistant &> /dev/null; then
            echo "  Status: INSTALADO"
        else
            echo "  Status: NÃO INSTALADO"
        fi
    else
        echo "  Status: NÃO APLICÁVEL (sistema não é BTRFS)"
    fi
    
    echo ""
    echo "IWD:"
    local has_wifi=0
    for iface in /sys/class/net/*; do
        if [ -d "$iface/wireless" ]; then
            has_wifi=1
            break
        fi
    done
    
    if [ $has_wifi -eq 1 ]; then
        if command -v iwd &> /dev/null || systemctl is-active iwd 2>/dev/null; then
            echo "  Status: INSTALADO"
            if systemctl is-active iwd &> /dev/null; then
                echo "  Serviço: ATIVO"
            else
                echo "  Serviço: INATIVO"
            fi
        else
            echo "  Status: NÃO INSTALADO"
        fi
    else
        echo "  Status: NÃO APLICÁVEL (sem WiFi)"
    fi
    
    echo ""
    echo "========================================="
    read -p "Pressione Enter para continuar..."
}

# ============================
# MENU PRINCIPAL
# ============================

main_menu() {
    while true; do
        show_main_menu
        
        case $option in
            1)  # Otimizações de Desempenho
                while true; do
                    show_performance_menu
                    
                    case $perf_option in
                        1)
                            clear
                            echo "=== CONFIGURAR CPU GOVERNOR ==="
                            echo ""
                            check_governor_status
                            
                            if [ -f /etc/systemd/system/set-ondemand-governor.service ]; then
                                read -p "O governor ondemand está ativado. Deseja desativar? (s/N): " -n 1 -r
                                echo
                                if [[ $REPLY =~ ^[Ss]$ ]]; then
                                    disable_ondemand
                                else
                                    echo "Operação cancelada."
                                fi
                            else
                                read -p "Deseja habilitar o governor ondemand? (s/N): " -n 1 -r
                                echo
                                if [[ $REPLY =~ ^[Ss]$ ]]; then
                                    enable_ondemand
                                else
                                    echo "Operação cancelada."
                                fi
                            fi
                            read -p "Pressione Enter para continuar..."
                            ;;
                        2)
                            configure_swap
                            ;;
                        3)
                            configure_shader_booster
                            ;;
                        4)
                            configure_splitlock
                            ;;
                        5)
                            configure_minfree
                            ;;
                        6)
                            configure_preload
                            ;;
                        7)
                            configure_earlyoom
                            ;;
                        8)
                            break
                            ;;
                        *)
                            echo "Opção inválida!"
                            read -p "Pressione Enter para continuar..."
                            ;;
                    esac
                done
                ;;
            
            2)  # Otimizações de Qualidade de Vida
                while true; do
                    show_quality_menu
                    
                    case $quality_option in
                        1)
                            configure_ufw
                            ;;
                        2)
                            install_lucidglyph
                            ;;
                        3)
                            configure_psaver
                            ;;
                        4)
                            configure_apparmor
                            ;;
                        5)
                            configure_hwaccel_flatpak
                            ;;
                        6)
                            configure_dnsmasq
                            ;;
                        7)
                            configure_grub_btrfs
                            ;;
                        8)
                            configure_mscorefonts
                            ;;
                        9)
                            configure_thumbnailer
                            ;;
                        10)
                            configure_btrfs_assistant
                            ;;
                        11)
                            configure_iwd
                            ;;
                        12)
                            break
                            ;;
                        *)
                            echo "Opção inválida!"
                            read -p "Pressione Enter para continuar..."
                            ;;
                    esac
                done
                ;;
            
            3)
                clear
                read -p "Esta opção configurará TODAS as otimizações. Continuar? (s/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Ss]$ ]]; then
                    configure_all
                else
                    echo "Operação cancelada."
                fi
                read -p "Pressione Enter para continuar..."
                ;;
            
            4)
                check_all_status
                ;;
            
            5)
                echo "Saindo..."
                exit 0
                ;;
            
            *)
                echo "Opção inválida! Escolha uma opção de 1 a 5."
                read -p "Pressione Enter para continuar..."
                ;;
        esac
    done
}

# ============================
# INICIALIZAÇÃO
# ============================

init() {
    check_arch
    skip_sudo_check
    clear
    main_menu
}

# Executar
init

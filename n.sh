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
    echo "6) Voltar ao Menu Principal"
    echo "========================================="
    read -p "Escolha uma opção [1-6]: " perf_option
}

show_quality_menu() {
    clear
    echo "========================================="
    echo "    OTIMIZAÇÕES DE QUALIDADE DE VIDA     "
    echo "========================================="
    echo "1) Configurar Firewall UFW"
    echo "2) Instalar LucidGlyph (Melhoria de Fontes)"
    echo "3) Aplicar Fix GTK para Intel/NVIDIA (gtk_bmg_fix) (AI)"
    echo "4) Voltar ao Menu Principal"
    echo "========================================="
    read -p "Escolha uma opção [1-4]: " quality_option
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

# 3. GTK FIX PARA INTEL/NVIDIA - AI
detect_gpu_for_gtk_fix() {
    HAS_INTEL_GPU=$(lspci | grep -i 'intel' | grep -i 'vga\|graphics' | head -1)
    HAS_NVIDIA_GPU=$(lspci | grep -i 'nvidia' | head -1)
    
    if [ -n "$HAS_INTEL_GPU" ]; then
        echo "✓ GPU Intel detectada:"
        echo "  $HAS_INTEL_GPU"
        echo "intel"
        return 0
    elif [ -n "$HAS_NVIDIA_GPU" ]; then
        echo "✓ GPU NVIDIA detectada:"
        echo "  $HAS_NVIDIA_GPU"
        echo "nvidia"
        return 0
    else
        echo "⚠ Nenhuma GPU Intel ou NVIDIA detectada"
        echo "none"
        return 1
    fi
}

check_gtk_fix_status() {
    echo "=== Status do GTK Fix ==="
    
    echo "Variáveis de ambiente GTK:"
    env | grep -i gtk | sort
    
    echo ""
    echo "Configurações GTK em /etc/environment:"
    if [ -f "/etc/environment" ]; then
        grep -i "gtk\|gl" /etc/environment || echo "  Nenhuma configuração encontrada"
    else
        echo "  /etc/environment não encontrado"
    fi
    
    echo ""
    if [ -d "/etc/gtk-3.0" ]; then
        echo "  /etc/gtk-3.0/ existe"
    fi
    
    if [ -d "/etc/gtk-4.0" ]; then
        echo "  /etc/gtk-4.0/ existe"
    fi
    
    if [ -f "/etc/environment" ] && grep -q "GTK_IM_MODULE\|GDK_BACKEND" /etc/environment 2>/dev/null; then
        echo ""
        echo "✓ Configurações GTK detectadas no sistema"
    else
        echo ""
        echo "⚠ Nenhuma configuração GTK especial encontrada"
    fi
    echo
}

apply_intel_gtk_fix() {
    echo "Aplicando correções GTK para Intel..."
    
    if [ -f "/etc/environment" ]; then
        cp /etc/environment /etc/environment.backup.$(date +%Y%m%d%H%M%S)
    fi
    
    echo "" | tee -a /etc/environment
    echo "# GTK Fix for Intel Graphics" | tee -a /etc/environment
    echo "export GDK_BACKEND=x11" | tee -a /etc/environment
    echo "export GTK_IM_MODULE=ibus" | tee -a /etc/environment
    echo "export CLUTTER_BACKEND=x11" | tee -a /etc/environment
    echo "export LIBGL_ALWAYS_SOFTWARE=0" | tee -a /etc/environment
    echo "export MESA_LOADER_DRIVER_OVERRIDE=i965" | tee -a /etc/environment
    echo "export INTEL_DEBUG=norbc" | tee -a /etc/environment
    
    echo "✓ Correções Intel aplicadas em /etc/environment"
}

apply_nvidia_gtk_fix() {
    echo "Aplicando correções GTK para NVIDIA..."
    
    if [ -f "/etc/environment" ]; then
        cp /etc/environment /etc/environment.backup.$(date +%Y%m%d%H%M%S)
    fi
    
    echo "" | tee -a /etc/environment
    echo "# GTK Fix for NVIDIA Graphics" | tee -a /etc/environment
    echo "export GDK_BACKEND=x11" | tee -a /etc/environment
    echo "export GTK_IM_MODULE=ibus" | tee -a /etc/environment
    echo "export CLUTTER_BACKEND=x11" | tee -a /etc/environment
    echo "export __GLX_VENDOR_LIBRARY_NAME=nvidia" | tee -a /etc/environment
    echo "export LIBGL_ALWAYS_SOFTWARE=0" | tee -a /etc/environment
    echo "export __GL_THREADED_OPTIMIZATIONS=1" | tee -a /etc/environment
    echo "export __GL_SYNC_TO_VBLANK=0" | tee -a /etc/environment
    
    echo "✓ Correções NVIDIA aplicadas em /etc/environment"
}

configure_gtk_fix() {
    clear
    echo "=== CORREÇÃO GTK PARA INTEL/NVIDIA (AI) ==="
    echo "Resolve problemas de renderização em aplicações GTK"
    echo ""
    
    local gpu_type=$(detect_gpu_for_gtk_fix)
    
    check_gtk_fix_status
    
    local has_gtk_config=0
    if [ -f "/etc/environment" ] && grep -q "GDK_BACKEND\|GTK_IM_MODULE" /etc/environment 2>/dev/null; then
        has_gtk_config=1
        echo "Configurações GTK já existem no sistema."
        read -p "Deseja: [1] Manter, [2] Substituir, [3] Voltar: " choice
        echo
        
        case $choice in
            1)
                echo "Configurações mantidas."
                return
                ;;
            2)
                # Limpar configurações antigas
                if [ -f "/etc/environment" ]; then
                    cp /etc/environment /etc/environment.backup.before_gtkfix.$(date +%Y%m%d%H%M%S)
                    grep -v "GDK_BACKEND\|GTK_IM_MODULE\|CLUTTER_BACKEND\|LIBGL_ALWAYS_SOFTWARE\|MESA_LOADER\|INTEL_DEBUG\|__GL" /etc/environment > /tmp/environment.tmp
                    mv /tmp/environment.tmp /etc/environment
                fi
                # Continuar para aplicar novas
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
    
    if [ "$gpu_type" = "none" ]; then
        echo "Nenhuma GPU Intel ou NVIDIA detectada."
        read -p "Aplicar configurações GTK genéricas? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            echo "Aplicando configurações GTK genéricas..."
            if [ -f "/etc/environment" ]; then
                cp /etc/environment /etc/environment.backup.$(date +%Y%m%d%H%M%S)
            fi
            echo "" | tee -a /etc/environment
            echo "# GTK Generic Fix" | tee -a /etc/environment
            echo "export GDK_BACKEND=x11" | tee -a /etc/environment
            echo "export GTK_IM_MODULE=ibus" | tee -a /etc/environment
            echo "✓ Configurações genéricas aplicadas"
        else
            echo "Operação cancelada."
        fi
        return
    fi
    
    echo ""
    echo "O GTK Fix resolve problemas com:"
    echo "  - Renderização lenta em aplicações GTK"
    echo "  - Problemas com wayland/x11"
    echo "  - Falhas gráficas em Intel/NVIDIA"
    echo ""
    
    read -p "Deseja aplicar o GTK Fix? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Operação cancelada."
        return
    fi
    
    if [ "$gpu_type" = "intel" ]; then
        apply_intel_gtk_fix
    elif [ "$gpu_type" = "nvidia" ]; then
        apply_nvidia_gtk_fix
    fi
    
    echo ""
    echo "✓ GTK Fix aplicado com sucesso!"
    echo ""
    echo "⚠ REINICIALIZAÇÃO OU NOVO LOGIN NECESSÁRIO"
    echo "Para que as mudanças tenham efeito, faça logout e login novamente"
    echo "ou reinicie o sistema."
    echo ""
    echo "As variáveis de ambiente foram configuradas em /etc/environment"
    
    read -p "Pressione Enter para continuar..."
}

# ============================
# FUNÇÃO DE CONFIGURAÇÃO COMPLETA
# ============================

configure_all() {
    echo "=== CONFIGURAÇÃO COMPLETA DO SISTEMA ==="
    echo "Aplicando todas as 8 otimizações..."
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
    
    # 6. UFW
    echo ""
    echo "6. Configurando Firewall UFW..."
    if ! command -v ufw &> /dev/null; then
        pacman -S --noconfirm ufw gufw
    fi
    ufw default deny incoming
    ufw default allow outgoing
    ufw --force enable
    systemctl enable ufw
    systemctl start ufw
    echo "✓ UFW configurado"
    
    # 7. LucidGlyph
    echo ""
    echo "7. Instalando LucidGlyph..."
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
    
    # 8. GTK Fix
    echo ""
    echo "8. Aplicando GTK Fix para Intel/NVIDIA..."
    HAS_INTEL_GPU=$(lspci | grep -i 'intel' | grep -i 'vga\|graphics' | head -1)
    HAS_NVIDIA_GPU=$(lspci | grep -i 'nvidia' | head -1)
    
    if [ -n "$HAS_INTEL_GPU" ] || [ -n "$HAS_NVIDIA_GPU" ]; then
        if [ -f "/etc/environment" ]; then
            cp /etc/environment /etc/environment.backup.$(date +%Y%m%d%H%M%S)
        fi
        
        echo "" | tee -a /etc/environment
        echo "# GTK Fix applied by Super Script" | tee -a /etc/environment
        echo "export GDK_BACKEND=x11" | tee -a /etc/environment
        echo "export GTK_IM_MODULE=ibus" | tee -a /etc/environment
        
        if [ -n "$HAS_INTEL_GPU" ]; then
            echo "# Intel specific optimizations" | tee -a /etc/environment
            echo "export MESA_LOADER_DRIVER_OVERRIDE=i965" | tee -a /etc/environment
        elif [ -n "$HAS_NVIDIA_GPU" ]; then
            echo "# NVIDIA specific optimizations" | tee -a /etc/environment
            echo "export __GLX_VENDOR_LIBRARY_NAME=nvidia" | tee -a /etc/environment
        fi
        
        echo "✓ GTK Fix aplicado"
    else
        echo "⚠ Nenhuma GPU Intel/NVIDIA detectada, GTK Fix não aplicado"
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
    echo "  6. Firewall UFW"
    echo "  7. LucidGlyph (melhoria de fontes)"
    echo "  8. GTK Fix para Intel/NVIDIA"
    
    read -p "Pressione Enter para continuar..."
}

# ============================
# VERIFICAÇÃO DE STATUS COMPLETA
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
    echo "--- OTIMIZAÇÕES DE QUALIDADE DE VIDA ---"
    check_ufw_status
    
    echo "LucidGlyph:"
    if detect_lucidglyph; then
        echo "  Status: INSTALADO"
    else
        echo "  Status: NÃO INSTALADO"
    fi
    
    echo ""
    echo "GTK Fix:"
    if [ -f "/etc/environment" ] && grep -q "GDK_BACKEND\|GTK_IM_MODULE" /etc/environment 2>/dev/null; then
        echo "  Status: APLICADO"
    else
        echo "  Status: NÃO APLICADO"
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
                            configure_gtk_fix
                            ;;
                        4)
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
                read -p "Esta opção configurará TODAS as 8 otimizações. Continuar? (s/N): " -n 1 -r
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
    skip_sudo_check  # Usa a nova função que suporta chroot
    clear
    main_menu
}

# Executar
init

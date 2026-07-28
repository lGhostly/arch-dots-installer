#!/bin/bash

# ==========================================
# Definición de Colores
# ==========================================
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# Función para imprimir títulos
print_step() {
    echo -e "\n${MAGENTA}✦ ${CYAN}$1 ${NC}"
}

# Función para imprimir éxitos
print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

# Función para imprimir advertencias
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# ==========================================
# INICIO DEL SCRIPT
# ==========================================
clear
echo -e "${MAGENTA}==========================================${NC}"
echo -e "${CYAN}   🚀 INICIANDO INSTALADOR DE ENTORNO   ${NC}"
echo -e "${MAGENTA}==========================================${NC}"

# Pedir permisos de superusuario al inicio
sudo -v

# 1. Actualización y Dependencias Base
print_step "Actualizando el sistema e instalando base-devel, git y stow..."
sudo pacman -Syu --needed --noconfirm base-devel git stow
print_success "Sistema base listo."

# 2. Instalación de Yay (AUR Helper)
print_step "Verificando instalación de Yay..."
if ! command -v yay &> /dev/null; then
    echo "Yay no encontrado. Instalando desde el AUR..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    rm -rf /tmp/yay
    print_success "Yay instalado correctamente."
else
    print_success "Yay ya está instalado."
fi

# 3. Instalación de Paquetes Oficiales
print_step "Instalando paquetes de los repositorios oficiales..."
if [ -f "pkglist.txt" ]; then
    sudo pacman -S --needed --noconfirm - < pkglist.txt
    print_success "Paquetes oficiales instalados."
else
    print_warning "No se encontró pkglist.txt, saltando..."
fi

# 4. Instalación de Paquetes del AUR
print_step "Instalando paquetes del AUR..."
if [ -f "aurlist.txt" ]; then
    yay -S --needed --noconfirm - < aurlist.txt
    print_success "Paquetes del AUR instalados."
else
    print_warning "No se encontró aurlist.txt, saltando..."
fi

# 5. Clonar el repositorio "Almacén" (Dotfiles)
print_step "Descargando repositorio de configuraciones (arch-dots)..."
DOTS_DIR="$HOME/arch-dots"

if [ -d "$DOTS_DIR" ]; then
    print_warning "La carpeta arch-dots ya existe. Actualizando..."
    cd "$DOTS_DIR"
    git pull
else
    # Corregido con el usuario exacto de tus logs
    git clone https://github.com/lGhostly/arch-dots.git "$DOTS_DIR"
    print_success "Repositorio clonado con éxito."
fi

# 6. Preparar entorno para Stow
print_step "Preparando el entorno para evitar conflictos..."
mkdir -p "$HOME/.config"

# Stow fallará si estos archivos ya existen por defecto en una instalación limpia.
# Esto los respalda añadiendo ".bak" al final.
for file in ".bashrc" ".bash_profile" ".zshrc"; do
    if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
        mv "$HOME/$file" "$HOME/${file}.bak"
        echo -e "  ${YELLOW}↳ Respaldo creado: ${file} -> ${file}.bak${NC}"
    fi
done

# 7. Aplicar configuraciones con GNU Stow
print_step "Generando enlaces simbólicos con GNU Stow..."
cd "$DOTS_DIR"

# Lista de las carpetas que SI quieres instalar
STOW_FOLDERS=(
    "bash"
    "zsh"
    "kitty"
    "hyprland"
    "Thunar"
    "rofi"
    "cava"
    "easyeffects"    
    "fastfetch"
    "waybar"
    "system"
    "teku-cava"
    "waypaper"
)

# copia cada carpeta de configuración al directorio home usando stow
for folder in "${STOW_FOLDERS[@]}"; do
    if [ -d "$folder" ]; then
        stow -R "$folder"
        echo -e "  ${GREEN}↳ Enlazado: ${NC}$folder"
    else
        echo -e "  ${RED}↳ No encontrado: ${NC}$folder"
    fi
done

echo -e "\n${MAGENTA}==========================================${NC}"
echo -e "${GREEN} 🎉 ¡INSTALACIÓN COMPLETADA CON ÉXITO! 🎉 ${NC}"
echo -e "${MAGENTA}==========================================${NC}"
echo -e "Por favor, reinicia tu sesión para aplicar todos los cambios.\n"
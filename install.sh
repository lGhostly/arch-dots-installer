#!/bin/bash

# ==========================================
# Definición de Colores para hacerlo estético
# ==========================================
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# Funciones de impresión
print_step() { echo -e "\n${MAGENTA}✦ ${CYAN}$1 ${NC}"; }
print_success() { echo -e "${GREEN}✔ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✖ $1${NC}"; }

# ==========================================
# COMPROBACIONES DE SEGURIDAD INICIALES
# ==========================================

# 1. Bloquear ejecución como root (Evita el error de makepkg)
if [ "$EUID" -eq 0 ]; then
  print_error "ERROR FATAL: No ejecutes este script como root o con sudo."
  print_error "Makepkg y Yay fallarán. Ejecútalo como tu usuario normal (ej. Ghostly)."
  exit 1
fi

# 2. Asegurar el directorio de trabajo (Evita el error de "limbo" / No such file)
# Esto forza a la terminal a ubicarse exactamente donde está guardado el script install.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR" || {
  print_error "No se pudo acceder al directorio del script."
  exit 1
}

# ==========================================
# INICIO DEL SCRIPT
# ==========================================
clear
echo -e "${MAGENTA}==========================================${NC}"
echo -e "${CYAN}   🚀 INICIANDO INSTALADOR DE ENTORNO   ${NC}"
echo -e "${MAGENTA}==========================================${NC}"

# Pedir permisos de superusuario al inicio (para pacman más adelante)
sudo -v

# 1. Actualización y Dependencias Base
print_step "Actualizando el sistema e instalando base-devel, git y stow..."
sudo pacman -Syu --needed --noconfirm base-devel git stow
print_success "Sistema base listo."

# 2. Instalación de Yay (AUR Helper)
print_step "Verificando instalación de Yay..."
if ! command -v yay &>/dev/null; then
  print_warning "Yay no encontrado. Instalando desde el AUR..."
  git clone https://aur.archlinux.org/yay.git /tmp/yay || {
    print_error "Fallo al clonar yay"
    exit 1
  }
  cd /tmp/yay
  makepkg -si --noconfirm || {
    print_error "Fallo al compilar yay"
    exit 1
  }
  rm -rf /tmp/yay
  # Volvemos al directorio del script
  cd "$SCRIPT_DIR"
  print_success "Yay instalado correctamente."
else
  print_success "Yay ya está instalado."
fi

# 3. Instalación de Paquetes Oficiales
print_step "Instalando paquetes de los repositorios oficiales..."
if [ -f "pkglist.txt" ]; then
  sudo pacman -S --needed --noconfirm - <pkglist.txt
  print_success "Paquetes oficiales instalados."
else
  print_warning "No se encontró pkglist.txt, saltando..."
fi

# 4. Instalación de Paquetes del AUR
print_step "Instalando paquetes del AUR..."
if [ -f "aurlist.txt" ]; then
  yay -S --needed --noconfirm - <aurlist.txt
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
  git pull || print_error "Hubo un problema actualizando el repositorio."
else
  # Si git clone falla (por falta de internet, github caído, etc), el script se detiene (exit 1)
  git clone https://github.com/lGhostly/arch-dots.git "$DOTS_DIR" || {
    print_error "Fallo al clonar los dotfiles. Abortando."
    exit 1
  }
  print_success "Repositorio clonado con éxito."
fi

# 6. Preparar entorno para Stow
print_step "Preparando el entorno para evitar conflictos..."
mkdir -p "$HOME/.config"

for file in ".bashrc" ".bash_profile" ".zshrc"; do
  if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
    mv "$HOME/$file" "$HOME/${file}.bak"
    echo -e "  ${YELLOW}↳ Respaldo creado: ${file} -> ${file}.bak${NC}"
  fi
done

# 7. Aplicar configuraciones con GNU Stow
print_step "Generando enlaces simbólicos con GNU Stow..."
cd "$DOTS_DIR" || {
  print_error "No se pudo acceder a $DOTS_DIR"
  exit 1
}

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

for folder in "${STOW_FOLDERS[@]}"; do
  if [ -d "$folder" ]; then
    stow -R "$folder"
    echo -e "  ${GREEN}↳ Enlazado: ${NC}$folder"
  else
    echo -e "  ${RED}↳ No encontrado: ${NC}$folder"
  fi
done

# 8. Instalación Opcional de Fondos de Pantalla
print_step "Fondos de Pantalla"
read -p "$(echo -e "  ${CYAN}¿Deseas instalar los fondos de pantalla? (s/n): ${NC}")" install_walls

if [[ "$install_walls" =~ ^[sS]$ ]]; then
  # Ajusta esta ruta de destino si prefieres ~/.config/wallpapers o ~/Imágenes
  WALLPAPER_DEST="$HOME/assets/Images/wallpapers"
  mkdir -p "$WALLPAPER_DEST"

  # IMPORTANTE: Revisa en tu repo arch-dots en qué carpeta están exactamente tus fondos de pantalla.
  # Cámbialo aquí si ya no están en 'assets/Images/wallpapers'
  WALLPAPER_SRC="assets/Images/wallpapers"

  if [ -d "$WALLPAPER_SRC" ]; then
    cp -r "$WALLPAPER_SRC"/* "$WALLPAPER_DEST/"
    echo -e "  ${GREEN}↳ Fondos de pantalla instalados en $WALLPAPER_DEST.${NC}"
  else
    echo -e "  ${RED}↳ No se encontró la ruta '$WALLPAPER_SRC' en el repositorio.${NC}"
    echo -e "  ${YELLOW}↳ Por favor, verifica la ruta de tus imágenes en GitHub.${NC}"
  fi
else
  echo -e "  ${YELLOW}↳ Instalación de fondos omitida.${NC}"
fi

echo -e "\n${MAGENTA}==========================================${NC}"
echo -e "${GREEN}  ¡INSTALACIÓN COMPLETADA CON ÉXITO!  ${NC}"
echo -e "${MAGENTA}==========================================${NC}"
echo -e "Por favor, reinicia tu sesión para aplicar todos los cambios.\n"

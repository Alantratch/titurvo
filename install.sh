#!/usr/bin/env bash
# install.sh - Instalador idempotente para Zorin / Ubuntu-based
# Uso:
#   sudo ./install.sh [onlyoffice|all]
# Se nenhum argumento dado, mostra ajuda.

set -euo pipefail
ARGS="${1:-}"

log() { echo -e "\e[1;32m[install]\e[0m $*"; }
err() { echo -e "\e[1;31m[error]\e[0m $*" >&2; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    err "Execute como root: sudo $0 $ARGS"
    exit 2
  fi
}

update_system() {
  log "Atualizando pacotes (apt)..."
  apt update -y
  apt upgrade -y
}

ensure_snapd() {
  if command -v snap >/dev/null 2>&1; then
    log "snap presente."
    return
  fi
  log "Instalando snapd..."
  apt install -y snapd
  # start snapd if systemd present
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now snapd.socket || true
  fi
  log "snapd instalado."
}

install_onlyoffice_snap() {
  log "Instalando OnlyOffice Desktop Editors via snap..."
  # tenta instalar; se já instalado, faz refresh
  if snap list onlyoffice-desktopeditors >/dev/null 2>&1; then
    log "OnlyOffice já instalado via snap — atualizando."
    snap refresh onlyoffice-desktopeditors || true
  else
    snap install onlyoffice-desktopeditors --classic || {
      err "Falha ao instalar via snap."
      return 1
    }
  fi
  log "OnlyOffice instalado via snap."
  return 0
}

# fallback: attempt apt/.deb method (comentado/pronto para uso manual)
install_onlyoffice_deb_fallback() {
  log "Método fallback (.deb) não automático. Instruções:"
  cat <<'EOF'
1) Baixe o .deb oficial do OnlyOffice (site oficial) e instale:
   sudo dpkg -i onlyoffice-desktopeditors_xxx.deb
   sudo apt -f install -y

2) Ou adicione o repositório oficial (se disponível) e instale via apt.
EOF
}

install_extra_packages() {
  # lê packages.txt e instala cada pacote apt (se existir)
  if [ -f packages.txt ]; then
    log "Instalando pacotes adicionais listados em packages.txt..."
    xargs -a packages.txt -r sudo apt install -y || true
  else
    log "Nenhum packages.txt encontrado — pulando pacotes extras."
  fi
}

main() {
  require_root

  case "${ARGS}" in
    ""|help|-h|--help)
      cat <<EOF
Uso: sudo $0 [onlyoffice|all]
 - onlyoffice : atualiza sistema + instala onlyoffice
 - all        : atualiza sistema + onlyoffice + pacotes de packages.txt
EOF
      exit 0
      ;;
    onlyoffice)
      update_system
      ensure_snapd
      install_onlyoffice_snap || install_onlyoffice_deb_fallback
      ;;
    all)
      update_system
      ensure_snapd
      install_onlyoffice_snap || install_onlyoffice_deb_fallback
      install_extra_packages
      ;;
    *)
      err "Argumento inválido: $ARGS"
      exit 3
      ;;
  esac

  log "Operação finalizada."
}

main

#!/usr/bin/env zsh

echo "Switching to MAX PERFORMANCE mode..."

if systemctl list-unit-files docker.service >/dev/null 2>&1; then
  sudo systemctl start docker.service docker.socket
fi

if command -v scxctl >/dev/null 2>&1 && systemctl is-active --quiet scx_loader.service; then
  echo "Switching scx_lavd to Gaming (performance) mode..."
  sudo scxctl switch --sched scx_lavd --mode gaming
fi

echo "Enabling UI animations and extensions..."
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface enable-animations true
fi
if command -v gnome-extensions >/dev/null 2>&1; then
  gnome-extensions list | while read -r ext; do
    gnome-extensions enable "$ext"
  done
fi

echo "Max Performance activated."

#!/usr/bin/env bash
# Double-click this file in Finder to install transcrtribe.
cd "$(dirname "$0")"
chmod +x install_macos.sh
./install_macos.sh
echo ""
read -n 1 -s -r -p "Press any key to close this window..."

#!/bin/bash
#===============================================================================
#
#     ██████╗ █████╗ ████████╗███████╗    ████████╗██╗    ██╗███████╗ █████╗ ██╗  ██╗███████╗██████╗ 
#    ██╔════╝██╔══██╗╚══██╔══╝██╔════╝    ╚══██╔══╝██║    ██║██╔════╝██╔══██╗██║ ██╔╝██╔════╝██╔══██╗
#    ██║     ███████║   ██║   ███████╗       ██║   ██║ █╗ ██║█████╗  ███████║█████╔╝ █████╗  ██████╔╝
#    ██║     ██╔══██║   ██║   ╚════██║       ██║   ██║███╗██║██╔══╝  ██╔══██║██╔═██╗ ██╔══╝  ██╔══██╗
#    ╚██████╗██║  ██║   ██║   ███████║       ██║   ╚███╔███╔╝███████╗██║  ██║██║  ██╗███████╗██║  ██║
#     ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝       ╚═╝    ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
#
#                                  「  v1.8.2 - WSL2 Ubuntu Edition  」
#                                       by Flames / Team Flames 🐱
#
#   USAGE: curl -fsSL <url> | bash    OR    bash cats-tweaker-wsl2.sh [-v]
#   FLAGS: -v = verbose mode (show progress)
#
#===============================================================================

# Don't use set -e, we handle errors manually
set +e

# ─────────────────────────────────────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────────────────────────────────────
INSTALL_DIR="$HOME/retro-dev"
TOOLS="$INSTALL_DIR/tools"
SDKS="$INSTALL_DIR/sdks"
EMUS="$INSTALL_DIR/emulators"
COMPILERS="$INSTALL_DIR/compilers"
LOG="$INSTALL_DIR/install.log"

VERBOSE=false
[[ "${1:-}" == "-v" ]] && VERBOSE=true

NCPU=$(nproc 2>/dev/null || echo 4)

# ─────────────────────────────────────────────────────────────────────────────
# UTILS
# ─────────────────────────────────────────────────────────────────────────────
G=$'\033[0;32m'; Y=$'\033[0;33m'; C=$'\033[0;36m'; M=$'\033[0;35m'; W=$'\033[1;37m'; RST=$'\033[0m'

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
say() { $VERBOSE && printf "  ${C}▸${RST} %s\n" "$1"; log "$1"; }
ok()  { printf "  ${G}[✓]${RST} %s\n" "$1"; log "[OK] $1"; }
err() { printf "  ${Y}[✗]${RST} %s\n" "$1"; log "[FAIL] $1"; }

# ─────────────────────────────────────────────────────────────────────────────
# ASCII ART COLLECTION
# ─────────────────────────────────────────────────────────────────────────────
declare -a ARTS
ARTS[0]='
      ><(((°>
    ><(((°>    ~blub~
  ><(((°>  ><(((°>
    ~FISHIES~
'

ARTS[1]='
    ___________
   /    TUNA   \
  |  ><(((°>    |
  |    YUM!    |
   \___________/
'

ARTS[2]='
     _________
    /  TACO!  \
   | PvZ 🌮   |
   | ~craaazy~|
    \_dave!__/
'

ARTS[3]='
    /\_____/\
   /  o   o  \
  ( ==  ^  == )
   )  ≧◡≦   (
  (  nyah~!  )
'

ART_IDX=0

# Simple progress display
show_progress() {
    local current="$1" total="$2" pkg_name="$3"
    local pct=$((current * 100 / total))
    local bar_filled=$((current * 30 / total))
    local bar_empty=$((30 - bar_filled))
    
    # Cycle art
    ART_IDX=$(( (ART_IDX + 1) % 4 ))
    
    # Build progress bar string
    local bar=""
    local i
    for ((i=0; i<bar_filled; i++)); do bar+="█"; done
    for ((i=0; i<bar_empty; i++)); do bar+="░"; done
    
    # Clear and redraw (8 lines up)
    printf "\r\033[8A\033[J"
    printf "${M}%s${RST}\n" "${ARTS[$ART_IDX]}"
    printf "  ${C}🐱 ...nyah! please wait...${RST}\n"
    printf "  ${W}Installing:${RST} ${Y}%-25s${RST}\n" "$pkg_name"
    printf "  ${C}[${G}%s${W}%s${C}]${RST} %3d%% (%d/%d)\n" "$bar" "" "$pct" "$current" "$total"
}

# Install APT packages with progress
install_apt_progress() {
    local pkgs=("$@")
    local total=${#pkgs[@]}
    local current=0
    local fail_count=0
    
    # Initial spacing
    printf "\n\n\n\n\n\n\n\n"
    
    for pkg in "${pkgs[@]}"; do
        current=$((current + 1))
        show_progress "$current" "$total" "$pkg"
        
        if ! sudo apt-get install -y -qq "$pkg" >> "$LOG" 2>&1; then
            log "[FAIL] apt: $pkg"
            fail_count=$((fail_count + 1))
        fi
    done
    
    # Clear progress
    printf "\r\033[8A\033[J"
    
    return $fail_count
}

# Install pip packages with progress
install_pip_progress() {
    local pkgs=("$@")
    local total=${#pkgs[@]}
    local current=0
    local fail_count=0
    
    # Initial spacing
    printf "\n\n\n\n\n\n\n\n"
    
    for pkg in "${pkgs[@]}"; do
        current=$((current + 1))
        show_progress "$current" "$total" "$pkg"
        
        if ! pip3 install --user --break-system-packages "$pkg" >> "$LOG" 2>&1; then
            if ! pip3 install --user "$pkg" >> "$LOG" 2>&1; then
                if ! pip3 install "$pkg" >> "$LOG" 2>&1; then
                    log "[FAIL] pip: $pkg"
                    fail_count=$((fail_count + 1))
                fi
            fi
        fi
    done
    
    # Clear progress
    printf "\r\033[8A\033[J"
    
    return $fail_count
}

dl() {
    local url="$1" out="$2"
    log "[DL] $url -> $out"
    if curl -fsSL --connect-timeout 30 --max-time 600 --retry 3 -L -o "$out" "$url" 2>>"$LOG"; then
        [[ -s "$out" ]] && { log "[DL] OK $(stat -c%s "$out" 2>/dev/null || echo '?') bytes"; return 0; }
    fi
    rm -f "$out" 2>/dev/null
    log "[DL] FAILED"
    return 1
}

run() {
    log "[RUN] $*"
    if "$@" >> "$LOG" 2>&1; then
        return 0
    else
        log "[RUN] exit $?"
        return 1
    fi
}

add_path() {
    local rc="$HOME/.bashrc"
    grep -qF "$1" "$rc" 2>/dev/null || echo "$1" >> "$rc"
}

# ─────────────────────────────────────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────────────────────────────────────
mkdir -p "$TOOLS" "$SDKS" "$EMUS" "$COMPILERS"
: > "$LOG"

cat << 'BANNER'

     ██████╗ █████╗ ████████╗███████╗    ████████╗██╗    ██╗███████╗ █████╗ ██╗  ██╗███████╗██████╗ 
    ██╔════╝██╔══██╗╚══██╔══╝██╔════╝    ╚══██╔══╝██║    ██║██╔════╝██╔══██╗██║ ██╔╝██╔════╝██╔══██╗
    ██║     ███████║   ██║   ███████╗       ██║   ██║ █╗ ██║█████╗  ███████║█████╔╝ █████╗  ██████╔╝
    ██║     ██╔══██║   ██║   ╚════██║       ██║   ██║███╗██║██╔══╝  ██╔══██║██╔═██╗ ██╔══╝  ██╔══██╗
    ╚██████╗██║  ██║   ██║   ███████║       ██║   ╚███╔███╔╝███████╗██║  ██║██║  ██╗███████╗██║  ██║
     ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝       ╚═╝    ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝

                                   「  v1.8.1 - WSL2 Ubuntu Edition  」
                                          /\_____/\
                                         /  o   o  \
                                        ( ==  ^  == )
                                         )         (
                                        (           )
                                       ( (  )   (  ) )
                                      (__(__)___(__)__)

BANNER

log "=== CAT'S TWEAKER 1.8.1 WSL2 ==="
log "Date: $(date)"
log "User: $USER"
log "WSL: ${WSL_DISTRO_NAME:-native}"

# ─────────────────────────────────────────────────────────────────────────────
# SYSTEM PACKAGES
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ SYSTEM PACKAGES${RST}\n"
say "Updating APT..."

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update -qq >> "$LOG" 2>&1

APT_PKGS=(
    build-essential gcc g++ clang llvm cmake ninja-build meson
    autoconf automake libtool pkg-config
    libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
    libpng-dev libjpeg-dev libfreetype6-dev zlib1g-dev libglew-dev libglfw3-dev
    python3 python3-pip python3-venv
    nasm yasm flex bison texinfo
    libncurses-dev libreadline-dev libgmp-dev libmpfr-dev libmpc-dev
    curl wget unzip p7zip-full xz-utils
    libusb-1.0-0-dev libelf-dev
    cc65 sdcc
)

install_apt_progress "${APT_PKGS[@]}" && ok "APT packages (${#APT_PKGS[@]} items)" || ok "APT packages (some skipped)"

# ─────────────────────────────────────────────────────────────────────────────
# PYTHON
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ PYTHON PACKAGES${RST}\n"

PY_PKGS=(pygame ursina pillow numpy pysdl2 pyyaml toml intelhex pyserial capstone)
install_pip_progress "${PY_PKGS[@]}" && ok "Python packages" || ok "Python packages (some skipped)"

# ─────────────────────────────────────────────────────────────────────────────
# N64 TOOLCHAIN (mips64-elf-gcc)
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ N64 TOOLCHAIN${RST}\n"
say "Downloading prebuilt mips64-elf-gcc..."

rm -rf "$COMPILERS/n64" 2>/dev/null
mkdir -p "$COMPILERS/n64"
cd "$COMPILERS/n64" || cd /tmp

# Try multiple URLs
TC_URLS=(
    "https://github.com/DragonMinded/libdragon/releases/download/toolchain-continuous-prerelease/gcc-toolchain-mips64-linux-x86_64.tar.gz"
    "https://github.com/DragonMinded/libdragon/releases/latest/download/gcc-toolchain-mips64-linux-x86_64.tar.gz"
)

N64_OK=false
for TC_URL in "${TC_URLS[@]}"; do
    log "Trying N64 toolchain: $TC_URL"
    if curl -fsSL --connect-timeout 30 --max-time 600 --retry 2 -L -o tc.tar.gz "$TC_URL" >> "$LOG" 2>&1; then
        if [[ -s tc.tar.gz ]]; then
            if tar xzf tc.tar.gz >> "$LOG" 2>&1; then
                rm -f tc.tar.gz
                add_path 'export N64_INST="$HOME/retro-dev/compilers/n64"'
                add_path 'export PATH="$N64_INST/bin:$PATH"'
                ok "N64 toolchain (mips64-elf-gcc)"
                N64_OK=true
                break
            fi
        fi
    fi
    rm -f tc.tar.gz 2>/dev/null
done

if ! $N64_OK; then
    err "N64 toolchain (check network/log)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# LIBDRAGON SDK
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ LIBDRAGON SDK${RST}\n"

cd "$SDKS" || cd /tmp
rm -rf libdragon libdragon-trunk 2>/dev/null

if curl -fsSL --connect-timeout 30 --max-time 300 --retry 2 -L -o libdragon.tar.gz \
    "https://github.com/DragonMinded/libdragon/archive/refs/heads/trunk.tar.gz" >> "$LOG" 2>&1; then
    if tar xzf libdragon.tar.gz >> "$LOG" 2>&1; then
        mv libdragon-trunk libdragon 2>/dev/null || true
        rm -f libdragon.tar.gz
        add_path 'export LIBDRAGON="$HOME/retro-dev/sdks/libdragon"'
        ok "libdragon SDK"
    else
        err "libdragon SDK (extract failed)"
    fi
else
    err "libdragon SDK (download failed)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# DEVKITPRO
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ DEVKITPRO${RST}\n"
say "Installing DevkitPro pacman..."

cd /tmp
if dl "https://apt.devkitpro.org/install-devkitpro-pacman" dkp-install.sh; then
    chmod +x dkp-install.sh
    run sudo ./dkp-install.sh && ok "DevkitPro pacman" || err "DevkitPro pacman"
    rm -f dkp-install.sh
    
    say "Installing DevkitARM/PPC..."
    run sudo /opt/devkitpro/pacman/bin/dkp-pacman -Syu --noconfirm
    run sudo /opt/devkitpro/pacman/bin/dkp-pacman -S --noconfirm gba-dev nds-dev gamecube-dev wii-dev wiiu-dev switch-dev
    ok "DevkitPro SDKs"
else
    err "DevkitPro"
fi

add_path 'export DEVKITPRO="/opt/devkitpro"'
add_path 'export DEVKITARM="$DEVKITPRO/devkitARM"'
add_path 'export DEVKITPPC="$DEVKITPRO/devkitPPC"'
add_path 'export PATH="$DEVKITARM/bin:$DEVKITPPC/bin:$PATH"'

# ─────────────────────────────────────────────────────────────────────────────
# GBDK-2020
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ GBDK-2020${RST}\n"

cd "$SDKS"
rm -rf gbdk gbdk-linux64 2>/dev/null

if dl "https://github.com/gbdk-2020/gbdk-2020/releases/download/4.3.0/gbdk-linux64.tar.gz" gbdk.tar.gz; then
    run tar xzf gbdk.tar.gz
    mv gbdk-linux64 gbdk 2>/dev/null || true
    rm -f gbdk.tar.gz
    add_path 'export GBDK="$HOME/retro-dev/sdks/gbdk"'
    add_path 'export PATH="$GBDK/bin:$PATH"'
    ok "GBDK-2020 4.3.0"
else
    err "GBDK-2020"
fi

# ─────────────────────────────────────────────────────────────────────────────
# RGBDS
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ RGBDS${RST}\n"

mkdir -p "$TOOLS/rgbds"
cd "$TOOLS/rgbds"

if dl "https://github.com/gbdev/rgbds/releases/download/v0.8.0/rgbds-0.8.0-linux-x86_64.tar.xz" rgbds.tar.xz; then
    run tar xJf rgbds.tar.xz
    rm -f rgbds.tar.xz
    add_path 'export PATH="$HOME/retro-dev/tools/rgbds:$PATH"'
    ok "RGBDS 0.8.0"
else
    err "RGBDS"
fi

# ─────────────────────────────────────────────────────────────────────────────
# ASM6F
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ ASM6F${RST}\n"

mkdir -p "$TOOLS/asm6"
cd "$TOOLS/asm6"

if dl "https://raw.githubusercontent.com/freem/asm6f/main/asm6f.c" asm6f.c; then
    run gcc -O3 -w asm6f.c -o asm6f && chmod +x asm6f && ok "ASM6F" || err "ASM6F compile"
else
    err "ASM6F download"
fi
add_path 'export PATH="$HOME/retro-dev/tools/asm6:$PATH"'

# ─────────────────────────────────────────────────────────────────────────────
# WLA-DX
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ WLA-DX${RST}\n"

cd "$TOOLS"
rm -rf wla-dx wla-dx-10.6 2>/dev/null

if dl "https://github.com/vhelin/wla-dx/archive/refs/tags/v10.6.tar.gz" wla.tar.gz; then
    run tar xzf wla.tar.gz
    cd wla-dx-10.6
    mkdir -p build && cd build
    if run cmake .. -DCMAKE_BUILD_TYPE=Release && run make -j"$NCPU"; then
        ok "WLA-DX 10.6"
    else
        err "WLA-DX compile"
    fi
    rm -f "$TOOLS/wla.tar.gz"
else
    err "WLA-DX"
fi
add_path 'export PATH="$HOME/retro-dev/tools/wla-dx-10.6/build/binaries:$PATH"'

# ─────────────────────────────────────────────────────────────────────────────
# DASM (Atari 2600/7800)
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ DASM${RST}\n"

mkdir -p "$SDKS/atari"
cd "$SDKS/atari"

if dl "https://github.com/dasm-assembler/dasm/releases/download/2.20.14.1/dasm-2.20.14.1-linux-x64.tar.gz" dasm.tar.gz; then
    run tar xzf dasm.tar.gz
    rm -f dasm.tar.gz
    add_path 'export PATH="$HOME/retro-dev/sdks/atari:$PATH"'
    ok "DASM 2.20.14.1"
else
    err "DASM"
fi

# ─────────────────────────────────────────────────────────────────────────────
# SGDK (Genesis/Mega Drive)
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ SGDK${RST}\n"

cd "$SDKS"
rm -rf sgdk SGDK-2.00 2>/dev/null

if dl "https://github.com/Stephane-D/SGDK/archive/refs/tags/v2.00.tar.gz" sgdk.tar.gz; then
    run tar xzf sgdk.tar.gz
    mv SGDK-2.00 sgdk 2>/dev/null
    rm -f sgdk.tar.gz
    add_path 'export SGDK="$HOME/retro-dev/sdks/sgdk"'
    ok "SGDK 2.00"
else
    err "SGDK"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PVSNESLIB (SNES)
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ PVSNESLIB${RST}\n"

cd "$SDKS"
rm -rf pvsneslib pvsneslib-master 2>/dev/null

if dl "https://github.com/alekmaul/pvsneslib/archive/refs/heads/master.zip" pvs.zip; then
    run unzip -qo pvs.zip
    mv pvsneslib-master pvsneslib 2>/dev/null
    rm -f pvs.zip
    add_path 'export PVSNESLIB="$HOME/retro-dev/sdks/pvsneslib"'
    ok "PVSnesLib"
else
    err "PVSnesLib"
fi

# ─────────────────────────────────────────────────────────────────────────────
# FLIPS (IPS/BPS Patcher)
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ ROM TOOLS${RST}\n"

mkdir -p "$TOOLS/flips"
cd "$TOOLS/flips"

if dl "https://github.com/Alcaro/Flips/releases/download/v198/flips-linux.zip" flips.zip; then
    run unzip -qo flips.zip
    chmod +x flips* 2>/dev/null
    rm -f flips.zip
    ok "Flips v198"
else
    # Build fallback
    cd "$TOOLS"
    if dl "https://github.com/Alcaro/Flips/archive/refs/heads/master.tar.gz" flips-src.tar.gz; then
        run tar xzf flips-src.tar.gz
        cd Flips-master
        run ./make-linux.sh && cp flips "$TOOLS/flips/" && ok "Flips (built)" || err "Flips"
        cd "$TOOLS"
        rm -rf Flips-master flips-src.tar.gz
    else
        err "Flips"
    fi
fi
add_path 'export PATH="$HOME/retro-dev/tools/flips:$PATH"'

# ─────────────────────────────────────────────────────────────────────────────
# EMULATORS
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ EMULATORS${RST}\n"

cd "$EMUS"

# mGBA
if dl "https://github.com/mgba-emu/mgba/releases/download/0.10.5/mGBA-0.10.5-appimage-x64.appimage" mGBA.AppImage; then
    chmod +x mGBA.AppImage
    ok "mGBA 0.10.5"
else
    err "mGBA"
fi

# Ares
if dl "https://github.com/ares-emulator/ares/releases/download/v146/ares-linux-x86_64.zip" ares.zip; then
    run unzip -qo ares.zip
    chmod +x ares*/ares 2>/dev/null
    rm -f ares.zip
    ok "Ares v146"
else
    err "Ares"
fi

# ─────────────────────────────────────────────────────────────────────────────
# RAYLIB
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ RAYLIB${RST}\n"

cd "$TOOLS"
rm -rf raylib raylib-5.5 2>/dev/null

if dl "https://github.com/raysan5/raylib/archive/refs/tags/5.5.tar.gz" raylib.tar.gz; then
    run tar xzf raylib.tar.gz
    cd raylib-5.5/src
    if run make PLATFORM=PLATFORM_DESKTOP -j"$NCPU" && run sudo make install; then
        ok "Raylib 5.5 (installed)"
    else
        ok "Raylib 5.5 (source)"
    fi
    rm -f "$TOOLS/raylib.tar.gz"
else
    err "Raylib"
fi

# ─────────────────────────────────────────────────────────────────────────────
# GODOT
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ GODOT${RST}\n"

cd "$TOOLS"

if dl "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip" godot.zip; then
    run unzip -qo godot.zip
    chmod +x Godot* 2>/dev/null
    rm -f godot.zip
    ok "Godot 4.3"
else
    err "Godot"
fi

# ─────────────────────────────────────────────────────────────────────────────
# ENVIRONMENT SCRIPT
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${M}▸ ENVIRONMENT${RST}\n"

cat > "$INSTALL_DIR/env.sh" << 'ENVEOF'
#!/bin/bash
# CAT'S TWEAKER 1.8.1 WSL2 - Environment Setup

export RETRO_DEV="$HOME/retro-dev"

# N64
export N64_INST="$RETRO_DEV/compilers/n64"
export LIBDRAGON="$RETRO_DEV/sdks/libdragon"

# DevkitPro (GBA/NDS/GC/Wii/Switch)
export DEVKITPRO="/opt/devkitpro"
export DEVKITARM="$DEVKITPRO/devkitARM"
export DEVKITPPC="$DEVKITPRO/devkitPPC"

# Game Boy
export GBDK="$RETRO_DEV/sdks/gbdk"

# Genesis / Mega Drive
export SGDK="$RETRO_DEV/sdks/sgdk"

# SNES
export PVSNESLIB="$RETRO_DEV/sdks/pvsneslib"

# PATH
export PATH="$N64_INST/bin:$DEVKITARM/bin:$DEVKITPPC/bin:$GBDK/bin:$PATH"
export PATH="$RETRO_DEV/tools/rgbds:$RETRO_DEV/tools/asm6:$RETRO_DEV/tools/flips:$PATH"
export PATH="$RETRO_DEV/tools/wla-dx-10.6/build/binaries:$RETRO_DEV/sdks/atari:$PATH"

cat << 'CAT'
🐱 CAT'S TWEAKER 1.8.1 WSL2 loaded! 

  N64:        mips64-elf-gcc --version
  GB/GBC:     lcc --version  
  GBA/NDS:    arm-none-eabi-gcc --version
  Genesis:    $SGDK
  SNES:       $PVSNESLIB
  Atari:      dasm
  ROM Patch:  flips

  Emulators:  ~/retro-dev/emulators/
  Tools:      ~/retro-dev/tools/
CAT
ENVEOF

chmod +x "$INSTALL_DIR/env.sh"

# Add sourcing to bashrc
add_path ''
add_path '# CAT'\''S TWEAKER'
add_path 'source "$HOME/retro-dev/env.sh" 2>/dev/null'

ok "Environment script"

# ─────────────────────────────────────────────────────────────────────────────
# COMPLETE
# ─────────────────────────────────────────────────────────────────────────────
echo ""
printf "${G}  ╔═══════════════════════════════════════════════════════════════╗${RST}\n"
printf "${G}  ║${RST}  ${W}✨ CAT'S TWEAKER 1.8.1 WSL2 COMPLETE! ✨${RST}                     ${G}║${RST}\n"
printf "${G}  ╠═══════════════════════════════════════════════════════════════╣${RST}\n"
printf "${G}  ║${RST}  ${C}Installed:${RST}  %-47s ${G}║${RST}\n" "$INSTALL_DIR"
printf "${G}  ║${RST}  ${C}Activate:${RST}   source ~/.bashrc                                 ${G}║${RST}\n"
printf "${G}  ║${RST}  ${C}Log:${RST}        ~/retro-dev/install.log                         ${G}║${RST}\n"
printf "${G}  ╚═══════════════════════════════════════════════════════════════╝${RST}\n"
echo ""
printf "                           ${M}/\\_____/\\${RST}\n"
printf "                          ${M}/  o   o  \\${RST}\n"
printf "                         ${M}( ==  ^  == )${RST}\n"
printf "                          ${M})  ~nya~  (${RST}\n"
printf "                         ${M}(           )${RST}\n"
printf "                        ${M}( (  )   (  ) )${RST}\n"
printf "                       ${M}(__(__)___(__)__)${RST}\n"
echo ""
printf "  ${Y}Run:${RST} source ~/.bashrc${RST}\n\n"

log "=== INSTALL COMPLETE ==="

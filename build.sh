#!/usr/bin/env bash
# Based on YAKB v2.0 by cyberknight777 (GPLv3), adapted for the RMX2020 4.19 kernel
# (mt6768-dev lineage-23.2 base + RMX2020 patches).
# Copyright (c) 2022-2023 Cyber Knight <cyberknight755@gmail.com>
#
#			GNU GENERAL PUBLIC LICENSE
#			 Version 3, 29 June 2007
#
# Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
# Everyone is permitted to copy and distribute verbatim copies
# of this license document, but changing it is not allowed.

# Some Placeholders: [!] [*] [✓] [✗]

# Single defconfig like the 4.14 tree: arch/arm64/configs/RMX2020_defconfig
# (generated from vendor/mt6768_defconfig + vendor/rmx2020.config + vendor/rmx2020_bringup.config).
# LAYERED=1 builds from the base defconfig + fragments instead (BRINGUP=0 then skips the bring-up fragment).
# Run "bash $0 mkdef" to regenerate RMX2020_defconfig from the fragments after editing them.
LAYERED="${LAYERED:-0}"
BRINGUP="${BRINGUP:-1}"
LAYERS=(vendor/mt6768_defconfig vendor/rmx2020.config)
if [[ "${BRINGUP}" == "1" ]]; then
    LAYERS+=(vendor/rmx2020_bringup.config)
fi
if [[ "${LAYERED}" == "1" ]]; then
    CONFIGS=("${LAYERS[@]}")
else
    CONFIGS=(RMX2020_defconfig)
fi
export CONFIGS

# Default directory where kernel is located in.
KDIR=$(pwd)
export KDIR

# Default linker to use for builds (only used by the gcc toolchain branch).
export LINKER="ld"

# Device name.
export DEVICE="Realme C3/Narzo 10A"

# Date of build.
DATE=$(date +"%Y-%m-%d")
export DATE

# Device codename.
export CODENAME="RMX2020"

# Oppo project overlay to build/merge (oppo6769_19741 | oppo6769_19747 | oppo6769_206AC).
# The first one is also what vendor/rmx2020.config puts in BUILD_ARM64_DTB_OVERLAY_IMAGE_NAMES.
export PROJECT="${PROJECT:-oppo6769_19741}"

# Use the dtb with the overlay already merged in (Image.gz-dtb-<PROJECT>) when packing the zip.
# Run "mdtb" first. Needs fdtoverlay (apt install device-tree-compiler).
export MERGED="${MERGED:-0}"

# dtbo.img page size (MTK dtbo usually uses 2048).
export DTBO_PAGE_SIZE="${DTBO_PAGE_SIZE:-2048}"

# Builder name.
export BUILDER="szyryjn"

# Kernel repository URL.
export REPO_URL="https://github.com/szyryjn911/kernel_realme_RMX2020-4.19.git"

# Commit hash of HEAD.
COMMIT_HASH=$(git rev-parse --short HEAD)
export COMMIT_HASH

# Number of jobs to run.
PROCS=$(nproc --all)
export PROCS

# Compiler to use for builds.
export COMPILER=clang

# Telegram Information. Set 1 to enable. | Set 0 to disable.
# NEVER hardcode the bot token in this file. Export TG_TOKEN and TG_CHATID, or put them in ~/.tgrc:
export TG_TOKEN="8914494265:AAFzeRsUUBRm7NHFL7NWaIJzACDqDZyftrU"
export TG_CHATID="-1003908567563"
# shellcheck disable=SC1090
[ -f "${HOME}/.tgrc" ] && source "${HOME}/.tgrc"
export TGI="${TGI:-1}"
TOKEN="${TG_TOKEN:-}"
CHATID="${TG_CHATID:-}"
if [[ -z "${TOKEN}" || -z "${CHATID}" ]]; then
    TGI=1
fi
export TGI TOKEN CHATID

# Architecture.
export ARCH=arm64

# Common directories setup.
OUT_DIR="${KDIR}/out"

# Requirements
if [[ "${COMPILER}" = gcc ]]; then
    if [ ! -d "${KDIR}/gcc64" ]; then
        echo "Downloading arm64 gcc..."
        curl -s https://api.github.com/repos/mvaisakh/gcc-build/releases/latest | grep "eva-gcc-arm64-" | cut -d : -f 2,3 | tr -d \" | wget -O gcc-arm64.xz -qi -
        tar -xf gcc-arm64.xz
        rm gcc-arm64.xz
        mv "${KDIR}"/gcc-arm64 "${KDIR}"/gcc64
    fi

    if [ ! -d "${KDIR}/gcc32" ]; then
        echo "Downloading arm gcc..."
        curl -s https://api.github.com/repos/mvaisakh/gcc-build/releases/latest | grep "eva-gcc-arm-" | cut -d : -f 2,3 | tr -d \" | wget -O gcc-arm.xz -qi -
        tar -xf gcc-arm.xz
        rm gcc-arm.xz
        mv "${KDIR}"/gcc-arm "${KDIR}"/gcc32
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/gcc64/bin/aarch64-elf-gcc --version | head -n 1)
    export KBUILD_COMPILER_STRING
    export PATH="${KDIR}"/gcc32/bin:"${KDIR}"/gcc64/bin:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
        O="${OUT_DIR}"
        CROSS_COMPILE=aarch64-elf-
        CROSS_COMPILE_ARM32=arm-eabi-
        CROSS_COMPILE_COMPAT=arm-eabi-
        LD="${KDIR}"/gcc64/bin/aarch64-elf-"${LINKER}"
        AR=llvm-ar
        NM=llvm-nm
        OBJDUMP=llvm-objdump
        OBJCOPY=llvm-objcopy
        OBJSIZE=llvm-objsize
        STRIP=llvm-strip
        HOSTAR=llvm-ar
        HOSTCC=gcc
        HOSTCXX=aarch64-elf-g++
        CC=aarch64-elf-gcc
    )

elif [[ ${COMPILER} == clang ]]; then
	if [ ! -f "${KDIR}/neutron-clang/bin/clang" ]; then
		rm -rf "${KDIR}"/neutron-clang
		mkdir "${KDIR}"/neutron-clang
		cd "${KDIR}"/neutron-clang || exit 1
		bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") -S
		cd "${KDIR}" || exit 1
	fi

	KBUILD_COMPILER_STRING=$("${KDIR}"/neutron-clang/bin/clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')
	export KBUILD_COMPILER_STRING
	export PATH=$KDIR/neutron-clang/bin/:/usr/bin/:${PATH}
	# The 4.19 tree supports LLVM=1 / LLVM_IAS (backported in its Makefile).
	MAKE+=(
		ARCH=arm64
		O="${OUT_DIR}"
		CROSS_COMPILE=aarch64-linux-gnu-
		CROSS_COMPILE_ARM32=arm-linux-gnueabi-
		LLVM=1
		LLVM_IAS=1
	)
fi

if [ ! -d "${KDIR}/AnyKernel3/" ]; then
	git clone -b RMX2020 https://github.com/szyryjn/AnyKernel3
fi

export KBUILD_BUILD_USER="szyryjn"
export KBUILD_BUILD_HOST="Death-Note"
KVER=$(make kernelversion 2>/dev/null | cut -d. -f1,2)
zipn="SHINIGAMI-KERNEL-${CODENAME}-${KVER:-4.19}-$(date '+%Y%m%d-%H%M').zip"
if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
        zipn="${zipn::-4}-$(echo $head | cut -c1-8).zip"
fi

# A function to exit on SIGINT.
exit_on_signal_SIGINT() {
	echo -e "\n\n\e[1;31m[✗] Received INTR call - Exiting...\e[0m"
	exit 0
}
trap exit_on_signal_SIGINT SIGINT

# A function to send message(s) via Telegram's BOT api.
tg() {
	local response
	response=$(curl -sX POST https://api.telegram.org/bot"${TOKEN}"/sendMessage \
		--data-urlencode chat_id="${CHATID}" \
		--data-urlencode parse_mode=Markdown \
		--data-urlencode disable_web_page_preview=true \
		--data-urlencode text="$1")

	if ! echo "$response" | grep -q '"ok":true'; then
		local err
		err=$(echo "$response" | sed -n 's/.*"description":"\([^"]*\)".*/\1/p')
		echo -e "\n\e[1;31m[✗] tg(): Failed to send message: ${err:-Unknown error}\e[0m" >&2
	fi
}

# A function to send file(s) via Telegram's BOT api.
tgs() {
	local MD5 response
	MD5=$(md5sum "$1" | cut -d' ' -f1)

	response=$(curl -sX POST -F document=@"$1" https://api.telegram.org/bot"${TOKEN}"/sendDocument \
		-F "chat_id=${CHATID}" \
		-F "parse_mode=Markdown" \
		-F "caption=$2 | *MD5*: \`$MD5\`")

	if ! echo "$response" | grep -q '"ok":true'; then
		local err
		err=$(echo "$response" | sed -n 's/.*"description":"\([^"]*\)".*/\1/p')
		echo -e "\n\e[1;31m[✗] tgs(): Failed to send file '$1': ${err:-Unknown error}\e[0m" >&2
	fi
}

# A function to handle notifying errors.
abort() {
	if [[ ${TGI} == "1" ]]; then
		if [ -z "${2}" ]; then
			tg "*${1}*"
		else
			tgs "${2}" "*${1}*"
		fi
	fi
	echo -e "\n\e[1;31m[✗] ${1}\e[0m"
	exit 1
}

# A function to clean kernel source prior building.
clean() {
	echo -e "\n\e[1;93m[*] Cleaning source, out/ and AnyKernel3 directory! \e[0m"
	make clean && make mrproper && rm -rf "${OUT_DIR}" || abort "Failed to clean source and remove out/ directory!"
	rm -rf "${KDIR}"/AnyKernel3/*.zip || abort "Failed to clean up AnyKernel3 directory!"
	echo -e "\n\e[1;32m[✓] Source cleaned, out/ removed and AnyKernel3 cleaned! \e[0m"
}

# A function to (re)generate .config from the base defconfig + fragments.
# NOTE: unlike the 4.14 script this does NOT copy .config back into arch/arm64/configs,
# because that would overwrite vendor/mt6768_defconfig with a full config.
rgn() {
	echo -e "\n\e[1;93m[*] Generating config: ${CONFIGS[*]} \e[0m"
	local cfg
	for cfg in "${CONFIGS[@]}"; do
		make "${MAKE[@]}" "${cfg}" || abort "Failed to apply ${cfg}!"
	done
	echo -e "\n\e[1;32m[✓] Config generated! \e[0m"
}

# A function to open a menu based program to update current config.
# Single-defconfig mode (default): the result is saved back into arch/arm64/configs/RMX2020_defconfig.
# LAYERED=1: saved as vendor/rmx2020_saved_defconfig, fold the changes into the fragments by hand.
mcfg() {
	rgn
	echo -e "\n\e[1;93m[*] Making Menuconfig! \e[0m"
	make "${MAKE[@]}" menuconfig || abort "Failed to run menuconfig!"
	make "${MAKE[@]}" savedefconfig || abort "Failed to run savedefconfig!"
	local dst="${KDIR}/arch/arm64/configs/RMX2020_defconfig"
	[[ "${LAYERED}" == "1" ]] && dst="${KDIR}/arch/arm64/configs/vendor/rmx2020_saved_defconfig"
	cp -f "${OUT_DIR}"/defconfig "${dst}" || abort "Failed to copy defconfig!"
	echo -e "\n\e[1;32m[✓] Saved to ${dst#${KDIR}/} \e[0m"
}

# A function to regenerate RMX2020_defconfig from base defconfig + fragments.
mkdef() {
	local saved=("${CONFIGS[@]}")
	CONFIGS=("${LAYERS[@]}")
	rgn
	make "${MAKE[@]}" savedefconfig || abort "Failed to run savedefconfig!"
	cp -f "${OUT_DIR}"/defconfig "${KDIR}"/arch/arm64/configs/RMX2020_defconfig || abort "Failed to copy defconfig!"
	CONFIGS=("${saved[@]}")
	echo -e "\n\e[1;32m[✓] arch/arm64/configs/RMX2020_defconfig regenerated from: ${LAYERS[*]} \e[0m"
}

# A function to build the kernel.
img() {
	if [[ "${TGI}" != "0" ]]; then
		tg "
*=====================
        S H I N I G A M I
           K E R N E L      
=====================*
*Compiler*: \`${KBUILD_COMPILER_STRING}\`
*Linux Version*: \`$(make kernelversion 2>/dev/null)\`
*Developer*: \`${BUILDER}\`
*Device*: \`${DEVICE}\`
*Codename*: \`${CODENAME}\`
*Build Date*: \`$(date +'%Y-%m-%d %H:%M')\`
*Last Commit Name*: \`$(git log --format='%s' -1)\`
*Last Commit Hash*: [${COMMIT_HASH}](${REPO_URL}/commit/${COMMIT_HASH})
"
	fi
	rgn
	echo -e "\n\e[1;93m[*] Building Kernel! \e[0m"
	BUILD_START=$(date +"%s")
	time make -k -j"$PROCS" "${MAKE[@]}" KCFLAGS="-fdiagnostics-color=always" Image.gz-dtb Image.gz 2>&1 | tee log.txt
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))
	if [ -f "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb" ] || [ -f "${OUT_DIR}/arch/arm64/boot/Image.gz" ]; then
		if [[ "${TGI}" != "0" ]]; then
			tg "*Build Duration*: \`$((DIFF / 60)).$((DIFF % 60)) mins\`"
		fi
		echo -e "\n\e[1;32m[✓] Kernel built after $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! \e[0m"
	else
		abort "Build Failed!" "${KDIR}/log.txt"
	fi
}

# A function to build dtbo.img from the overlays listed in CONFIG_BUILD_ARM64_DTB_OVERLAY_IMAGE_NAMES.
# The 4.19 tree has no dtbo.img make target, so mkdtboimg.py (AOSP) is used.
mkdtbo() {
	local tool="${HOME}/.cache/yakb/mkdtboimg.py"
	if [ ! -s "${tool}" ]; then
		mkdir -p "$(dirname "${tool}")"
		echo -e "\n\e[1;93m[*] Downloading mkdtboimg.py \e[0m"
		curl -sfL "https://raw.githubusercontent.com/LineageOS/android_system_libufdt/lineage-21.0/utils/src/mkdtboimg.py" -o "${tool}" \
			|| curl -sfL "https://android.googlesource.com/platform/system/libufdt/+/refs/heads/master/utils/src/mkdtboimg.py?format=TEXT" | base64 -d > "${tool}"
		[ -s "${tool}" ] || { rm -f "${tool}"; abort "Failed to download mkdtboimg.py!"; }
	fi
	local names name files=()
	names=$(grep '^CONFIG_BUILD_ARM64_DTB_OVERLAY_IMAGE_NAMES=' "${OUT_DIR}/.config" | cut -d'"' -f2)
	for name in ${names}; do
		[ -f "${OUT_DIR}/arch/arm64/boot/dts/${name}.dtbo" ] || abort "Missing ${name}.dtbo, run dtb first!"
		files+=("${OUT_DIR}/arch/arm64/boot/dts/${name}.dtbo")
	done
	[ ${#files[@]} -gt 0 ] || abort "No overlay names found in .config!"
	python3 "${tool}" create "${OUT_DIR}/arch/arm64/boot/dtbo.img" --page_size="${DTBO_PAGE_SIZE}" "${files[@]}" || abort "Failed to create dtbo.img!"
	echo -e "\n\e[1;32m[✓] dtbo.img created from: ${names} \e[0m"
}

# A function to build DTBs (+ dtbo.img).
dtb() {
	rgn
	echo -e "\n\e[1;93m[*] Building DTBS! \e[0m"
	time make -j"$PROCS" "${MAKE[@]}" dtbs || abort "Failed to build DTBs!"
	mkdtbo
	echo -e "\n\e[1;32m[✓] Built DTBS! \e[0m"
}

# A function to create Image.gz-dtb with the overlay merged into the platform dtb.
# Handy for temporary boots (fastboot boot) when the dtbo partition is the old 4.14 one.
mdtb() {
	echo -e "\n\e[1;93m[*] Merging ${PROJECT} overlay into mt6768.dtb! \e[0m"
	command -v fdtoverlay >/dev/null || abort "fdtoverlay not found (apt install device-tree-compiler)!"
	[ -f "${OUT_DIR}/arch/arm64/boot/Image.gz" ] || abort "Build the kernel first (img)!"
	bash "${KDIR}/scripts/rmx2020_merge_dtb.sh" "${OUT_DIR}" "${PROJECT}" || abort "Failed to merge dtb!"
	echo -e "\n\e[1;32m[✓] Created Image.gz-dtb-${PROJECT} \e[0m"
}

# A function to build a boot.img from the STOCK boot.img (new kernel + new merged dtb) for `fastboot boot`.
# Usage: STOCK_BOOT=/path/to/boot_backup.img bash $0 mkboot      (run img first)
mkboot() {
	[ -f "${STOCK_BOOT:-}" ] || abort "Set STOCK_BOOT=/path/to/stock/boot.img (a backup of the device's boot partition)!"
	[ -f "${OUT_DIR}/arch/arm64/boot/Image.gz" ] || abort "Build the kernel first (img)!"
	command -v fdtoverlay >/dev/null || echo -e "\n\e[1;33m[!] fdtoverlay missing (apt install device-tree-compiler): the overlay will NOT be merged\e[0m"
	python3 "${KDIR}/scripts/rmx2020_mkboot.py" "${STOCK_BOOT}" "${OUT_DIR}" -p "${PROJECT}" -o "${KDIR}/new-boot.img" || abort "Failed to create new-boot.img!"
	echo -e "\n\e[1;32m[✓] ${KDIR}/new-boot.img created: fastboot boot new-boot.img \e[0m"
}

# A function to build out-of-tree modules.
mod() {
	if [[ ${TGI} == "1" ]]; then
		tg "*Building Modules!*"
	fi
	rgn
	echo -e "\n\e[1;93m[*] Building Modules! \e[0m"
	mkdir -p "${OUT_DIR}"/modules
	make "${MAKE[@]}" modules_prepare || abort "Failed to prepare modules!"
	make -j"$PROCS" "${MAKE[@]}" modules INSTALL_MOD_PATH="${OUT_DIR}"/modules || abort "Failed to build modules!"
	make "${MAKE[@]}" modules_install INSTALL_MOD_PATH="${OUT_DIR}"/modules || abort "Failed to install modules!"
	mkdir -p "${KDIR}"/AnyKernel3/modules/system/lib/modules/
	find "${OUT_DIR}"/modules -type f -iname '*.ko' -exec cp {} "${KDIR}"/AnyKernel3/modules/system/lib/modules/ \;
	echo -e "\n\e[1;32m[✓] Built Modules! \e[0m"
}

# A function to inject build date AND compiler version into anykernel.sh after compilation.
#
# anykernel.sh needs these two placeholders:
#   ##CLANG_VERSION##   -> replaced with the compiler string
#   ##BUILD_DATE##      -> replaced with the current date/time
# The original anykernel.sh is kept as anykernel.sh.orig so every build starts from the
# placeholders again (the 4.14 version replaced them once and could never update them).
patch_anykernel() {
    local AK3_SCRIPT="${KDIR}/AnyKernel3/anykernel.sh"

    [ -f "${AK3_SCRIPT}.orig" ] || cp "${AK3_SCRIPT}" "${AK3_SCRIPT}.orig"
    cp "${AK3_SCRIPT}.orig" "${AK3_SCRIPT}"

    local CLANG_SHORT
    if [[ "${COMPILER}" == clang ]]; then
        CLANG_SHORT=$(echo "${KBUILD_COMPILER_STRING}" | grep -oP 'clang \d+\.\d+\.\d+' | head -1)
        CLANG_SHORT="${CLANG_SHORT:-${KBUILD_COMPILER_STRING}}"
    else
        CLANG_SHORT="${KBUILD_COMPILER_STRING}"
    fi

    local BUILD_DATETIME
    BUILD_DATETIME=$(date '+%Y-%m-%d %H:%M')

    sed -i "s|##CLANG_VERSION##|${CLANG_SHORT}|g" "${AK3_SCRIPT}" \
        || abort "Failed to patch CLANG_VERSION in anykernel.sh!"
    sed -i "s|##BUILD_DATE##|${BUILD_DATETIME}|g" "${AK3_SCRIPT}" \
        || abort "Failed to patch BUILD_DATE in anykernel.sh!"

    echo -e "\n\e[1;32m[✓] anykernel.sh patched — Compiler: ${CLANG_SHORT} | Date: ${BUILD_DATETIME}\e[0m"
}

# A function to build an AnyKernel3 zip.
mkzip() {
	if [[ ${TGI} == "1" ]]; then
		tg "*Building zip!*"
	fi
	echo -e "\n\e[1;93m[*] Building zip! \e[0m"
	mkdir -p "${KDIR}"/AnyKernel3/dtbs
	# Remove images of previous builds so an old one can never end up in the zip.
	rm -f "${KDIR}"/AnyKernel3/Image.gz "${KDIR}"/AnyKernel3/Image.gz-dtb "${KDIR}"/AnyKernel3/dtbo.img "${KDIR}"/AnyKernel3/dtb.img

	if [[ "${MERGED}" == "1" ]]; then
		[ -f "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb-${PROJECT}" ] || abort "MERGED=1 but Image.gz-dtb-${PROJECT} missing, run mdtb first!"
		cp "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb-${PROJECT}" "${KDIR}"/AnyKernel3/Image.gz-dtb || abort "Failed to copy merged image!"
	elif [ -f "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb" ]; then
		cp "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb" "${KDIR}"/AnyKernel3 || abort "Failed to copy Image.gz-dtb!"
	elif [ -f "${OUT_DIR}/arch/arm64/boot/Image.gz" ]; then
		cp "${OUT_DIR}/arch/arm64/boot/Image.gz" "${KDIR}"/AnyKernel3 || abort "Failed to copy Image.gz!"
	else
		abort "No kernel image found!"
	fi
	# dtbo and dtb are optional — copy only if they exist.
	# The new 4.19 dtb needs the matching new dtbo, build it with the "dtb" option first.
	[ -f "${OUT_DIR}/arch/arm64/boot/dtbo.img" ] && cp "${OUT_DIR}/arch/arm64/boot/dtbo.img" "${KDIR}"/AnyKernel3
	[ -f "${OUT_DIR}/arch/arm64/boot/dtb.img" ] && cp "${OUT_DIR}/arch/arm64/boot/dtb.img" "${KDIR}"/AnyKernel3

    patch_anykernel

    cd "${KDIR}"/AnyKernel3 || abort "Failed to cd into AnyKernel3!"
	zip -r9 "$zipn" . -x ".git*" -x "README.md" -x "LICENSE" -x "*.zip" -x "*.orig" || abort "Failed to create zip!"
	echo -e "\n\e[1;32m[✓] Built zip! \e[0m"
	if [[ "${TGI}" != "0" ]]; then
		tgs "${zipn}" "*${KBUILD_COMPILER_STRING}*"
	fi
	cd "${KDIR}" || exit 1
}

# A function to build specific objects.
obj() {
	rgn
	echo -e "\n\e[1;93m[*] Building ${1}! \e[0m"
	time make -j"$PROCS" "${MAKE[@]}" "$1" || abort "Failed to build ${1}!"
	echo -e "\n\e[1;32m[✓] Built ${1}! \e[0m"
}

# A function to showcase the options provided for args-based usage.
helpmenu() {
	echo -e "\n\e[1m
usage: bash $0 <arg>

example: bash $0 img
example: bash $0 img dtb mkzip
example: bash $0 img mdtb          (temporary boot with merged dtb)
example: MERGED=1 bash $0 mkzip    (zip with the merged dtb)
example: LAYERED=1 BRINGUP=0 bash $0 img   (base defconfig + fragments, without bring-up)
example: bash $0 --obj=drivers/misc/mediatek/lcm/
example: PROJECT=oppo6769_19747 bash $0 mdtb

	 mcfg   Runs make menuconfig (saves back into RMX2020_defconfig)
	 img    Builds Kernel (Image.gz-dtb)
	 dtb    Builds dtbs + dtbo.img
	 dtbo   Builds only dtbo.img (after dtb)
	 mdtb   Merges the overlay into the dtb -> Image.gz-dtb-<PROJECT>
	 mkboot Builds new-boot.img from STOCK_BOOT=<stock boot.img> (new kernel + new dtb)
	 mod    Builds out-of-tree modules
	 mkzip  Builds anykernel3 zip
	 --obj  Builds specific driver/subsystem
	 rgn    Regenerates .config from RMX2020_defconfig
	 mkdef  Regenerates RMX2020_defconfig from the vendor/ fragments
	 clean  make clean/mrproper, removes out/
\e[0m"
}

# A function to setup plain select-based menu (no dialog needed).
ndialog() {
	while true; do
		echo -e "\n\e[1;36m╔══════════════════════════════╗\e[0m"
		echo -e "\e[1;36m║   S H I N I G A M I          ║\e[0m"
		echo -e "\e[1;36m║      K E R N E L  4.19       ║\e[0m"
		echo -e "\e[1;36m╚══════════════════════════════╝\e[0m"
		echo -e "\e[1;33m  Device  :\e[0m ${DEVICE} (${CODENAME})"
		echo -e "\e[1;33m  Builder :\e[0m ${BUILDER}"
		echo -e "\e[1;33m  Compiler:\e[0m ${KBUILD_COMPILER_STRING}"
		echo -e "\e[1;33m  Configs :\e[0m ${CONFIGS[*]}"
		echo -e "\e[1;33m  Project :\e[0m ${PROJECT} (merged zip: ${MERGED})"
		echo -e ""
		echo -e "\e[1;37m  [1]\e[0m Build Kernel"
		echo -e "\e[1;37m  [2]\e[0m Build DTBs + dtbo.img"
		echo -e "\e[1;37m  [3]\e[0m Build Modules"
		echo -e "\e[1;37m  [4]\e[0m Open Menuconfig"
		echo -e "\e[1;37m  [5]\e[0m Regenerate Config"
		echo -e "\e[1;37m  [6]\e[0m Build AnyKernel3 Zip"
		echo -e "\e[1;37m  [7]\e[0m Build Specific Object"
		echo -e "\e[1;37m  [8]\e[0m Clean + Build Kernel"
		echo -e "\e[1;37m  [9]\e[0m Merge overlay into dtb (temporary boot image)"
		echo -e "\e[1;31m  [0]\e[0m Exit"
		echo -e ""
		echo -ne "\e[1;32m  Choose an option: \e[0m"
		read -r CHOICE

		case "$CHOICE" in
		1)
			img
			;;
		2)
			dtb
			;;
		3)
			mod
			;;
		4)
			mcfg
			;;
		5)
			rgn
			;;
		6)
			mkzip
			;;
		7)
			echo -ne "\n\e[1;93m  Enter object path (e.g. drivers/misc/mediatek/lcm/): \e[0m"
			read -r ob
			if [ -z "$ob" ]; then
				echo -e "\e[1;31m[✗] No path entered!\e[0m"
			else
				obj "$ob"
			fi
			;;
		8)
			clean
			img
			;;
		9)
			mdtb
			;;
		0)
			echo -e "\n\e[1m  Exiting YAKB...\e[0m"
			exit 0
			;;
		*)
			echo -e "\n\e[1;31m[✗] Invalid option! Try again.\e[0m"
			;;
		esac

		echo -ne "\n\e[1m  Press Enter to return to menu or type 0 to exit: \e[0m"
		read -r back
		if [ "$back" == "0" ]; then
			echo -e "\n\e[1m  Exiting YAKB...\e[0m"
			exit 0
		fi
	done
}

if [[ -z $* ]]; then
	ndialog
fi

for arg in "$@"; do
	case "${arg}" in
	"mcfg")
		mcfg
		;;
	"img")
		img
		;;
	"dtb")
		dtb
		;;
	"dtbo")
		mkdtbo
		;;
	"mdtb")
		mdtb
		;;
	"mkboot")
		mkboot
		;;
	"mod")
		mod
		;;
	"mkzip")
		mkzip
		;;
	"--obj="*)
		object="${arg#*=}"
		if [[ -z $object ]]; then
			echo "Use --obj=filename.o"
			exit 1
		else
			obj "$object"
		fi
		;;
	"rgn")
		rgn
		;;
	"mkdef")
		mkdef
		;;
	"clean")
		clean
		;;
	"help")
		helpmenu
		exit 1
		;;
	*)
		helpmenu
		exit 1
		;;
	esac
done

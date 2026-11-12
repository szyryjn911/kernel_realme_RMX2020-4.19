#!/usr/bin/env python3
"""
RMX2020 4.19 bring-up helper: build a boot.img from the STOCK boot.img with the new kernel
and the new dtb (platform dtb + oppo6769 overlay merged).

Why: an AnyKernel zip may keep the old 4.14 dtb that lives in the boot image's own dtb section
(header v2). The bootloader then ignores the dtb appended to the kernel and the 4.19 kernel
boots with a 4.14 dtb (e.g. "[SSPM] cannot find property sspm_mem_key").

usage: scripts/rmx2020_mkboot.py STOCK_BOOT.img OUT_DIR [-p oppo6769_19741] [-o new-boot.img]
       fastboot boot new-boot.img        # temporary boot, nothing is written to the device

needs: python3, fdtoverlay (apt install device-tree-compiler) to merge the overlay into the dtb.
"""
import argparse
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import urllib.request

BASE = "https://raw.githubusercontent.com/LineageOS/android_system_tools_mkbootimg/lineage-19.1/"
CACHE = os.path.join(os.path.expanduser("~"), ".cache", "yakb", "mkbootimg")


def fetch_tools():
    os.makedirs(CACHE, exist_ok=True)
    for f in ("mkbootimg.py", "unpack_bootimg.py"):
        dst = os.path.join(CACHE, f)
        if not os.path.exists(dst) or os.path.getsize(dst) < 1000:
            print("[*] downloading", f)
            urllib.request.urlretrieve(BASE + f, dst)
    return os.path.join(CACHE, "mkbootimg.py"), os.path.join(CACHE, "unpack_bootimg.py")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("stock", help="stock boot.img (backup from the device)")
    ap.add_argument("out", help="kernel build dir (the O= directory, e.g. out)")
    ap.add_argument("-p", "--project", default="oppo6769_19741")
    ap.add_argument("-o", "--output", default="new-boot.img")
    ap.add_argument("--no-merge", action="store_true",
                    help="use the plain platform dtb without the oppo overlay (the RMX2020 hardware nodes are then "
                         "missing unless the bootloader applies a matching dtbo from the dtbo partition)")
    a = ap.parse_args()

    boot = os.path.join(a.out, "arch", "arm64", "boot")
    dts = os.path.join(boot, "dts", "mediatek")
    kernel = os.path.join(boot, "Image.gz")
    if not os.path.exists(kernel):
        kernel = os.path.join(boot, "Image")
    base_dtb = os.path.join(dts, "mt6768.dtb")
    overlay = os.path.join(dts, a.project + ".dtbo")
    for f in (kernel, base_dtb):
        if not os.path.exists(f):
            sys.exit("missing " + f + " (build the kernel and the dtbs first)")

    mkbootimg, unpack = fetch_tools()
    tmp = tempfile.mkdtemp(prefix="rmx2020_boot_")

    # 1) merged dtb (platform dtb + oppo overlay), independent of the dtbo partition
    dtb = base_dtb
    if a.no_merge:
        print("[!] --no-merge: using the plain platform dtb (no RMX2020 overlay)")
    else:
        if not os.path.exists(overlay):
            sys.exit("missing %s (build the kernel first, or pick another -p project)" % overlay)
        if not shutil.which("fdtoverlay"):
            sys.exit("fdtoverlay not found, it is needed to merge the overlay into the dtb:\n"
                     "    sudo apt-get update && sudo apt-get install -y device-tree-compiler\n"
                     "(or use --no-merge if the dtbo partition already has a matching overlay)")
        dtb = os.path.join(tmp, "mt6768-%s.dtb" % a.project)
        subprocess.run(["fdtoverlay", "-i", base_dtb, "-o", dtb, overlay], check=True)
        print("[+] merged %s into mt6768.dtb" % a.project)

    # 2) unpack the stock image and get its mkbootimg arguments
    print("[*] stock boot image:")
    info = subprocess.run([sys.executable, unpack, "--boot_img", a.stock, "--out", os.path.join(tmp, "u")],
                          check=True, capture_output=True, text=True).stdout
    print("    " + info.strip().replace("\n", "\n    "))
    out = subprocess.run([sys.executable, unpack, "--boot_img", a.stock, "--out", os.path.join(tmp, "u"),
                          "--format=mkbootimg"], check=True, capture_output=True, text=True).stdout
    args = shlex.split(out)

    def pop(opt):
        if opt in args:
            i = args.index(opt)
            v = args[i + 1]
            del args[i:i + 2]
            return v
        return None

    header = int(args[args.index("--header_version") + 1]) if "--header_version" in args else 0
    pop("--kernel")
    stock_dtb = pop("--dtb")
    has_dtb_section = bool(stock_dtb) and os.path.exists(stock_dtb) and os.path.getsize(stock_dtb) > 0
    pop("--output")

    if header >= 2 and has_dtb_section:
        # the bootloader takes the dtb from the boot image's dtb section: replace it
        new_kernel = kernel
        args += ["--dtb", dtb]
        print("[+] header v%d with a dtb section: new dtb goes into the dtb section" % header)
    else:
        # no dtb section: the dtb has to be appended to the kernel
        new_kernel = os.path.join(tmp, "Image.gz-dtb")
        with open(new_kernel, "wb") as o:
            for f in (kernel, dtb):
                with open(f, "rb") as i:
                    shutil.copyfileobj(i, o)
        if stock_dtb:
            args += ["--dtb", stock_dtb] if has_dtb_section else []
        print("[+] header v%d without a dtb section: dtb appended to the kernel" % header)

    cmd = [sys.executable, mkbootimg, "--kernel", new_kernel] + args + ["--output", a.output]
    subprocess.run(cmd, check=True)
    print("[+] wrote %s (%d bytes)" % (a.output, os.path.getsize(a.output)))
    print("    temporary boot : fastboot boot %s" % a.output)
    print("    flash (careful): fastboot flash boot %s   (keep a backup of the stock boot/dtbo!)" % a.output)
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()

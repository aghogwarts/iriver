# iRiver IFP-180TC on macOS — Setup Guide

Your IFP-180TC is in **Manager Mode** (Vendor `0x4102`, Product `0x1001`), which uses iRiver's proprietary USB protocol. Finder only recognizes USB Mass Storage devices, so you need special software to talk to it.

---

## Option A: Switch to UMS Mode (Easiest — Try This First)

Some IFP models can switch firmware modes from the player menu:

1. On the player, press and hold **NAVI/MENU**
2. Navigate to **GENERAL** settings
3. Look for a **USB Mode** option
4. If present, switch from **Manager** → **UMS (Mass Storage)**
5. Reconnect to your Mac — it should now appear in Finder as a USB drive

**Trade-off:** UMS mode doesn't support OGG Vorbis playback (MP3/WMA still work fine).

If your player doesn't have this option (the IFP-180TC does not), proceed to Option B.

---

## Option B: Build `libifp` + `ifp` CLI Tool on macOS

This compiles the open-source reverse-engineered driver that speaks the iRiver protocol.

### Prerequisites

Install [Homebrew](https://brew.sh) if you don't have it:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Step 1: Install dependencies

```bash
brew install libusb libusb-compat wget
```

`libusb-compat` provides the legacy `libusb-0.1` API that libifp expects. `libusb` is the modern USB access library. `wget` is for downloading the source tarball.

### Step 2: Download and extract libifp

```bash
cd ~/Downloads
wget https://sourceforge.net/projects/ifp-driver/files/libifp/1.0.1.0-stable/libifp-1.0.1.0.tar.gz/download -O libifp-1.0.1.0.tar.gz
tar xzf libifp-1.0.1.0.tar.gz
cd libifp-1.0.1.0
```

### Step 3: Configure and build

The key is telling the build system where to find `libusb-compat` and to link against it. The `configure` script's `--with-libusb-prefix` flag is broken in this version, so you must pass linker flags directly:

```bash
LDFLAGS="-L$(brew --prefix libusb-compat)/lib" LIBS="-lusb" ./configure
make
```

**Why this specific command:** The `configure` script detects the `usb.h` header fine, but doesn't embed the library search path into the Makefile it generates. `LDFLAGS` tells the linker _where_ to find libraries (`-L` = library search path), and `LIBS="-lusb"` tells it _what_ to link against. Without this, `make` will compile everything successfully but fail at the linking stage with "Undefined symbols" errors for all the `usb_*` functions.

**Expected output:** You will see many `-Wpointer-sign` warnings during compilation. These are harmless — it's a 2004 codebase where `uint8_t*` and `char*` were used interchangeably. As long as `make` exits without `Error`, you're good.

### Step 4: Install the binary AND the shared library

The built binary depends on `libifp.4.dylib` at runtime. You must install both:

```bash
# Install the shared library
sudo cp src/.libs/libifp.4.dylib /usr/local/lib/
sudo ln -sf /usr/local/lib/libifp.4.dylib /usr/local/lib/libifp.dylib

# Install the CLI tool
sudo cp examples/.libs/ifpline /usr/local/bin/ifp
```

**Note:** The binary is at `examples/.libs/ifpline` (not `ifp` — the build names it `ifpline` internally). We rename it to `ifp` during install for convenience.

If you skip the `libifp.4.dylib` copy, you'll get this error when running `ifp`:

```
dyld[XXXX]: Library not loaded: /usr/local/lib/libifp.4.dylib
  Referenced from: /usr/local/bin/ifp
  Reason: tried: '/usr/local/lib/libifp.4.dylib' (no such file)
zsh: abort
```

### Step 5: Test

Plug in your IFP-180TC and run:

```bash
# List root directory
ifp ls /

# Check battery status
ifp battery

# Show device model
ifp typestring

# Show firmware version
ifp firmversion

# Check free space
ifp df
```

**Expected output:** You'll see a harmless warning line on every command:

```
wrn:  [ifp_delta] interesting, there were only 4 bytes.
Detected: model IFP-180TC, firmware 1.14, battery =[####], delta 1.0.0.0
```

This is normal — the IFP-180TC returns 4 bytes for an undocumented diagnostic value where the library expects 8. It does not affect functionality.

---

## Using the `ifp` CLI

### File Management

```bash
# List files on the player
ifp ls /

# Upload a song
ifp upload ~/Music/song.mp3 /

# Upload an entire folder
ifp upload ~/Music/playlist/ /playlist

# Download a file from the player
ifp download /song.mp3 ~/Downloads/song.mp3

# Delete a file
ifp rm /song.mp3

# Create a folder
ifp mkdir /Rock

# Delete a folder (recursive)
ifp rm -r /OldStuff
```

### Device Info

```bash
ifp battery        # Battery level (0-4)
ifp df             # Total and free space
ifp typestring     # Model number
ifp firmversion    # Firmware version
```

### Firmware Update (Use with Caution)

```bash
# Only if you have a .HEX firmware file
ifp firmupdate ./IFP-1XXTC.HEX
# DO NOT unplug or turn off during update!
```

---

## Troubleshooting

### "Permission denied" or "could not find device"

On macOS, you may need to allow the USB device access. Try:

```bash
sudo ifp ls /
```

If that works, create a launch daemon or use `sudo` each time. In practice, on recent macOS versions the device may work without `sudo` after the first successful `sudo` call in a session.

### Device not detected at all

1. Make sure the player shows "USB CONNECTED" on its LCD
2. Verify it appears in **System Information → USB** (you've confirmed this ✓)
3. Try a different USB port or cable
4. Try unplugging and re-plugging

### "Device isn't responding.. try jiggling the handle. (error 8)"

This means the USB connection is in a bad state. Common causes:

- A previous file transfer was interrupted (e.g., a download that failed mid-rename)
- The device was left in a locked state from a failed operation

**Fix:** Unplug the USB cable, wait a few seconds, plug it back in. If it still fails, power cycle the player itself (turn off → turn on) before reconnecting. This always resolves it.

### Download fails with "rename from .mp3 to .m3p failed" (error -17)

The iRiver protocol temporarily renames files during download (`.mp3` → `.m3p`) as a lock mechanism. Error `-17` is `EEXIST`, meaning a `.m3p` file with that name already exists — likely from a previous interrupted transfer.

**Fix:** Check `ifp ls /` for any leftover `.m3p` files and delete them with `ifp rm`, then retry the download. If the file has special characters in its name (see below), it may be easier to just delete and re-upload.

### Filenames with `!` or special characters (zsh escaping)

zsh treats `!` as a history expansion character. If a filename contains `!`, use **single quotes** instead of double quotes:

```bash
# WRONG — zsh will error with "event not found"
ifp rm "/iRiver, Catch the digital flow!.mp3"

# CORRECT — single quotes prevent zsh interpretation
ifp rm '/iRiver, Catch the digital flow!.mp3'
```

This applies to any `ifp` command where the filename contains `!`, `$`, backticks, or other shell-special characters.

### Linker errors: "Undefined symbols for architecture x86_64" (\_usb_bulk_read, \_usb_open, etc.)

This means `configure` found the `usb.h` header but didn't embed the library path into the Makefile. The fix:

```bash
make clean
LDFLAGS="-L$(brew --prefix libusb-compat)/lib" LIBS="-lusb" ./configure
make
```

Do NOT use `./configure --with-libusb-prefix=...` — this flag is recognized by the configure script but doesn't actually work properly on macOS.

### "Library not loaded: libifp.4.dylib" (dyld error)

You installed the `ifp` binary but forgot the shared library. Fix:

```bash
sudo cp src/.libs/libifp.4.dylib /usr/local/lib/
sudo ln -sf /usr/local/lib/libifp.4.dylib /usr/local/lib/libifp.dylib
```

### Build errors with newer Xcode/clang

If you get warnings-as-errors, try:

```bash
CFLAGS="-Wno-error" make
```

### macOS System Extension / Kernel Extension issues

`libifp` uses `libusb` in userspace — it does **not** require kernel extensions or system extensions. It should work without disabling SIP or any security settings.

---

## Post-Install: Cleanup

After a successful install, the source directory in Downloads is no longer needed. The important installed files are:

- `/usr/local/bin/ifp` — the CLI binary
- `/usr/local/lib/libifp.4.dylib` — the shared library
- `/usr/local/lib/libifp.dylib` — symlink to the above

You can safely delete `~/Downloads/libifp-1.0.1.0/` and `~/Downloads/libifp-1.0.1.0.tar.gz`. Do NOT delete anything in `/usr/local/`.

---

## Alternative: Python + PyUSB (Advanced)

If building libifp proves difficult, you could write a Python script using `pyusb` to talk to the device directly. This would require reverse-engineering the exact USB control transfer commands from the libifp source code. The key constants:

- **Vendor ID:** `0x4102`
- **Product ID:** `0x1001` (Manager Mode) / `0x1101` (UMS Mode)
- **Interface:** USB 1.1 Full Speed (12 Mb/s)
- **Protocol:** Proprietary control transfers over bulk endpoints

The libifp source (in the SourceForge Git repo) contains all the USB command sequences in `ifp_routines.c`. If you want to go this route and the C build doesn't work, let me know and I can help port the protocol to Python.

---

## Quick Reference Card

| Command                     | Description               |
| --------------------------- | ------------------------- |
| `ifp ls /`                  | List root directory       |
| `ifp ls /Music`             | List specific folder      |
| `ifp upload file.mp3 /`     | Upload file to root       |
| `ifp upload dir/ /dir`      | Upload directory          |
| `ifp download /file.mp3 ./` | Download file             |
| `ifp rm /file.mp3`          | Delete file               |
| `ifp rm -r /folder`         | Delete folder recursively |
| `ifp mkdir /NewFolder`      | Create folder             |
| `ifp df`                    | Show free space           |
| `ifp battery`               | Show battery level        |
| `ifp typestring`            | Show model number         |
| `ifp firmversion`           | Show firmware version     |

---

_Built from the [ifp-driver](https://ifp-driver.sourceforge.net/) open-source project (libifp 1.0.1.0)_
_Tested on macOS Sequoia (darwin25.4.0) with Xcode Command Line Tools, April 2026_

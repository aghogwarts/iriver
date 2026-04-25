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

If your player doesn't have this option, proceed to Option B.

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

`libusb-compat` provides the legacy `libusb-0.1` API that libifp expects.

### Step 2: Download and extract libifp

```bash
cd ~/Downloads
wget https://sourceforge.net/projects/ifp-driver/files/libifp/1.0.1.0-stable/libifp-1.0.1.0.tar.gz/download -O libifp-1.0.1.0.tar.gz
tar xzf libifp-1.0.1.0.tar.gz
cd libifp-1.0.1.0
```

### Step 3: Configure and build

The key is pointing the build at Homebrew's `libusb-compat` headers and libs:

```bash
# Find where Homebrew installed libusb-compat
LIBUSB_PREFIX=$(brew --prefix libusb-compat)

# Configure
./configure --with-libusb-prefix=$LIBUSB_PREFIX

# Build
make
```

**If `make` fails on the final link step** (a known macOS issue), manually link:

```bash
gcc -g -O2 -o ifp ifp-ifp.o ifp-ifp_routines.o ./libunicodehack.a \
    -liconv \
    $(brew --prefix libusb-compat)/lib/libusb.dylib
```

### Step 4: Install

```bash
sudo cp ifp /usr/local/bin/
# Or if you prefer ~/bin:
mkdir -p ~/bin && cp ifp ~/bin/
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
# Full device info string
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

If that works, create a launch daemon or use `sudo` each time.

### Device not detected at all

1. Make sure the player shows "USB CONNECTED" on its LCD
2. Verify it appears in **System Information → USB** (you've confirmed this ✓)
3. Try a different USB port or cable
4. Try unplugging and re-plugging

### Build errors with newer Xcode/clang

If you get warnings-as-errors, try:

```bash
CFLAGS="-Wno-error" make
```

### macOS System Extension / Kernel Extension issues

`libifp` uses `libusb` in userspace — it does **not** require kernel extensions or system extensions. It should work without disabling SIP or any security settings.

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

| Command | Description |
|---|---|
| `ifp ls /` | List root directory |
| `ifp ls /Music` | List specific folder |
| `ifp upload file.mp3 /` | Upload file to root |
| `ifp upload dir/ /dir` | Upload directory |
| `ifp download /file.mp3 ./` | Download file |
| `ifp rm /file.mp3` | Delete file |
| `ifp rm -r /folder` | Delete folder recursively |
| `ifp mkdir /NewFolder` | Create folder |
| `ifp df` | Show free space |
| `ifp battery` | Show battery level |
| `ifp typestring` | Show model number |
| `ifp firmversion` | Show firmware version |

---

*Built from the [ifp-driver](https://ifp-driver.sourceforge.net/) open-source project (libifp 1.0.1.0)*

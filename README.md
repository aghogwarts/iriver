# iRiver IFP-180TC macOS Driver

A working setup to manage the iRiver IFP-180TC (and other IFP-series players) on modern macOS, built from the open-source [ifp-driver](https://ifp-driver.sourceforge.net/) project.

These players use a proprietary USB protocol instead of USB Mass Storage, so they don't show up in Finder. This repo contains everything you need to compile the reverse-engineered driver and manage your device from the terminal — upload music, download files, check battery, and more.

## What's Inside

- **[Setup Guide](iriver-ifp-mac-setup.md)** — Step-by-step build and install instructions with tested troubleshooting for every error you'll likely hit on modern macOS (linker failures, dylib issues, zsh escaping, device lock-ups).

- **[Knowledge Guide](iriver-ifp-knowledge-guide.md)** — Deep dive into how everything works: USB protocols, reverse engineering, the autotools build system, shared libraries, the iRiver protocol internals, and shell concepts.

## Quick Start

```bash
brew install libusb libusb-compat wget

wget https://sourceforge.net/projects/ifp-driver/files/libifp/1.0.1.0-stable/libifp-1.0.1.0.tar.gz/download -O libifp-1.0.1.0.tar.gz
tar xzf libifp-1.0.1.0.tar.gz && cd libifp-1.0.1.0

LDFLAGS="-L$(brew --prefix libusb-compat)/lib" LIBS="-lusb" ./configure
make

sudo cp src/.libs/libifp.4.dylib /usr/local/lib/
sudo ln -sf /usr/local/lib/libifp.4.dylib /usr/local/lib/libifp.dylib
sudo cp examples/.libs/ifpline /usr/local/bin/ifp
```

Then plug in your player and:

```bash
ifp ls /           # list files
ifp upload song.mp3 /   # upload music
ifp df             # check free space
ifp battery        # battery status
```

## Compatibility

Tested on macOS Sequoia (darwin25.4.0) with an IFP-180TC. Should work with any IFP-series player in Manager Mode — the 1xx, 3xx, 5xx, 7xx, 8xx, 9xx, and N10 models all use the same protocol.

## Acknowledgments

Built on top of [libifp](https://ifp-driver.sourceforge.net/libifp/) by Geoff Oakham and the ifp-driver community, who reverse-engineered the iRiver protocol two decades ago. This repo just documents getting it running on modern macOS.

# Pony Finance Terminal

A small Pony terminal for public market quotes. It uses Pony `0.63.3`, Corral `0.9.2`, and Stooq's public quote CSV endpoint.

## Commands

```powershell
.\scripts\run-windows.ps1 watch
.\scripts\run-windows.ps1 quote AAPL MSFT NVDA
.\scripts\run-windows.ps1 source
```

Symbols without an exchange suffix default to Stooq `.us`, so `AAPL` becomes `aapl.us`.

## Windows Notes

Install and pin the current Pony tools:

```powershell
.\scripts\install-pony-windows.ps1
```

Build:

```powershell
.\scripts\build-windows.ps1
```

Windows Pony requires MSVC C++ Build Tools for linking. If `build-windows.ps1` reports that `link.exe` is missing, install Visual Studio Build Tools with `Desktop development with C++`.

## Tiny Core WSL2

This path imports Tiny Core 17.x x86_64 from the official `rootfs64.gz`, installs Pony inside the distro, builds the same source, and runs it:

```powershell
.\scripts\bootstrap-tinycore-wsl2.ps1 quote AAPL MSFT SPY
```

The first run creates a `TinyCorePony` WSL2 distro under `E:\wsl\TinyCorePony` and downloads the Linux Pony toolchain into `E:\toolchains\tinycore-wsl2`. It uses an existing WSL distro as a helper only to preserve Unix file permissions while creating the Tiny Core rootfs tar. To pick the helper explicitly:

```powershell
.\scripts\bootstrap-tinycore-wsl2.ps1 -HelperDistro TinyCore-Mojo quote AAPL
```

Recreate the distro:

```powershell
.\scripts\bootstrap-tinycore-wsl2.ps1 -Reimport watch
```

## Data Source

The app fetches one symbol at a time from:

```text
https://stooq.com/q/l/?s=aapl.us&f=sd2t2ohlcv&h&e=csv
```

Fields are symbol, date, time, open, high, low, close, and volume. This is informational market data, not investment advice.

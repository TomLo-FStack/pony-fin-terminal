# Contributing

Thanks for improving Pony Finance Terminal.

## Development

Install Pony `0.63.3`, then build:

```powershell
.\scripts\build-windows.ps1
```

Or use the Tiny Core WSL2 path:

```powershell
.\scripts\bootstrap-tinycore-wsl2.ps1 source
```

## Pull Requests

Keep changes small and focused. Include a short explanation of user-visible
behavior and the command you used to verify the change.

This project displays public market data only. Do not add features that ask
for brokerage credentials or execute trades.

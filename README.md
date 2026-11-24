# MC-challenge-HUB Client

ScopeCrystal shaderpack and Windows installer for the MC-challenge-HUB server (Minecraft Java 26.3).
Vanilla look in normal worlds, effects in the hub and arena.

**Download:** [full install](https://github.com/Jan-schweizer-99/MC-challenge-HUB-Client/releases/latest/download/MC-challenge-HUB-Client.zip) · [shader update](https://github.com/Jan-schweizer-99/MC-challenge-HUB-Client/releases/latest/download/ScopeCrystal-Shader.zip) · [install guide](install.txt)

No Minecraft files or third-party mods are included. The installer downloads the mods from their official
sources and builds two block-texture atlases from the player's own Minecraft.

Not an official Minecraft product. Not approved by or associated with Mojang or Microsoft.

## Publish a new version

Commit first, then:

```powershell
.\release.ps1 1.0.1 "What changed" -Publish
```

Without `-Publish` it only builds the ZIPs in `dist\`.

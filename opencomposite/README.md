# OpenComposite (VR without SteamVR)

`openvr_api.dll` lets Vivecraft talk to the OpenXR runtime of the headset (for the Quest 3: Meta Quest Link) instead
of SteamVR. Our Shader Menu mod carries these files, puts them into `.minecraft\opencomposite` at start and tells
LWJGL to load this DLL when VR starts. No other game and no system setting is touched.

## Source and license

OpenComposite is free software under the GNU GPL v3 (see `LICENSE.txt`), by ZNix and contributors.

- Upstream: https://gitlab.com/znixian/OpenOVR, branch `openxr`, commit `a27e7e6a64bdcd1eff6b7fba1ea2ea34bcf1273d`
- Our changes: `mc-hub-fixes.patch`
  - `BaseInput.cpp` `GetActionOrigins`: two-call idiom for `xrEnumerateBoundSourcesForAction`. With Meta Quest Link
    the fixed buffer of 20 was too small, so the game crashed when an action had overlapping bindings (B button,
    radial menu). Null or unreadable paths are skipped instead of aborting.
  - `DrvOpenXR.cpp`, `openvr_api.cpp`: without a headset (Quest not connected) the runtime answers
    `XR_ERROR_FORM_FACTOR_UNAVAILABLE`; OpenComposite aborted the whole game there. Now the init fails cleanly with
    `VRInitError_Init_HmdNotFound`, like SteamVR, and the game starts without VR (a later try works again).
  - `XrHMD.cpp`: missing `<chrono>` and `<thread>` includes for MSVC.

## Build

```
git clone --recursive https://gitlab.com/znixian/OpenOVR.git
cd OpenOVR
git checkout a27e7e6a64bdcd1eff6b7fba1ea2ea34bcf1273d
git submodule update --init --recursive
git apply ../mc-hub-fixes.patch
```

Extract `vulkan-minisdk.7z` (from the upstream readme) to `libs/vulkan`, then with Visual Studio 2022 (MSVC 14.44):

```
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release --target OCOVR
```

The result `build/bin/Release/vrclient_x64.dll` is `openvr_api.dll` here.

SHA-512 of the shipped DLL:
`192dbdb8c0be9bbaa71e25d22538c35709c4ab1b57c93047b170c18b89be43fd905e73b8f6b046720de834714d75ccb06f666fa6298cd03740fdfc416b46ec8d`

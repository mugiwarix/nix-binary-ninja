{
  lib,
  stdenv,
  callPackage,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  unzip,
  libGL,
  glib,
  fontconfig,
  xorg,
  dbus,
  libxkbcommon,
  wayland,
  kdePackages,
  python3,
  libxml2,
  auto-patchelf,

  binaryNinjaEdition ? "personal",
  forceWayland ? false,
  overrideSource ? null,
}:
let
  sources = callPackage ./sources.nix { };
  platformSources = sources.editions.${binaryNinjaEdition};
  source =
    if overrideSource != null then
      overrideSource
    else if builtins.hasAttr stdenv.hostPlatform.system platformSources then
      platformSources.${stdenv.hostPlatform.system}
    else
      throw "No source for system ${stdenv.hostPlatform.system}";
  desktopIcon = fetchurl {
    url = "https://docs.binary.ninja/img/logo.png";
    hash = "sha256-TzGAAefTknnOBj70IHe64D6VwRKqIDpL4+o9kTw0Mn4=";
  };
in
stdenv.mkDerivation {
  pname = "binary-ninja";
  inherit (sources) version;
  src = source;
  nativeBuildInputs = [
    makeWrapper
    auto-patchelf
    autoPatchelfHook
    python3.pkgs.wrapPython
    kdePackages.wrapQtAppsHook
    copyDesktopItems
  ];
  buildInputs = [
    unzip
    libGL
    glib
    fontconfig
    xorg.libXi
    xorg.libXrender
    xorg.xcbutilimage
    xorg.xcbutilrenderutil
    kdePackages.qtbase
    kdePackages.qtdeclarative
    libxkbcommon
    dbus
    wayland
    libxml2.out
  ];
  pythonDeps = [ python3.pkgs.pip ];
  appendRunpaths = [ "${lib.getLib python3}/lib" ];
  qtWrapperArgs = lib.optionals forceWayland [
    "--set"
    "QT_QPA_PLATFORM"
    "wayland"
  ];
  buildPhase = ":";

  desktopItems = [
    (makeDesktopItem {
      name = "Binary Ninja";
      exec = "binaryninja";
      icon = "binaryninja";
      desktopName = "Binary Ninja";
      comment = "Binary Ninja is an interactive decompiler, disassembler, debugger, and binary analysis platform built by reverse engineers, for reverse engineers";
      categories = [ "Development" ];
    })
  ];

  # libxml2 soname changes now follow ABI breaks.

  # https://gitlab.gnome.org/GNOME/libxml2/-/issues/751

  # This is of course ultimately good, but we can't recompile binja

  # So let's just force it to use whatever NixOS has. It's Probably Fine™

  preFixup = ''


    patchelf $out/opt/binaryninja/plugins/lldb/lib/liblldb.so.* \


      --replace-needed libxml2.so.2 libxml2.so


  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/opt
    mkdir -p $out/share/pixmaps
    cp -r * $out/opt
    cp ${desktopIcon} $out/share/pixmaps/binaryninja.png
    chmod +x $out/opt/binaryninja
    buildPythonPath "$pythonDeps"
    makeWrapper $out/opt/binaryninja $out/bin/binaryninja \
      --prefix PYTHONPATH : "$program_PYTHONPATH" \
      "''${qtWrapperArgs[@]}"

    runHook postInstall
  '';
  dontWrapQtApps = true;
  meta = {
    mainProgram = "binaryninja";
  };
}

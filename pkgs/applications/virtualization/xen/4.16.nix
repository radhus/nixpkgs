{ lib, callPackage, fetchurl, fetchpatch, fetchgit
, ocaml-ng
, withInternalQemu ? true
, withInternalTraditionalQemu ? false
, withInternalSeabios ? true
, withSeabios ? !withInternalSeabios, seabios
, withInternalOVMF ? false # FIXME: tricky to build
, withOVMF ? false, OVMF
, withLibHVM ? false

# xen
, python3Packages

# qemu
, udev, pciutils, xorg, SDL, pixman, acl, glusterfs, spice-protocol, usbredir
, alsa-lib, glib, python3, ninja, meson
, ... } @ args:

assert withInternalSeabios -> !withSeabios;
assert withInternalOVMF -> !withOVMF;
assert !withLibHVM;

with lib;

# Patching XEN? Check the XSAs at
# https://xenbits.xen.org/xsa/
# and try applying all the ones we don't have yet.

let
  xsa = import ./xsa-patches.nix { inherit fetchpatch; };

  qemuMemfdBuildFix = fetchpatch {
    name = "xen-4.8-memfd-build-fix.patch";
    url = "https://github.com/qemu/qemu/commit/75e5b70e6b5dcc4f2219992d7cffa462aa406af0.patch";
    sha256 = "0gaz93kb33qc0jx6iphvny0yrd17i8zhcl3a9ky5ylc2idz0wiwa";
  };

  qemuDeps = [
    udev pciutils xorg.libX11 SDL pixman acl glusterfs spice-protocol usbredir
    alsa-lib glib python3 ninja meson
  ];
in

callPackage (import ./generic.nix (rec {
  version = "4.16.2";

  src = fetchurl {
    url = "https://downloads.xenproject.org/release/xen/${version}/xen-${version}.tar.gz";
    sha256 = "1dqjd2jscq68l99mglsx1pwxjgl3nyxvs0fasj002chcv2wwwx1a";
  };

  # Sources needed to build tools and firmwares.
  xenfiles = optionalAttrs withInternalQemu {
    qemu-xen = {
      src = fetchgit {
        url = "https://xenbits.xen.org/git-http/qemu-xen.git";
        # rev = "refs/tags/qemu-xen-${version}";
        # use revision hash - reproducible but must be updated with each new version
        rev = "107951211a8d17658e1aaa0c23a8cf29f8806ad8";
        sha256 = "1k4vvk546qkrisqrkhzyf7h9cqfdr8w5qsml7llgj34xcaq9ddva";
      };
      buildInputs = qemuDeps;
      postPatch = ''
        # needed in build but /usr/bin/env is not available in sandbox
        substituteInPlace scripts/tracetool.py \
          --replace "/usr/bin/env python" "${python3}/bin/python"
      '';
      meta.description = "Xen's fork of upstream Qemu";
    };
  } // optionalAttrs withInternalTraditionalQemu {
    # TODO 4.15: something happened with traditional in this release?
    qemu-xen-traditional = {
      src = fetchgit {
        url = "https://xenbits.xen.org/git-http/qemu-xen-traditional.git";
        # rev = "refs/tags/xen-${version}";
        # use revision hash - reproducible but must be updated with each new version
        rev = "3d273dd05e51e5a1ffba3d98c7437ee84e8f8764";
        sha256 = "1dc6dhjp4y2irmi9yiyw1kzmm1habyy8j1s2zkf6qyak850krqj7";
      };
      buildInputs = qemuDeps;
      patches = [
      ];
      postPatch = ''
        substituteInPlace xen-hooks.mak \
          --replace /usr/include/pci ${pciutils}/include/pci
      '';
      meta.description = "Xen's fork of upstream Qemu that uses old device model";
    };
  } // optionalAttrs withInternalSeabios {
    "firmware/seabios-dir-remote" = {
      src = fetchgit {
        url = "https://xenbits.xen.org/git-http/seabios.git";
        rev = "155821a1990b6de78dde5f98fa5ab90e802021e0";
        sha256 = "0jp4rxsv9jdzvx4gjvkybj6g1yjg8pkd2wys4sdh6c029npp6y8p";
      };
      patches = [ ./0000-qemu-seabios-enable-ATA_DMA.patch ];
      meta.description = "Xen's fork of Seabios";
    };
  } // optionalAttrs withInternalOVMF {
    "firmware/ovmf-dir-remote" = {
      src = fetchgit {
        url = "https://xenbits.xen.org/git-http/ovmf.git";
        rev = "7b4a99be8a39c12d3a7fc4b8db9f0eab4ac688d5";
        sha256 = "0zsdmdp7xqq80jd4cmw59dp7axd85lkhq8lddshlmcm5z5acfcid";
      };
      meta.description = "Xen's fork of OVMF";
    };
  } // {
    # TODO: patch Xen to make this optional?
    "firmware/etherboot/ipxe.git" = {
      src = fetchgit {
        url = "https://git.ipxe.org/ipxe.git";
        rev = "3c040ad387099483102708bb1839110bc788cefb";
        sha256 = "1cmh5grj7zyg5iiqpbsjqslniibb2730zvxsiq86bc0699j1sr6b";
      };
      meta.description = "Xen's fork of iPXE";
    };
  };

  configureFlags = []
    ++ optional (!withInternalQemu) "--with-system-qemu" # use qemu from PATH
    ++ optional (withInternalTraditionalQemu) "--enable-qemu-traditional"
    ++ optional (!withInternalTraditionalQemu) "--disable-qemu-traditional"

    ++ optional (withSeabios) "--with-system-seabios=${seabios}"
    ++ optional (!withInternalSeabios && !withSeabios) "--disable-seabios"

    ++ optional (withOVMF) "--with-system-ovmf=${OVMF.fd}/FV/OVMF.fd"
    ++ optional (withInternalOVMF) "--enable-ovmf";

  NIX_CFLAGS_COMPILE = toString [
    # TODO 4.15: drop unneeded ones
    # Fix build on Glibc 2.24.
    "-Wno-error=deprecated-declarations"
    # Fix build with GCC 8
    "-Wno-error=maybe-uninitialized"
    "-Wno-error=stringop-truncation"
    "-Wno-error=format-truncation"
    "-Wno-error=array-bounds"
    # Fix build with GCC 9
    "-Wno-error=address-of-packed-member"
    "-Wno-error=format-overflow"
    "-Wno-error=absolute-value"
    # Fix build with GCC 10
    "-Wno-error=enum-conversion"
    "-Wno-error=zero-length-bounds"
  ];

  patches = with xsa; flatten [
    ./0000-fix-ipxe-src.4.16.patch
    ./0000-fix-install-python.4.16.patch
    ./0004-makefile-use-efi-ld.4.16.patch
    ./0005-makefile-fix-efi-mountdir-use.4.16.patch

    # XSA_409 # patches don't apply, but only relevant for ARM
    XSA_410
    XSA_411
  ];

  postPatch = ''
    # Avoid a glibc >= 2.25 deprecation warnings that get fatal via -Werror.
    sed 1i'#include <sys/sysmacros.h>' \
      -i tools/libs/light/libxl_device.c

    # Fix missing pkg-config dir
    mkdir -p tools/pkg-config
  '';

  preBuild = ''
    # PKG_CONFIG env var collides with variables used in tools Makefiles.
    unset PKG_CONFIG
  '';

  passthru = {
    qemu-system-i386 = if withInternalQemu
      then "lib/xen/bin/qemu-system-i386"
      else throw "this xen has no qemu builtin";
  };

})) ({
  ocamlPackages = ocaml-ng.ocamlPackages_4_05;
  pythonXPackages = python3Packages;
} // args)

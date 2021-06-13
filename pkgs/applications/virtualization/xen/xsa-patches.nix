{ fetchpatch }:

let
  xsaPatch = { patchFile, sha256 }: (fetchpatch {
    url = "https://xenbits.xen.org/xsa/${patchFile}";
    inherit sha256;
  });
in {
  XSA_372 = [
    (xsaPatch {
      patchFile = "xsa372-4.15/0001-xen-arm-Create-dom0less-domUs-earlier.patch";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    })
    (xsaPatch {
      patchFile = "xsa372-4.15/0002-xen-arm-Boot-modules-should-always-be-scrubbed-if-bo.patch";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    })
  ];

  XSA_373 = [
    (xsaPatch {
      patchFile = "xsa373/xsa373-4.15-1.patch";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    })
    (xsaPatch {
      patchFile = "xsa373/xsa373-4.15-2.patch";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    })
    (xsaPatch {
      patchFile = "xsa373/xsa373-4.15-3.patch";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    })
    (xsaPatch {
      patchFile = "xsa373/xsa373-4.15-4.patch";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    })
    (xsaPatch {
      patchFile = "xsa373/xsa373-4.15-5.patch";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    })
  ];

  XSA_375 = (xsaPatch {
    patchFile = "xsa375.patch";
    sha256 = "0000000000000000000000000000000000000000000000000000";
  });

  XSA_377 = (xsaPatch {
    patchFile = "xsa377.patch";
    sha256 = "0000000000000000000000000000000000000000000000000000";
  });
}

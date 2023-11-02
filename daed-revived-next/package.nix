{ mkPnpmPackage
, clang
, buildGoModule
, fetchFromGitHub
}:

let
  dist = mkPnpmPackage {
    src = fetchFromGitHub {
      owner = "daeuniverse";
      repo = "daed-revived-next";
      fetchSubmodules = true;
      rev = "5597f9ab533b3c11403e7cde612e35be688ea54c";
      hash = "sha256-KRDllndl83+LNbpm+xJUOeH5c+ioXmwotDJmOqXE6eM=";
    };
  };

  dae-ebpf = buildGoModule rec {
    pname = "dae";
    version = "ebpf";

    src = fetchFromGitHub {
      owner = "daeuniverse";
      repo = pname;
      rev = "92596cd01e1b90e92b51a2f5dea867010ced6dbe";
      hash = "sha256-DY32iX8o4cd/c6IJt+oEYzD8kpocn/Tl5lU15PcoE6M=";
      fetchSubmodules = true;
    };

    vendorHash = "sha256-rZwK+mYWJqgLFhzwZTfCC4tIg2gtNtx7Lu/fyOL3ozA=";

    proxyVendor = true;

    nativeBuildInputs = [ clang ];

    buildPhase = ''
      make CFLAGS="-D__REMOVE_BPF_PRINTK -fno-stack-protector -Wno-unused-command-line-argument" \
      NOSTRIP=y \
      ebpf
    '';
    installPhase = ''
      mkdir $out
      cp -r ./* $out
    '';

    # network required
    doCheck = false;
  };


in
buildGoModule rec {
  name = "daed";
  version = "unstable-2023-08-22";

  src = fetchFromGitHub {
    owner = "daeuniverse";
    repo = "dae-wing";
    rev = "bcfba3a71bd1bd55a690a38d5efcd2a31ef43001";
    hash = "sha256-LzHXdm98Ny/UFIasPGD08YD/mEX6MRtwFUnk44hnpbU=";
  };

  vendorHash = "sha256-IGORrj9br8fQyu2m23ukCNFR8M5EHW6spR18B+eowtw=";
  proxyVendor = true;
  preBuild = ''
    # replace built dae ebpf bindings
    rm -r ./dae-core
    cp -r ${dae-ebpf} ./dae-core

    cp -r ${dist} ./webrender/web

    substituteInPlace Makefile \
      --replace /bin/bash "/bin/sh" \

    chmod -R 777 webrender

    go generate ./...

    find webrender/web -type f -size +4k ! -name "*.gz" ! -name "*.woff" ! -name "*.woff2" -exec sh -c "
        echo '{}';
        gzip -9 -k '{}';
        if [ \$(stat -c %s '{}') -lt \$(stat -c %s '{}.gz') ]; then
            rm '{}.gz';
        else
            rm '{}';
        fi
    " ';'
  '';

  tags = [ "embedallowed" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/daeuniverse/dae-wing/db.AppVersion=${version}"
    "-X github.com/daeuniverse/dae-wing/db.AppName=${name}"
  ];

  excludedPackages = [ "dae-core" ];

  postInstall = ''
    mv $out/bin/dae-wing $out/bin/daed
    rm $out/bin/{input,resolver}
  '';
}

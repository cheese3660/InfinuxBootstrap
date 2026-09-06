{
  description = "Minimal static environment with Musl-GCC, BusyBox, and Linux Kernel Headers";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      
      # Target kernel version for the headers
      kernelVersion = "6.6";

      # Cross-compilation pkgs set targeting musl (statically linked output by default)
      pkgsMusl = import nixpkgs {
        inherit system;
        crossSystem = {
          config = "x86_64-unknown-linux-musl";
        };
      };

      # Native pkgs set for host-side tooling
      pkgs = import nixpkgs { inherit system; };

      # 1. Custom Linux Headers package for the specified version
      customLinuxHeaders = pkgsMusl.linuxHeaders.overrideAttrs (oldAttrs: rec {
        version = kernelVersion;
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          # Update or calculate hash when changing major/minor versions
          hash = "sha256-D3x3mX9eC1W8L7B1X9m5n8V1k2J3H4g5F6e7D8c9B0A="; 
        };
      });

      # 2. Package that creates the merged output directory
      sysrootEnv = pkgs.stdenv.mkDerivation {
        name = "custom-musl-sysroot";

        # Pull static GCC toolchain, static busybox, and custom kernel headers
        buildInputs = [
          pkgsMusl.stdenv.cc
          pkgsMusl.busybox-sandbox # Statically built busybox
          customLinuxHeaders
        ];

        buildCommand = ''
          mkdir -p $out/{bin,include,lib}

          # Symlink static Musl GCC toolchain and libraries
          cp -rs ${pkgsMusl.stdenv.cc}/bin/* $out/bin/
          cp -rs ${pkgsMusl.musl}/include/* $out/include/
          cp -rs ${pkgsMusl.musl}/lib/* $out/lib/

          # Add Linux Kernel Headers into include/
          cp -rs ${customLinuxHeaders}/include/* $out/include/

          # Add static BusyBox binary and populate standard symlinks
          cp ${pkgsMusl.busybox-sandbox}/bin/busybox $out/bin/busybox
          chmod +x $out/bin/busybox
          
          # Populate common busybox utils as symlinks inside bin/
          for applet in $(${pkgsMusl.busybox-sandbox}/bin/busybox --list); do
            ln -sf busybox $out/bin/$applet
          done
        '';
      };
    in
    {
      packages.${system} = {
        default = sysrootEnv;
      };

      apps.${system}.default = {
        type = "app";
        program = "${pkgs.writeShellScript "build-folder" ''
          DEST=''${1:-./sysroot}
          echo "Populating static toolchain folder at $DEST..."
          mkdir -p "$DEST"
          cp -rL ${sysrootEnv}/* "$DEST/"
          chmod -R +w "$DEST"
          echo "Done! Target directory ready."
        ''}";
      };
    };
}
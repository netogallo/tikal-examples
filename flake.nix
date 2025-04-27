{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    utils.url = "github:numtide/flake-utils";    
  };

  outputs = { self, nixpkgs, utils }:
    let
      inherit (utils.lib) eachDefaultSystem;
      dummy-config = { pkgs, ...}: {
        imports = [ "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix" ];
        boot.loader.grub.enable = false;
        #services.getty.autoLogin.enable = true;
		    #services.getty.autoLogin.user = "nixos";

		    users.users.nixos = {
			    isNormalUser = true;
			    password = "nixos";
        };

        environment.systemPackages = with pkgs; [ vim git curl ];

		    networking.useDHCP = true;
		    system.stateVersion = "24.05";
      };

      flake = system:
        let
          pkgs = import nixpkgs { inherit system; };
          nixos-system = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [ dummy-config ];
          };
          run' = pkgs.writeScript "nixos" ''
            ${pkgs.qemu}/bin/qemu-x86_64 \
              -m 1024
              -enable-kvm \
              -drive file=${nixos-system.config.system.build.images.qemu},model=virtio \
              -cpu host
          '';
        in
          {
            apps = {
              dummy = {
                type = "app";
                program = "${nixos-system.config.system.build.vm}/bin/run-nixos-vm";
              };
            };
            packages = {
              inherit nixos-system;
            };
          }
      ;
    in
      eachDefaultSystem flake
  ;
}

{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    utils.url = "github:numtide/flake-utils";    
    tikal-flake.url = "git+file:tikal";
  };

  outputs = { self, nixpkgs, utils, tikal-flake }:
    let
      inherit (utils.lib) eachDefaultSystem;
      basic-config = { pkgs, ...}: {
        imports = [ "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix" ];
        boot.loader.grub.enable = false;

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
          tikal = tikal-flake.lib.${system};
          pkgs = import nixpkgs { inherit system; };
          nixos-system = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [ basic-config ];
          };
          example1 =
            tikal.universe
            ./example1/universe.nix
            {
              # base-dir is always a relative directory to the location
              # where the flake is being run (ie. nix run .#sync). Therefore
              # it must not be a path (ie. ./my-base-dir) as, in the case of flakes,
              # that will point to a readonly directory in the store.
              base-dir = "example1";

              # The root directory of the flake. Sould always be ./.
              flake-root = ./.;
            };
          example1-server =
            nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                basic-config
                example1.nixosModules.server
              ];
            }
          ;
        in
          {
            inherit nixpkgs;
            apps = {
              basic = {
                type = "app";
                program = "${nixos-system.config.system.build.vm}/bin/run-nixos-vm";
              };
              example1 =
                example1.apps //
                {
                  "server" = {
                    type = "app";
                    program = "${example1-server.config.system.build.vm}/bin/run-nixos-vm";
                  };
                }
              ;
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

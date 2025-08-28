{
  description = "A very basic flake";

  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    utils.url = "github:numtide/flake-utils";    
    #tikal-flake.url = "git+file:tikal?submodule=1";
    tikal-flake.url = ./tikal;
  };

  outputs = { self, nixpkgs, utils, tikal-flake }:
    let
      inherit (utils.lib) eachDefaultSystem;
      basic-config = { pkgs, ...}: {
        #imports = [ "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix" ];
        imports = [ "${tikal-flake}/modules/virtualization/tikal-qemu.nix" ];
        boot.loader.grub.enable = false;

        security.sudo.enable = true;

		    users.users.nixos = {
			    isNormalUser = true;
			    password = "nixos";
          extraGroups = [ "wheel" ];
        };

        environment.systemPackages =
          with pkgs;
          [ vim git curl
            netcat
          ]
        ;

		    networking.useDHCP = true;
		    system.stateVersion = "25.05";
      };

      flake = system:
        let
          tikal = (tikal-flake.override { log-level = 7; }).lib.${system};
          pkgs = import nixpkgs { inherit system; };
          nixos-system = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [ basic-config ];
          };
          example1 =

            # The universe function takes as an argument a tikal module and
            # has two main products:
            # 1. A set of nixos modules that can then be used to define
            #    nixos systems. Each of this modules is referred in Tikal
            #    as a "nahual". The word comes from ancient Mayan mythology
            #    where "nahuales" were supernatural shape-shifters.
            # 2. A "sync" script. This script is meant to be called before
            #    building the nixos systems defined by the nahuales.
            #    The purpose of this script is to safely generate secrets
            #    that are to be included in the nixos system but are not
            #    to be exposed in the nix store. This includes things like
            #    ssh keys private keys.
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
                {
                  config.system.name = "tikal-server";
                }
              ];
            }
          ;
          example1-client =
            nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                basic-config
                example1.nixosModules.client
                {
                  config.system.name = "tikal-client";
                }
              ];
            }
          ;
        in
          {
            inherit nixpkgs;
            apps = {
              example1 =
                example1.apps //
                {
                  "server" = {
                    type = "app";
                    #program = "${example1-server.config.system.build.vm}/bin/run-tikal-server-vm";
                    program = "${example1-server.config.system.build.tikal.vm.qemu}/bin/run-qemu";
                  };
                  "client" = {
                    type = "app";
                    program = "${example1-client.config.system.build.vm}/bin/run-tikal-client-vm";
                  };
                }
              ;
            };

            packages = {
              inherit nixos-system;
              inherit (tikal) tikal;
              example1 = {
                server = example1-server;
                client = example1-client;
              };
            };
          }
      ;
    in
      eachDefaultSystem flake
  ;
}

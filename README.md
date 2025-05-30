# Apollo nix flake
Nix flake for https://github.com/ClassicOldSong/Apollo.

## Disclaimer
This is the first flake I'm building. It might not be complete. Following the Usage section you should be able to get Apollo up and running.

## Usage
To include the flake, follow the instructions [Using nix flakes with NixOS](https://nixos.wiki/wiki/flakes#Using_nix_flakes_with_NixOS). After including the flake I added this to my modules in flake.nix:
```nix
    modules = [
      # configuration.nix
      # Apollo
      (inputs.apollo-flake.nixosModules.${linuxPkgsUnstable.system}.default)
      ({pkgs, ...}: {
        services.apollo.package = apollo-flake.packages.${pkgs.system}.default;
      })
    ];
```

And in my `configuration.nix`:
```nix
  # Enable self-hosted game streaming
  services.apollo = {
    enable = true;
    capSysAdmin = true;
    openFirewall = true;
    applications = {
      apps = [
        {
          name = "TV";
          prep-cmd = [
            {
              do = ''
              ${pkgs.hyprland}/bin/hyprctl keyword monitor DP-2,3840x2160@60,0x0,1
              '';
              undo = ''
                ${pkgs.hyprland}/bin/hyprctl keyword monitor DP-2,5120x1440@240,0x0,1
              '';
            }
          ];
          exclude-global-prep-cmd = "false";
          auto-detach = "true";
        }
      ];
    };
  };
```

After `nixos-rebuild` the service should be started. Verify with `systemctl --user status apollo` or start it with `systemctl --user start apollo.service`

## Credits
I made some small modifications to the Sunshine package from nixpkgs (https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/su/sunshine/package.nix). The people maintaining that package put in the hard work to make the package work for Sunshine.

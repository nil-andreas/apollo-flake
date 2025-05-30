# Apollo nix flake
Nix flake for https://github.com/ClassicOldSong/Apollo.

## Disclaimer
This is the first flake I'm building. It is not complete. Following the Usage section you should be able to get Apollo up and running with default settings (currently using the sunshine command).

## Usage
To include the flake, follow the instructions [Using nix flakes with NixOS](https://nixos.wiki/wiki/flakes#Using_nix_flakes_with_NixOS). After including the flake I added this to my `configuration.nix`:

```nix
  environment.systemPackages = with pkgs; [
    apollo-flake.packages.${pkgs.system}.default
  ];
```

After `nixos-rebuild` the command `sunshine` is available.

## Credits
I made some small modifications to the Sunshine package from nixpkgs (https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/su/sunshine/package.nix). The people maintaining that package put in the hard work to make the package work for Sunshine.

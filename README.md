# Nix Flake for Unitree SDK2

A Nix flake providing the [Unitree SDK2](https://github.com/unitreerobotics/unitree_sdk2) (C++17, DDS-based) for controlling Unitree robots (Go2, B2, H1, G1, etc.).

Linux only (`x86_64-linux` and `aarch64-linux`) — no macOS binaries are provided upstream.

## Install to your profile

```sh
nix profile install github:jeff-hykin/nix_unitree
```

This installs the SDK headers, `libunitree_sdk2.a`, and CMake config files.

## Use in your own flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    unitree.url = "github:jeff-hykin/nix_unitree";
  };

  outputs = { nixpkgs, unitree, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      unitree_sdk2 = unitree.packages.${system}.default;
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [ unitree_sdk2 pkgs.cmake ];
      };
    };
}
```

Then in your CMakeLists.txt:

```cmake
find_package(unitree_sdk2 REQUIRED)
target_link_libraries(my_target PRIVATE unitree_sdk2)
```

## Dev shell

```sh
nix develop github:jeff-hykin/nix_unitree
```

Drops you into a shell with the SDK, cmake, pkg-config, and CycloneDDS available.

## Links

- [Unitree SDK2 on GitHub](https://github.com/unitreerobotics/unitree_sdk2)
- [Unitree Robotics](https://www.unitree.com/)

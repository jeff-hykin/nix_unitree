{
  description = "Nix flake for Unitree SDK2 (prebuilt, Linux only)";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
    lib.url          = "github:jeff-hykin/quick-nix-toolkits";
    lib.inputs.flakeUtils.follows = "flake-utils";

    unitree_sdk2_src = {
      url   = "github:unitreerobotics/unitree_sdk2/2.0.2";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, lib, unitree_sdk2_src, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        aggregation = lib.aggregator [
          # Build tools (nativeBuildInputs)
          { vals.pkg = pkgs.cmake;           flags.nativeBuild = true; }
          # SDK dependencies (buildInputs)
          { vals.pkg = pkgs.cyclonedds;      flags = { buildInput = true; ldLibraryGroup = true; }; }
          { vals.pkg = pkgs.cyclonedds-cxx;  flags = { buildInput = true; ldLibraryGroup = true; }; }
          # Dev shell extras
          { vals.pkg = pkgs.bashInteractive; flags = {}; }
          { vals.pkg = pkgs.pkg-config;      flags = {}; }
          { vals.pkg = pkgs.git;             flags = {}; }
        ];

        nativeBuildPkgs   = aggregation.getAll { hasAllFlags = [ "nativeBuild" ]; attrPath = [ "pkg" ]; };
        buildInputPkgs    = aggregation.getAll { hasAllFlags = [ "buildInput" ];   attrPath = [ "pkg" ]; };
        devPackages       = aggregation.getAll { attrPath = [ "pkg" ]; };
        ldLibraryPackages = aggregation.getAll { hasAllFlags = [ "ldLibraryGroup" ]; attrPath = [ "pkg" ]; };

        unitree_sdk2 = pkgs.stdenv.mkDerivation {
          pname   = "unitree_sdk2";
          version = "2.0.2";
          src     = unitree_sdk2_src;

          nativeBuildInputs = nativeBuildPkgs;
          buildInputs       = buildInputPkgs;

          # Patch CMake to:
          # 1. Use nixpkgs CycloneDDS instead of vendored .so files
          # 2. Fix the typo in unitree_sdk2Targets.cmake (ddsxcxx -> ddscxx)
          postPatch = ''
            # Replace thirdparty/CMakeLists.txt to use system CycloneDDS
            cat > thirdparty/CMakeLists.txt << 'THIRDPARTY_EOF'
            find_package(CycloneDDS REQUIRED)
            find_package(CycloneDDS-CXX REQUIRED)
            find_package(Threads REQUIRED)

            # Create alias targets matching what the SDK expects
            if(NOT TARGET ddsc)
              add_library(ddsc ALIAS CycloneDDS::ddsc)
            endif()
            if(NOT TARGET ddscxx)
              add_library(ddscxx ALIAS CycloneDDS-CXX::ddscxx)
            endif()
            THIRDPARTY_EOF

            # Fix the installed Targets file: ddsxcxx -> ddscxx, and use system libs
            cat > cmake/unitree_sdk2Targets.cmake << 'TARGETS_EOF'
            cmake_policy(PUSH)
            cmake_policy(VERSION 3.5)
            set(CMAKE_IMPORT_FILE_VERSION 1)

            get_filename_component(_IMPORT_PREFIX "''${CMAKE_CURRENT_LIST_FILE}" PATH)
            get_filename_component(_IMPORT_PREFIX "''${_IMPORT_PREFIX}" PATH)
            get_filename_component(_IMPORT_PREFIX "''${_IMPORT_PREFIX}" PATH)
            get_filename_component(_IMPORT_PREFIX "''${_IMPORT_PREFIX}" PATH)

            find_package(CycloneDDS REQUIRED)
            find_package(CycloneDDS-CXX REQUIRED)
            find_package(Threads REQUIRED)

            add_library(unitree_sdk2 STATIC IMPORTED GLOBAL)
            set_target_properties(unitree_sdk2 PROPERTIES
                IMPORTED_LOCATION "''${_IMPORT_PREFIX}/lib/libunitree_sdk2.a"
                INTERFACE_INCLUDE_DIRECTORIES "''${_IMPORT_PREFIX}/include"
                INTERFACE_LINK_LIBRARIES "CycloneDDS::ddsc;CycloneDDS-CXX::ddscxx;Threads::Threads"
                LINKER_LANGUAGE CXX)

            set(CMAKE_IMPORT_FILE_VERSION)
            cmake_policy(POP)
            TARGETS_EOF

            # Update Config.cmake.in to find CycloneDDS dependencies
            cat > cmake/unitree_sdk2Config.cmake.in << 'CONFIG_EOF'
            include(CMakeFindDependencyMacro)
            find_dependency(Threads REQUIRED)
            find_dependency(CycloneDDS REQUIRED)
            find_dependency(CycloneDDS-CXX REQUIRED)
            include("''${CMAKE_CURRENT_LIST_DIR}/unitree_sdk2Targets.cmake")
            CONFIG_EOF
          '';

          cmakeFlags = [
            "-DBUILD_EXAMPLES=OFF"
          ];

          meta = with pkgs.lib; {
            description = "Unitree SDK2 for robot control via DDS";
            homepage    = "https://github.com/unitreerobotics/unitree_sdk2";
            license     = licenses.bsd3;
            platforms   = [ "x86_64-linux" "aarch64-linux" ];
          };
        };

      in {
        packages.default = unitree_sdk2;

        devShells.default = pkgs.mkShell {
          buildInputs = devPackages ++ [ unitree_sdk2 ];
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath ldLibraryPackages;
          shellHook = ''
            echo "Unitree SDK2 dev shell"
            echo "  unitree_sdk2: ${unitree_sdk2}"
          '';
        };
      }
    );
}

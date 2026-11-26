{
  description = "staking-rewards development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.just
              pkgs.jq
              pkgs.z3
              pkgs.lcov
              pkgs.slither-analyzer
            ];

            shellHook = ''
              echo "staking-rewards: using local Foundry from PATH."
              echo "Run 'just doctor' to inspect the toolchain; 'just' lists recipes."
            '';
          };
        }
      );
    };
}

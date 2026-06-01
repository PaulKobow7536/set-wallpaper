{
  description = "Wallhaven wallpaper fetcher service";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    {
      homeManagerModules.wallpaper =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.wallpaper;

          wallpaperScript = pkgs.writeShellScriptBin "get-wallpaper" ''
            set -eo pipefail
            set -x
            time=$(date +%s)
            wallpaper_path="$HOME/.wallpaper"
            mkdir -p "$wallpaper_path"

            echo "Fetching wallpaper from wallhaven..."

            tag=$(echo "${lib.concatStringsSep "\n" cfg.tags}" | shuf | head -n 1)

            img_url=$(${pkgs.curl}/bin/curl -sf \
              "https://wallhaven.cc/api/v1/search?categories=${cfg.categories}&purity=${cfg.purity}&atleast=${cfg.minResolution}&sorting=random&ratios=${cfg.ratios}&q=$tag" \
              | ${pkgs.jq}/bin/jq -r 'if (.data | length) > 0 then .data[0].path else error("no results") end')

            echo "Downloading: $img_url"
            ext="''${img_url##*.}"
            tmp="/tmp/$time.$ext"

            ${pkgs.wget}/bin/wget -q -O "$tmp" "$img_url"


            hash=$(${pkgs.coreutils}/bin/sha256sum "$tmp" | cut -d " " -f 1)

            if [[ -f "$wallpaper_path/$hash.$ext" ]]; then
              echo "Already have this wallpaper, skipping"
              rm "$tmp"
              exit 0
            fi

            mv "$tmp" "$wallpaper_path/$hash.$ext"
            echo "Setting wallpaper..."
            ${cfg.setWallpaperCmd} "$wallpaper_path/$hash.$ext"
            echo "Done"
          '';
        in
        {
          options.services.wallpaper = {
            enable = lib.mkEnableOption "Wallhaven wallpaper fetcher";

            setWallpaperCmd = lib.mkOption {
              type = lib.types.str;
              example = "\${pkgs.feh}/bin/feh --bg-scale";
              description = "Command to set the wallpaper. The image path will be appended as the last argument.";
            };

            minResolution = lib.mkOption {
              type = lib.types.str;
              default = "1920x1080";
              description = "Minimum resolution filter (wallhaven atleast parameter)";
            };

            ratios = lib.mkOption {
              type = lib.types.str;
              default = "16x9";
              description = "Aspect ratio filter (wallhaven ratios parameter)";
            };

            categories = lib.mkOption {
              type = lib.types.str;
              default = "100";
              description = "Wallhaven categories bitmask: general/anime/people (e.g. '100' = general only, '111' = all)";
            };

            purity = lib.mkOption {
              type = lib.types.str;
              default = "100";
              description = "Wallhaven purity bitmask: sfw/sketchy/nsfw (e.g. '100' = sfw only)";
            };

            tags = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "nature"
                "cars"
                "abstract"
                "linux"
              ];
              description = "List of tags to filter wallpapers by";
            };

            interval = lib.mkOption {
              type = lib.types.str;
              default = "1h";
              description = "How often to fetch a new wallpaper (systemd OnUnitActiveSec format)";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ wallpaperScript ];

            systemd.user.services.wallpaper = {
              Unit = {
                Description = "Fetch and set random wallpaper from wallhaven";
                After = [ "network-online.target" ];
              };
              Service = {
                Type = "oneshot";
                ExecStart = "${wallpaperScript}/bin/get-wallpaper";
                Restart = "on-failure";
                RestartSec = "30s";
              };
            };

            systemd.user.timers.wallpaper = {
              Unit.Description = "Timer for wallpaper fetcher";
              Timer = {
                OnBootSec = "30s";
                OnUnitActiveSec = cfg.interval;
                Unit = "wallpaper.service";
              };
              Install.WantedBy = [ "timers.target" ];
            };
          };
        };
    };
}

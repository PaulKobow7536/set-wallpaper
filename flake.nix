{
  description = "Reddit wallpaper fetcher service";

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
            set -e
            time=$(date +%s)
            tries=0
            wallpaper_path="$HOME/.wallpaper"

            mkdir -p "$wallpaper_path"

            addJpegIfImgur(){
              while read url; do
                isImgur=$(echo "$url" | grep imgur)
                url=$(echo "$url" | sed -e 's/"url": "//' -e 's/",//' -e 's/gallery\///')
                [[ -z "$isImgur" ]] && echo "$url" || echo "$url" | sed -e 's/$/\.jpg/'
              done
            }

            startOver(){
              [[ -z "$1" ]] && echo "error" || echo "$1"
              rm "$wallpaper_path/$time.jpg" 2>/dev/null
              sleep 1
              getWallpaper "retry"
            }

            setWallpaper(){
              echo "Setting wallpaper..."
              ${cfg.setWallpaperCmd} "$1"
            }

            getWallpaper(){
              if [[ $tries -gt 100 ]]; then
                echo "too many failed attempts, exiting"
                exit 1
              fi
              tries=$((tries+1))
              [[ -z "$1" ]] || echo "that didn't work, let's try again"
              echo "getting wallpaper..."

              subreddit=$(echo -e "${lib.concatStringsSep "\\n" cfg.subreddits}" | shuf -n 1)

              RESULT=$(${pkgs.curl}/bin/curl -s -A "wallpaper bot" \
                "https://www.reddit.com/r/$subreddit/.json" \
                | ${pkgs.python3}/bin/python3 -m json.tool \
                | ${pkgs.gnugrep}/bin/grep -P '\"url\": \"htt(p|ps):\/\/((i.+)?imgur.com\/(?!.\/)[A-z0-9]{5,7}|i.redd.it|staticflickr.com)' \
                | addJpegIfImgur \
                | shuf -n 1 \
                | xargs ${pkgs.wget}/bin/wget -O "/tmp/$time.jpg" 2>/dev/null) || true

              [[ ! -f "/tmp/$time.jpg" ]] && startOver "Image not downloaded"

              hash=$(${pkgs.coreutils}/bin/sha256sum "/tmp/$time.jpg" | cut -d " " -f 1)
              [[ -f "$wallpaper_path/$hash.jpg" ]] && startOver "Already have this one"

              mv "/tmp/$time.jpg" "$wallpaper_path/$hash.jpg"

              echo "Setting image..."
              setWallpaper "$wallpaper_path/$hash.jpg"
              echo "Done"
              exit 0
            }

            getWallpaper
          '';
        in
        {
          options.services.wallpaper = {
            enable = lib.mkEnableOption "Reddit wallpaper fetcher";

            subreddits = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "earthporn"
                "wallpapers"
                "Wallpaper"
                "4kWallpaper"
                "WQHD_Wallpaper"
                "spaceporn"
              ];
              description = "List of subreddits to fetch wallpapers from";
            };

            setWallpaperCmd = lib.mkOption {
              type = lib.types.str;
              example = "\${pkgs.feh}/bin/feh --bg-scale";
              description = "Command to set the wallpaper. The image path will be appended as the last argument.";
            };

            interval = lib.mkOption {
              type = lib.types.str;
              default = "1h";
              description = "How often to fetch a new wallpaper (systemd calendar format)";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ wallpaperScript ];

            systemd.user.services.wallpaper = {
              Unit.Description = "Fetch and set random Reddit wallpaper";
              Service = {
                Type = "oneshot";
                ExecStart = "${wallpaperScript}/bin/get-wallpaper";
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

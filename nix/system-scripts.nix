{
  config,
  pkgs,
  ...
}: {
  # NOTE: - nix-darwin is only letting a limited activationScripts namespaces
  #         see: https://github.com/nix-darwin/nix-darwin/blob/73d59580d01e9b9f957ba749f336a272869c42dd/modules/system/activation-scripts.nix#L149
  #       - we use "postUserActivation" to not launch the commands as root, but rather as the user
  system.activationScripts.postUserActivation.text = ''
    # Disable Cmd+M minimize window shortcut
    /usr/bin/defaults write -g NSUserKeyEquivalents -dict-add "Minimize" "\\0"

    # --- Setup Default App for file extensions ---
    # note: get the id with `osascript -e 'id of app "VLC"'

    # Set VLC as default for all common video formats
    for ext in .3gp .3g2 .asf .avi .divx .dv .flv .m2t .m2ts .m4v .mkv \
               .mov .mp4 .mpeg .mpg .ogm .ogv .qt .rm .rmvb .ts .vob \
               .webm .wmv .xvid .amv .dav .f4v .hevc .m1v .m2v .m4b \
               .mxf .nsv .rec .swf .tod; do
      ${pkgs.duti}/bin/duti -s org.videolan.vlc "$ext" all
    done

    # Set VLC as default for all common audio formats
    for ext in .mp3 .flac .wav .aiff .aif .ogg .m4a .wma .opus .alac .aac \
               .ac3 .amr .ape .au .cda .dts .mka .mid .midi .mp2 .mpa .mpc \
               .ra .rmi .spx .tta .wv .weba .pcm .dsf .m4b .m4r .webm; do
      ${pkgs.duti}/bin/duti -s org.videolan.vlc "$ext" all
    done

    # Set Zed as default for all common text file formats
    for ext in .txt .md .markdown .rst .org .tex .bib .log \
               .json .yaml .yml .xml .css .scss .sass .less \
               .js .jsx .ts .tsx .mjs .cjs .php .py .rb .go .java .kt \
               .scala .swift .m .h .c .cpp .cc .hpp .cs .fs .fsx .rs \
               .lua .pl .pm .sh .bash .zsh .fish .ps1 .bat .cmd .vbs \
               .ini .cfg .conf .config .toml .env .gitignore .dockerignore \
               .editorconfig .eslintrc .prettierrc .babelrc .npmrc \
               .lock .gitattributes .gitmodules .gradle .properties \
               .pug .jade .ejs .erb .haml .slim .mustache .hbs .handlebars \
               .vue .svelte .astro .graphql .gql .sql .prisma; do
      ${pkgs.duti}/bin/duti -s dev.zed.Zed "$ext" all
    done

    # Set Excel as default for common table formats
    for ext in .csv .tsv .xlsx; do
      ${pkgs.duti}/bin/duti -s com.microsoft.Excel "$ext" all
    done
  '';

  # Make Apps installed with nixpkgs appear in spotlight search (by making alias in /Applications/Nix Apps/)
  system.activationScripts.applications.text = let
    env = pkgs.buildEnv {
      name = "system-applications";
      paths = config.environment.systemPackages;
      pathsToLink = "/Applications";
    };
  in
    pkgs.lib.mkForce ''
      # Set up applications.
      echo "setting up /Applications..." >&2
      rm -rf /Applications/Nix\ Apps
      mkdir -p /Applications/Nix\ Apps
      find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
      while read -r src; do
        app_name=$(basename "$src")
        echo "copying $src" >&2
        ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
      done
    '';
}

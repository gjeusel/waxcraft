{
  config,
  pkgs,
  ...
}: let
  # NOTE: postActivation runs as root, but defaults/duti/xattr are per-user tools.
  #       Re-enter the primary user's context the same way nix-darwin does for
  #       system.defaults (launchctl asuser + sudo --user).
  userActivationScript = pkgs.writeShellScript "user-post-activation" ''
    # Disable Cmd+M minimize window shortcut
    /usr/bin/defaults write -g NSUserKeyEquivalents -dict-add "Minimize" "\\0"

    # Remove quarantine attribute from unsigned apps
    xattr -cr "/Applications/YouTube Music Desktop App.app" 2>/dev/null || true

    # --- Setup Default App for file extensions ---
    # note: get the id with `osascript -e 'id of app "VLC"'
    #
    # macOS 26.4+ shows a confirmation dialog for every programmatic
    # default-app *change*, and refuses extensions that only resolve to a
    # dynamic UTI (error -50). Only call duti when the current handler
    # differs, so rebuilds are silent no-ops once associations are in place.
    skipped=""
    set_handler() {
      bundle="$1"
      shift
      for ext in "$@"; do
        current="$(${pkgs.duti}/bin/duti -x "''${ext#.}" 2>/dev/null | /usr/bin/sed -n 3p)"
        if [ "$current" != "$bundle" ]; then
          ${pkgs.duti}/bin/duti -s "$bundle" "$ext" all 2>/dev/null || skipped="$skipped $ext"
        fi
      done
    }

    # VLC: common video formats (.ts belongs to Zed, TypeScript)
    set_handler org.videolan.vlc \
      .3gp .3g2 .asf .avi .divx .dv .flv .m2t .m2ts .m4v .mkv \
      .mov .mp4 .mpeg .mpg .ogm .ogv .qt .rm .rmvb .vob \
      .webm .wmv .xvid .amv .dav .f4v .hevc .m1v .m2v .m4b \
      .mxf .nsv .rec .swf .tod

    # VLC: common audio formats
    set_handler org.videolan.vlc \
      .mp3 .flac .wav .aiff .aif .ogg .m4a .wma .opus .alac .aac \
      .ac3 .amr .ape .au .cda .dts .mka .mid .midi .mp2 .mpa .mpc \
      .ra .rmi .spx .tta .wv .weba .pcm .dsf .m4b .m4r .webm

    # Zed: common text file formats
    set_handler dev.zed.Zed \
      .txt .md .markdown .rst .org .tex .bib .log \
      .json .yaml .yml .xml .css .scss .sass .less \
      .js .jsx .ts .tsx .mjs .cjs .php .py .rb .go .java .kt \
      .scala .swift .m .h .c .cpp .cc .hpp .cs .fs .fsx .rs \
      .lua .pl .pm .sh .bash .zsh .fish .ps1 .bat .cmd .vbs \
      .ini .cfg .conf .config .toml .env .gitignore .dockerignore \
      .editorconfig .eslintrc .prettierrc .babelrc .npmrc \
      .lock .gitattributes .gitmodules .gradle .properties \
      .pug .jade .ejs .erb .haml .slim .mustache .hbs .handlebars \
      .vue .svelte .astro .graphql .gql .sql .prisma

    # Excel: common table formats
    set_handler com.microsoft.Excel .csv .tsv .xlsx

    if [ -n "$skipped" ]; then
      echo "duti: could not set:$skipped (dynamic UTI, or confirmation dialog declined)"
    fi
  '';
in {
  system.activationScripts.postActivation.text = ''
    launchctl asuser "$(id -u -- ${config.system.primaryUser})" sudo --user=${config.system.primaryUser} -- ${userActivationScript}
  '';
}

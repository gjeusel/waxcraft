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
    # macOS 26 (Tahoe) refuses handlers for extensions no installed app declares
    # (LaunchServices reports them as dyn.* UTIs, error -50). Nothing can be set
    # for those, so swallow that case and surface any other failure.
    # Tahoe also prompts the user whenever a default moves from one app to another,
    # so only touch extensions that are not already pointing at the target app.
    # Keep an extension in a single list: a conflict (e.g. .ts) would flip it and
    # trigger that prompt on every activation.
    set_handler() {
      local out current
      current=$(${pkgs.duti}/bin/duti -x "''${2#.}" 2>/dev/null | tail -n 1)
      [ "$current" = "$1" ] && return 0
      if ! out=$(${pkgs.duti}/bin/duti -s "$1" "$2" all 2>&1); then
        case "$out" in
          *"for dyn."*) ;;
          *) printf '%s\n' "$out" >&2 ;;
        esac
      fi
    }

    # Set VLC as default for all common video formats
    for ext in .3gp .3g2 .asf .avi .divx .dv .flv .m2t .m2ts .m4v .mkv \
               .mov .mp4 .mpeg .mpg .ogm .ogv .qt .rm .rmvb .vob \
               .webm .wmv .xvid .amv .dav .f4v .hevc .m1v .m2v .m4b \
               .mxf .nsv .rec .swf .tod; do
      set_handler org.videolan.vlc "$ext"
    done

    # Set VLC as default for all common audio formats
    for ext in .mp3 .flac .wav .aiff .aif .ogg .m4a .wma .opus .alac .aac \
               .ac3 .amr .ape .au .cda .dts .mka .mid .midi .mp2 .mpa .mpc \
               .ra .rmi .spx .tta .wv .weba .pcm .dsf .m4b .m4r .webm; do
      set_handler org.videolan.vlc "$ext"
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
      set_handler dev.zed.Zed "$ext"
    done

    # Set Excel as default for common table formats
    for ext in .csv .tsv .xlsx; do
      set_handler com.microsoft.Excel "$ext"
    done
  '';
in {
  system.activationScripts.postActivation.text = ''
    launchctl asuser "$(id -u -- ${config.system.primaryUser})" sudo --user=${config.system.primaryUser} -- ${userActivationScript}
  '';
}

#!/usr/bin/env bash
#
# Atlas.command — Atlas dev control panel (native macOS GUI)
#
# Double-click to launch. Presents native macOS button dialogs (via AppleScript)
# for the everyday workflow: sync with GitHub, switch/merge branches, open Xcode,
# build & run on a simulator, deploy the Worker. No build step, no install, no
# Gatekeeper app — it's a plain script that drives osascript for the UI and
# git/xcodebuild/wrangler for the work.
#
# The companion atlas.sh (text menu) stays as the terminal/power-user version;
# this file is the click-the-buttons version.
#
set -uo pipefail

# ----------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------
REPO_URL="https://github.com/sahmoee/Atlas.git"
WORKER_DIR="atlas-worker"
PREFERRED_SIM="iPhone 16 Pro"
APP_TITLE="Atlas Control Panel"

# ----------------------------------------------------------------------------
# Native dialog helpers (AppleScript via osascript)
# ----------------------------------------------------------------------------

# gui_msg "text" [icon: note|caution|stop] — simple OK dialog.
gui_msg() {
  local text="$1" icon="${2:-note}"
  osascript >/dev/null 2>&1 <<OSA
    display dialog "${text//\"/\\\"}" with title "$APP_TITLE" buttons {"OK"} default button "OK" with icon $icon
OSA
}

# gui_confirm "text" — returns 0 if user clicks Continue, 1 if Cancel.
gui_confirm() {
  local text="$1"
  osascript >/dev/null 2>&1 <<OSA
    display dialog "${text//\"/\\\"}" with title "$APP_TITLE" buttons {"Cancel","Continue"} default button "Continue" with icon caution
OSA
}

# gui_prompt "text" "default" — echoes typed text, or empty on cancel.
gui_prompt() {
  local text="$1" def="${2:-}"
  osascript 2>/dev/null <<OSA
    try
      set r to text returned of (display dialog "${text//\"/\\\"}" with title "$APP_TITLE" default answer "${def//\"/\\\"}" buttons {"Cancel","OK"} default button "OK")
      return r
    on error
      return ""
    end try
OSA
}

# gui_choose "prompt" item1 item2 …  — native clickable list; echoes choice or empty.
gui_choose() {
  local prompt="$1"; shift
  local items="" i
  for i in "$@"; do items+="\"${i//\"/\\\"}\","; done
  items="${items%,}"
  osascript 2>/dev/null <<OSA
    set theList to {$items}
    set theChoice to choose from list theList with title "$APP_TITLE" with prompt "${prompt//\"/\\\"}" OK button name "Select" cancel button name "Quit"
    if theChoice is false then
      return ""
    else
      return item 1 of theChoice
    end if
OSA
}

# Open a Terminal window and run a command there, so long operations (build,
# deploy) show live output. Waits for it to finish, returns its exit status via
# a temp file.
gui_run_in_terminal() {
  local title="$1"; shift
  local cmd="$*"
  local statusfile; statusfile=$(mktemp /tmp/atlas_status.XXXXXX)
  local script; script=$(mktemp /tmp/atlas_run.XXXXXX.sh)
  cat > "$script" <<EOF
#!/usr/bin/env bash
echo "──────── $title ────────"
cd "$REPO_ROOT" || exit 1
$cmd
code=\$?
echo \$code > "$statusfile"
echo ""
if [ \$code -eq 0 ]; then echo "✅ Done. You can close this window."; else echo "❌ Failed (exit \$code). Scroll up for details."; fi
EOF
  chmod +x "$script"
  # Launch in Terminal and bring it to the front.
  osascript >/dev/null 2>&1 <<OSA
    tell application "Terminal"
      activate
      do script "bash '$script'"
    end tell
OSA
  # Wait for the status file to be written.
  local waited=0
  while [[ ! -s "$statusfile" ]]; do
    sleep 1; waited=$((waited+1))
    [[ $waited -gt 1200 ]] && break   # 20-min safety cap
  done
  local rc; rc=$(cat "$statusfile" 2>/dev/null || echo 1)
  rm -f "$statusfile" "$script"
  return "${rc:-1}"
}

# ----------------------------------------------------------------------------
# Repo + project discovery
# ----------------------------------------------------------------------------
REPO_ROOT=""; XCODEPROJ=""; SCHEME=""

have() { command -v "$1" >/dev/null 2>&1; }

find_repo_root() {
  local self_dir; self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # 1) the .command sitting inside the repo
  if git -C "$self_dir" rev-parse --show-toplevel >/dev/null 2>&1; then
    REPO_ROOT="$(git -C "$self_dir" rev-parse --show-toplevel)"; return 0
  fi
  # 2) an Atlas/.git next to the .command
  [[ -d "$self_dir/Atlas/.git" ]] && { REPO_ROOT="$self_dir/Atlas"; return 0; }
  return 1
}

ensure_repo() {
  find_repo_root && return 0
  local self_dir; self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if gui_confirm "No Atlas repo found.

Clone it into:
$self_dir/Atlas ?"; then
    gui_run_in_terminal "Clone Atlas" "git clone '$REPO_URL' '$self_dir/Atlas'"
    if [[ -d "$self_dir/Atlas/.git" ]]; then REPO_ROOT="$self_dir/Atlas"; return 0; fi
  fi
  gui_msg "Can't continue without the repo." stop
  return 1
}

discover_project() {
  XCODEPROJ=$(find "$REPO_ROOT" -maxdepth 2 -name "*.xcodeproj" -not -path "*/.*" | head -1)
  [[ -z "$XCODEPROJ" ]] && return 1
  SCHEME=$(xcodebuild -project "$XCODEPROJ" -list 2>/dev/null \
            | awk '/Schemes:/{f=1;next} f&&NF{gsub(/^[ \t]+/,"");print;exit}')
  [[ -z "$SCHEME" ]] && SCHEME=$(basename "$XCODEPROJ" .xcodeproj)
  return 0
}

# ----------------------------------------------------------------------------
# Git helpers
# ----------------------------------------------------------------------------
git_in() { git -C "$REPO_ROOT" "$@"; }
current_branch() { git_in rev-parse --abbrev-ref HEAD 2>/dev/null; }
git_dirty() { [[ -n "$(git_in status --porcelain 2>/dev/null)" ]]; }

branch_list() {
  git_in fetch origin >/dev/null 2>&1
  { git_in for-each-ref --format='%(refname:short)' refs/heads
    git_in for-each-ref --format='%(refname:short)' refs/remotes/origin | sed 's#^origin/##'
  } | grep -v '^HEAD$' | sort -u
}

# ----------------------------------------------------------------------------
# Actions
# ----------------------------------------------------------------------------

act_sync() {
  if git_dirty; then
    gui_msg "You have uncommitted changes, so a pull was skipped.

Use “Stash / restore” first, or commit in Xcode, then sync again." caution
    return
  fi
  local br; br=$(current_branch)
  if gui_run_in_terminal "Sync $br" "git fetch origin && git pull --ff-only origin '$br'"; then
    gui_msg "Synced “$br” with GitHub." note
  else
    gui_msg "Sync didn’t complete cleanly.

If the branch has no upstream yet, use “Switch branch” to check out a Claude branch first." caution
  fi
}

act_switch() {
  local choices=(); local line
  while IFS= read -r line; do [[ -n "$line" ]] && choices+=("$line"); done < <(branch_list)
  [[ ${#choices[@]} -eq 0 ]] && { gui_msg "No branches found." caution; return; }
  local target; target=$(gui_choose "Check out which branch?" "${choices[@]}")
  [[ -z "$target" ]] && return
  if git_dirty; then
    gui_confirm "You have uncommitted changes. Switching may carry them along.

Continue anyway?" || return
  fi
  local cmd
  if git_in show-ref --verify --quiet "refs/heads/$target"; then
    cmd="git checkout '$target'"
  else
    cmd="git checkout -b '$target' --track 'origin/$target'"
  fi
  if gui_run_in_terminal "Checkout $target" "$cmd && git pull --ff-only 2>/dev/null; true"; then
    gui_msg "Now on “$target”." note
  else
    gui_msg "Couldn’t switch to “$target”." stop
  fi
}

act_merge() {
  if git_dirty; then gui_msg "Commit or stash your changes before merging." caution; return; fi
  local choices=(); local line
  while IFS= read -r line; do [[ -n "$line" ]] && choices+=("$line"); done < <(branch_list | grep -v '^main$')
  [[ ${#choices[@]} -eq 0 ]] && { gui_msg "No feature branches to merge." caution; return; }
  local src; src=$(gui_choose "Merge which branch INTO main?" "${choices[@]}")
  [[ -z "$src" ]] && return
  gui_confirm "Merge “$src” into main?

This updates your local main. You’ll be asked whether to push it to GitHub after." || return
  if gui_run_in_terminal "Merge $src → main" \
      "git checkout main && git pull --ff-only origin main && git fetch origin '$src' && (git merge --no-edit 'origin/$src' || git merge --no-edit '$src')"; then
    if gui_confirm "Merged “$src” into main.

Push main to GitHub now? (Uses your saved GitHub login.)"; then
      gui_run_in_terminal "Push main" "git push origin main" \
        && gui_msg "main pushed to GitHub." note \
        || gui_msg "Push failed — check your GitHub login in Xcode/Keychain." stop
    fi
  else
    gui_msg "Merge hit conflicts.

Resolve them in Xcode, or in Terminal run:
git -C \"$REPO_ROOT\" merge --abort" stop
  fi
}

act_stash() {
  local pick; pick=$(gui_choose "Local changes:" "Stash (shelve current changes)" "Pop (restore last stash)")
  case "$pick" in
    Stash*) git_in stash push -u -m "Atlas.command $(date +%H:%M)" >/dev/null 2>&1 && gui_msg "Changes stashed." note ;;
    Pop*)   git_in stash pop >/dev/null 2>&1 && gui_msg "Changes restored." note || gui_msg "Nothing to restore." caution ;;
    *) : ;;
  esac
}

act_open_xcode() {
  open "$XCODEPROJ" && gui_msg "Opening Xcode.

Press ▶︎ Run in Xcode to build and launch." note || gui_msg "Couldn’t open Xcode." stop
}

pick_simulator() {
  local udid
  udid=$(xcrun simctl list devices booted 2>/dev/null | grep -Eo '[0-9A-F-]{36}' | head -1)
  [[ -n "$udid" ]] && { echo "$udid"; return; }
  udid=$(xcrun simctl list devices available 2>/dev/null | grep "$PREFERRED_SIM (" | grep -Eo '[0-9A-F-]{36}' | head -1)
  [[ -n "$udid" ]] && { echo "$udid"; return; }
  xcrun simctl list devices available 2>/dev/null | grep -E "iPhone" | grep -Eo '[0-9A-F-]{36}' | head -1
}

act_run_sim() {
  local udid; udid=$(pick_simulator)
  [[ -z "$udid" ]] && { gui_msg "No iOS simulator available.

Add one in Xcode ▸ Settings ▸ Platforms." stop; return; }
  gui_confirm "Build “$SCHEME” and run it on the simulator?

This can take a minute; progress shows in a Terminal window." || return
  local DERIVED="$REPO_ROOT/.atlas-build"
  local build_cmd="xcrun simctl boot '$udid' >/dev/null 2>&1; open -a Simulator; \
xcodebuild -project '$XCODEPROJ' -scheme '$SCHEME' -configuration Debug -destination 'id=$udid' -derivedDataPath '$DERIVED' build && \
APP=\$(find '$DERIVED/Build/Products' -maxdepth 2 -name '*.app' -type d | head -1) && \
BID=\$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \"\$APP/Info.plist\" 2>/dev/null) && \
xcrun simctl install '$udid' \"\$APP\" && xcrun simctl launch '$udid' \"\$BID\""
  if gui_run_in_terminal "Build & run on simulator" "$build_cmd"; then
    gui_msg "Built and launched on the simulator." note
  else
    gui_msg "Build or launch failed.

Open the Terminal window for the first error, or use “Open in Xcode” to debug." stop
  fi
}

act_deploy_worker() {
  local wdir="$REPO_ROOT/$WORKER_DIR"
  [[ ! -d "$wdir" ]] && { gui_msg "No “$WORKER_DIR” folder in the repo." stop; return; }
  if ! have npx; then gui_msg "npx not found.

Install Node from nodejs.org, then try again." stop; return; fi
  gui_confirm "Deploy the Cloudflare Worker?

First time, a browser opens to log in to Cloudflare. Secrets live in Cloudflare, not the repo." || return
  if gui_run_in_terminal "Deploy Worker" "cd '$wdir' && npx wrangler deploy"; then
    gui_msg "Worker deployed." note
  else
    gui_msg "Deploy failed — check Cloudflare login and wrangler.toml." stop
  fi
}

act_status() {
  local br dirty up
  br=$(current_branch); dirty="clean"; git_dirty && dirty="uncommitted changes"
  up="$(git_in log -1 --pretty='%h — %s' 2>/dev/null)"
  gui_msg "Branch:  $br
State:   $dirty
Latest:  $up

Project: $(basename "$XCODEPROJ")
Scheme:  $SCHEME
Worker:  $WORKER_DIR" note
}

# ----------------------------------------------------------------------------
# Main menu loop
# ----------------------------------------------------------------------------
main_loop() {
  while true; do
    local br; br=$(current_branch)
    local flag=""; git_dirty && flag="  •changes"
    local pick
    pick=$(gui_choose "On branch: ${br}${flag}" \
      "Sync with GitHub (pull latest)" \
      "Switch / check out a branch" \
      "Merge a branch into main" \
      "Stash / restore changes" \
      "Open in Xcode (then press Run)" \
      "Build & run on simulator" \
      "Deploy Cloudflare Worker" \
      "Show status" )
    case "$pick" in
      "Sync"*)    act_sync ;;
      "Switch"*)  act_switch ;;
      "Merge"*)   act_merge ;;
      "Stash"*)   act_stash ;;
      "Open in Xcode"*) act_open_xcode ;;
      "Build & run"*)   act_run_sim ;;
      "Deploy"*)  act_deploy_worker ;;
      "Show status"*)   act_status ;;
      "")  exit 0 ;;   # Quit / cancel
      *)   : ;;
    esac
  done
}

# ----------------------------------------------------------------------------
# Boot
# ----------------------------------------------------------------------------
if ! have git; then
  gui_msg "Git isn’t installed.

Install Xcode from the App Store, then run in Terminal:
xcode-select --install" stop
  exit 1
fi
ensure_repo || exit 1
if ! discover_project; then
  gui_msg "Found the repo, but no Xcode project inside it." stop
  exit 1
fi
main_loop

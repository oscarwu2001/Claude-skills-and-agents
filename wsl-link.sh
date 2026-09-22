#!/usr/bin/env bash
# Point a WSL install of Claude Code at the Windows ~/.claude, so there is one
# configuration on the machine, not two that drift.
#
# WSL's Claude Code reads /home/<name>/.claude; the Windows one reads
# C:\Users\<name>\.claude, which is this git checkout. Before these links WSL
# sessions ran with no agents, no skills and a separate auto-memory, silently.
#
# Run once by hand (bash /mnt/c/Users/<name>/.claude/wsl-link.sh), then the
# SessionStart hook in WSL's settings.json re-runs it every session, so a skill
# or project added on the Windows side is linked without anyone remembering to.
#
# Left per-install on purpose: settings.json (hooks and the status line are
# WSL commands), skills/synced/ (each install manages its own), plugins/
# (install paths are native to each side), credentials, history, sessions.
#
# It never replaces a real file or folder: a WSL-side copy that still holds
# something is reported on stderr and left for a person to merge.
set -u
shopt -s nullglob   # an empty folder must loop zero times, not over a literal "*"

W="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"   # the Windows .claude
H="$HOME/.claude"
[ "$W" = "$H" ] && exit 0                              # not a WSL install
mkdir -p "$H/skills" "$H/projects"

link() {  # link <target> <link path>
  if [ -L "$2" ]; then
    [ "$(readlink "$2")" = "$1" ] || ln -sfn "$1" "$2"
  elif [ -e "$2" ]; then
    if [ -d "$2" ] && [ -z "$(ls -A "$2")" ]; then
      rmdir "$2" && ln -s "$1" "$2"
    else
      echo "wsl-link: $2 is a real file or folder, not linked to $1 -- merge it by hand" >&2
    fi
  else
    ln -s "$1" "$2"
  fi
}

for x in agents CLAUDE.md ecc-library skill-observations wsl-link.sh; do
  [ -e "$W/$x" ] && link "$W/$x" "$H/$x"
done

for s in "$W"/skills/*; do
  [ "$(basename "$s")" = synced ] || link "$s" "$H/skills/$(basename "$s")"
done
for l in "$H"/skills/*; do   # a skill removed on Windows leaves a dangling link
  [ -L "$l" ] && [ ! -e "$l" ] && case "$(readlink "$l")" in "$W"/*) rm "$l" ;; esac
done

# Auto-memory is keyed by project path, spelled differently by each install:
# /mnt/c/Users/x/proj is "-mnt-c-Users-x-proj" here and "c--Users-x-proj" on
# Windows. Only projects on a Windows drive have a Windows twin. The session's
# own project is included because its folder may not exist yet at SessionStart.
for d in "$H"/projects/-mnt-[a-z]-* "$H/projects/$(echo "$PWD" | sed 's/[^A-Za-z0-9]/-/g')"; do
  n="$(basename "$d")"
  case "$n" in -mnt-[a-z]-?*) ;; *) continue ;; esac
  wn="${n:5:1}--${n:7}"   # -mnt-c-Users-x-proj -> c--Users-x-proj
  # Create the Windows side only when the link can actually be made, so a
  # refused link leaves no empty folder behind.
  if [ -L "$d/memory" ] || [ ! -e "$d/memory" ] || [ -z "$(ls -A "$d/memory")" ]; then
    mkdir -p "$d" "$W/projects/$wn/memory"
    link "$W/projects/$wn/memory" "$d/memory"
  else
    link "$W/projects/$wn/memory" "$d/memory"   # reports it, changes nothing
  fi
done
exit 0

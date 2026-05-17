#!/usr/bin/env sh
# single-embedded-checklist-fixed.sh
# MIT License
# Single-file, portable checklist (multi-select) widget embedded with example usage.
# Portable-only variant: targets sh (dash/ash/busybox), bash, zsh, and includes an embedded fish implementation.
# No external dialog binaries required. Clean-room implementation; do not copy GPL sources.

# Dispatcher: forward to fish section if requested or running in fish
if [ "${1:-}" = "--fish" ]; then
  shift
  if command -v fish >/dev/null 2>&1; then
    awk '/^__FISH__$/ {p=1; next} p{print}' "$0" | fish -s - "$@"
    exit $?
  else
    printf 'fish shell not found in PATH\n' >&2
    exit 2
  fi
fi

if [ -n "${FISH_VERSION:-}" ]; then
  awk '/^__FISH__$/ {p=1; next} p{print}' "$0" | fish -s - "$@"
  exit $?
fi

# -----------------------
# POSIX checklist implementation
# -----------------------

_term_saved_stty=
term_init() {
  _term_saved_stty=$(stty -g 2>/dev/null || true)
  stty -echo -icanon min 1 time 0 2>/dev/null || true
  printf '\033[?25l'
  trap 'term_restore; exit 1' INT TERM HUP
}

term_restore() {
  [ -n "$_term_saved_stty" ] && stty "$_term_saved_stty" 2>/dev/null || true
  printf '\033[?25h'
  trap - INT TERM HUP
}

clear_screen() { printf '\033[2J\033[H'; }
move_cursor() { printf '\033[%s;%sH' "$1" "$2"; }

# Portable key reader
read_key() {
  key=$(dd bs=1 count=1 2>/dev/null </dev/tty || true)
  if [ "$key" = $'\033' ]; then
    seq=$(dd bs=1 count=2 2>/dev/null </dev/tty || true)
    key="$key$seq"
  fi
  printf '%s' "$key"
}

# Portable ANSI-strip using real ESC byte (fixes BusyBox/GNU sed differences)
str_len() {
  esc=$(printf '\033')
  s=$(printf '%s' "$1" | esc=$(printf '\033')
sed "s/${esc}\

\[[0-9;]*[a-zA-Z]//g"
  printf '%s' "${#s}"
}

truncate_label() {
  label=$1; width=$2
  esc=$(printf '\033')
  clean=$(printf '%s' "$label" | esc=$(printf '\033')
sed "s/${esc}\

\[[0-9;]*[a-zA-Z]//g"
  len=${#clean}
  if [ "$len" -le "$width" ]; then
    printf '%s' "$label"
  else
    cutlen=$((width - 1))
    printf '%s…' "$(printf '%s' "$clean" | awk -v L=$cutlen '{print substr($0,1,L)}')"
  fi
}

_draw_box() {
  w=$1; h=$2; title=$3
  printf '+'
  i=1
  while [ $i -lt $w ]; do printf '-'; i=$((i+1)); done
  printf '+\n'
  i=1
  while [ $i -lt $h ]; do
    printf '|'
    j=1
    while [ $j -lt $w ]; do printf ' '; j=$((j+1)); done
    printf '|\n'
    i=$((i+1))
  done
  printf '+'
  i=1
  while [ $i -lt $w ]; do printf '-'; i=$((i+1)); done
  printf '+\n'
  move_cursor 1 3
  printf '%s' "$title"
}

checklist_fallback() {
  title="$1"; shift
  prompt="$1"; shift
  i=1
  tags=""
  for a in "$@"; do
    tag=$(printf '%s' "$a" | awk -F'|' '{print $1}')
    label=$(printf '%s' "$a" | awk -F'|' '{print $2}')
    [ -z "$label" ] && label="$tag"
    printf '%3d) %s\n' "$i" "$label"
    tags="$tags
$tag"
    i=$((i+1))
  done
  printf '%s\n' "$prompt"
  printf 'Enter numbers separated by spaces (or empty to cancel): '
  IFS= read -r sel
  if [ -z "$sel" ]; then return 1; fi
  IFS=' '
  set -- $sel
  IFS='
'
  set -- $tags
  tags_list="$*"
  unset IFS
  idx=0
  for tag in $tags_list; do
    idx=$((idx+1))
    for s in "$@"; do
      if [ "$s" -eq "$idx" ] 2>/dev/null; then printf '%s\n' "$tag"; fi
    done
  done
  return 0
}

checklist() {
  title="$1"; shift
  prompt="$1"; shift
  items_count=0
  tags=""
  labels=""
  states=""
  for a in "$@"; do
    tag=$(printf '%s' "$a" | awk -F'|' '{print $1}')
    label=$(printf '%s' "$a" | awk -F'|' '{print $2}')
    init=$(printf '%s' "$a" | awk -F'|' '{print $3}')
    [ -z "$label" ] && label="$tag"
    if [ "$init" = "on" ]; then state=1; else state=0; fi
    tags="$tags
$tag"
    labels="$labels
$label"
    states="$states
$state"
    items_count=$((items_count+1))
  done

  if [ ! -t 0 ] || [ "${TERM:-}" = "dumb" ]; then
    checklist_fallback "$title" "$prompt" "$@"
    return $?
  fi

  IFS='
'
  set -- $tags
  tags_list="$*"
  set -- $labels
  labels_list="$*"
  set -- $states
  states_list="$*"
  unset IFS

  idx=0
  for tag in $tags_list; do
    idx=$((idx+1))
    eval "item_tag_$idx=\$tag"
  done
  idx=0
  for label in $labels_list; do
    idx=$((idx+1))
    safe_label=$(printf '%s' "$label" | sed "s/'/'\\\\''/g")
    eval "item_label_$idx='$safe_label'"
  done
  idx=0
  for st in $states_list; do
    idx=$((idx+1))
    eval "item_state_$idx=\$st"
  done

  term_init
  clear_screen

  rows=$(tput lines 2>/dev/null || printf 24)
  cols=$(tput cols 2>/dev/null || printf 80)
  box_w=$((cols - 4))
  box_h=$((rows - 6))
  [ $box_w -lt 30 ] && box_w=30
  [ $box_h -lt 8 ] && box_h=8

  per_page=$((box_h - 6))
  [ $per_page -lt 3 ] && per_page=3
  total=$items_count
  cursor=1
  page=0
  max_page=$(( (total + per_page - 1) / per_page - 1 ))

  render() {
    clear_screen
    _draw_box "$box_w" "$box_h" "$title"
    move_cursor 3 3
    printf '%s\n' "$prompt"
    start=$((page * per_page + 1))
    end=$((start + per_page - 1))
    [ $end -gt $total ] && end=$total
    line=5
    label_w=$((box_w - 12))
    i=$start
    while [ $i -le $end ]; do
      eval st=\$item_state_$i
      eval lab=\$item_label_$i
      if [ "$st" -eq 1 ]; then mark='[x]'; else mark='[ ]'; fi
      if [ $i -eq $cursor ]; then
        move_cursor $line 3
        printf '\033[7m%s %s\033[0m' "$mark" "$(truncate_label "$lab" $label_w)"
      else
        move_cursor $line 3
        printf '%s %s' "$mark" "$(truncate_label "$lab" $label_w)"
      fi
      line=$((line+1))
      i=$((i+1))
    done
    move_cursor $((box_h)) 3
    printf 'Space toggle  a select all  Enter confirm  q cancel  PgUp/PgDn page'
    move_cursor $((box_h)) $((box_w - 20))
    printf 'Page %d/%d' $((page+1)) $((max_page+1))
  }

  ensure_cursor() {
    if [ $cursor -lt $((page*per_page+1)) ]; then
      page=$(( (cursor-1) / per_page ))
    elif [ $cursor -gt $((page*per_page+per_page)) ]; then
      page=$(( (cursor-1) / per_page ))
    fi
  }

  while :; do
    ensure_cursor
    render
    key=$(read_key)
    case "$key" in
      $'\n'|$'\r')
        term_restore
        i=1
        while [ $i -le $total ]; do
          eval st=\$item_state_$i
          eval tag=\$item_tag_$i
          if [ "$st" -eq 1 ]; then printf '%s\n' "$tag"; fi
          i=$((i+1))
        done
        return 0
        ;;
      $'\033' )
        term_restore
        return 1
        ;;
      $'\033[A'|$'\033OA') # Arrow Up
        if [ $cursor -gt 1 ]; then cursor=$((cursor-1)); fi
        ;;
      $'\033[B'|$'\033OB') # Arrow Down
        if [ $cursor -lt $total ]; then cursor=$((cursor+1)); fi
        ;;
      $'\033[5~') # PgUp
        if [ $page -gt 0 ]; then page=$((page-1)); cursor=$((page*per_page+1)); fi
        ;;
      $'\033[6~') # PgDn
        if [ $page -lt $max_page ]; then page=$((page+1)); cursor=$((page*per_page+1)); fi
        ;;
      ' ' )
        eval st=\$item_state_$cursor
        if [ "$st" -eq 1 ]; then new=0; else new=1; fi
        eval "item_state_$cursor=$new"
        ;;
      $'\x7f'|$'\b')   # Backspace (DEL or BS) -> toggle current
        eval st=\$item_state_$cursor
        if [ "$st" -eq 1 ]; then new=0; else new=1; fi
        eval "item_state_$cursor=$new"
        ;;
      'w'|'W') # W -> up
        if [ $cursor -gt 1 ]; then cursor=$((cursor-1)); fi
        ;;
      's'|'S') # S -> down
        if [ $cursor -lt $total ]; then cursor=$((cursor+1)); fi
        ;;
      'a'|'A') # A -> select all / toggle all
        any_off=0
        i=1
        while [ $i -le $total ]; do
          eval st=\$item_state_$i
          if [ "$st" -eq 0 ]; then any_off=1; break; fi
          i=$((i+1))
        done
        i=1
        while [ $i -le $total ]; do
          if [ $any_off -eq 1 ]; then eval "item_state_$i=1"; else eval "item_state_$i=0"; fi
          i=$((i+1))
        done
        ;;
      'd'|'D') # D -> toggle current (alternate)
        eval st=\$item_state_$cursor
        if [ "$st" -eq 1 ]; then new=0; else new=1; fi
        eval "item_state_$cursor=$new"
        ;;
      'q'|$'\003') # q or Ctrl-C
        term_restore
        return 1
        ;;
      *)
        ;;
    esac
  done
}

# Demo / example usage
if [ "${1:-}" = "--demo" ]; then
  checklist "Select Features" "Choose features to enable:" \
    "core|Core utilities (required)|on" \
    "net|Networking tools|off" \
    "dev|Development tools|off" \
    "docs|Documentation|off" \
    "extras|Extra utilities|off"
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "Selected:"
    cat
  else
    echo "Cancelled" >&2
  fi
  exit $rc
fi

if [ $# -gt 0 ]; then
  checklist "$@"
  exit $?
fi

if [ -t 0 ]; then
  echo "Demo: choose components to simulate installation."
  if selected=$(checklist "Install components" "Select components to install:" \
      "core|Core utilities (required)|on" \
      "net|Networking tools|off" \
      "dev|Development tools|off" \
      "docs|Documentation|off" \
      "extras|Extra utilities|off"); then

    echo
    echo "User confirmed. Selected tags:"
    printf '%s\n' "$selected" | while IFS= read -r tag; do
      echo " - $tag"
      case "$tag" in
        core) echo "   Installing core utilities..."; sleep 0.2;;
        net)  echo "   Installing networking tools..."; sleep 0.2;;
        dev)  echo "   Installing development tools..."; sleep 0.2;;
        docs) echo "   Installing documentation..."; sleep 0.2;;
        extras) echo "   Installing extras..."; sleep 0.2;;
      esac
    done
    echo "Done."
    exit 0
  else
    echo "User cancelled." >&2
    exit 1
  fi
else
  cat <<'USAGE'
Usage:
  ./single-embedded-checklist-fixed.sh --demo
  ./single-embedded-checklist-fixed.sh "Title" "Prompt" "tag|Label|on" "tag2|Label2|off" ...
  Source this file to call checklist() from another script.
USAGE
  exit 0
fi

# -----------------------
# Embedded fish implementation
# -----------------------
__FISH__
# (fish section unchanged; executed when piped to fish)
function __fish_checklist_main
  set -l args $argv
  if test (count $args) -eq 0
    set -l items \
      "core|Core utilities|on" \
      "net|Networking tools|off" \
      "dev|Development tools|off" \
      "extras|Extra utilities with a long label that will be truncated|off"
    set -l title "Select Features"
    set -l prompt "Choose features to enable:"
  else
    set -l title $args[1]; set -e args[1]
    set -l prompt $args[1]; set -e args[1]
    set -l items $args
  end

  set -l list
  for it in $items
    set -l tag (string split '|' $it)[1]
    set -l label (string split '|' $it)[2]
    set -l init (string split '|' $it)[3]
    if test -z "$label"
      set label $tag
    end
    if test "$init" = "on"
      set state 1
    else
      set state 0
    end
    set list $list "$tag|$label|$state"
  end

  stty -echo -icanon min 1 time 0
  printf '\033[?25l'
  function cleanup --on-variable __fish_checklist_cleanup
    stty echo icanon
    printf '\033[?25h'
  end

  set -l rows (tput lines 2>/dev/null; or echo 24)
  set -l cols (tput cols 2>/dev/null; or echo 80)
  set -l box_w (math $cols - 4)
  set -l box_h (math $rows - 6)
  if test $box_w -lt 30; set box_w 30; end
  if test $box_h -lt 8; set box_h 8; end
  set -l per_page (math $box_h - 6)
  if test $per_page -lt 3; set per_page 3; end
  set -l total (count $list)
  set -l cursor 1
  set -l page 0
  set -l max_page (math (math ($total + $per_page - 1) / $per_page) - 1)

  function render
    clear
    printf '+'
    for i in (seq (math $box_w - 2)); printf '-'; end
    printf '+\n'
    printf "| $title"
    for i in (seq (math $box_w - 3 - (string length -- $title))); printf ' '; end
    printf "|\n"
    printf '+'
    for i in (seq (math $box_w - 2)); printf '-'; end
    printf '+\n'
    printf '%s\n' "$prompt"
    set -l start (math $page * $per_page + 1)
    set -l end (math $start + $per_page - 1)
    if test $end -gt $total; set end $total; end
    set -l i $start
    while test $i -le $end
      set -l entry $list[$i]
      set -l tag (string split '|' $entry)[1]
      set -l label (string split '|' $entry)[2]
      set -l st (string split '|' $entry)[3]
      if test $st -eq 1
        set mark '[x]'
      else
        set mark '[ ]'
      end
      if test $i -eq $cursor
        printf '\033[7m%s %s\033[0m\n' "$mark" "$label"
      else
        printf '%s %s\n' "$mark" "$label"
      end
      set i (math $i + 1)
    end
    printf '\nSpace toggle  a select all  Enter confirm  q cancel  PgUp/PgDn page\n'
    printf 'Page %d/%d\n' (math $page + 1) (math $max_page + 1)
  end

  while true
    render
    set -l key (dd bs=1 count=1 2>/dev/null </dev/tty)
    if test "$key" = $'\n'
      stty echo icanon
      printf '\033[?25h'
      for e in $list
        if test (string split '|' $e)[3] -eq 1
          printf '%s\n' (string split '|' $e)[1]
        end
      end
      return 0
    end
    switch "$key"
      case $'\033'
        set -l seq (dd bs=1 count=2 2>/dev/null </dev/tty)
        set key "$key$seq"
        switch "$key"
          case $'\033[A' $'\033OA'
            if test $cursor -gt 1; set cursor (math $cursor - 1); end
          case $'\033[B' $'\033OB'
            if test $cursor -lt $total; set cursor (math $cursor + 1); end
          case $'\033[5~'
            if test $page -gt 0; set page (math $page - 1); set cursor (math $page * $per_page + 1); end
          case $'\033[6~'
            if test $page -lt $max_page; set page (math $page + 1); set cursor (math $page * $per_page + 1); end
        end
      case ' '
        set -l e $list[$cursor]
        set -l tag (string split '|' $e)[1]
        set -l label (string split '|' $e)[2]
        set -l st (string split '|' $e)[3]
        if test $st -eq 1
          set st 0
        else
          set st 1
        end
        set list[$cursor] "$tag|$label|$st"
      case $'\x7f' $'\b'
        set -l e $list[$cursor]
        set -l tag (string split '|' $e)[1]
        set -l label (string split '|' $e)[2]
        set -l st (string split '|' $e)[3]
        if test $st -eq 1
          set st 0
        else
          set st 1
        end
        set list[$cursor] "$tag|$label|$st"
      case 'w' 'W'
        if test $cursor -gt 1; set cursor (math $cursor - 1); end
      case 's' 'S'
        if test $cursor -lt $total; set cursor (math $cursor + 1); end
      case 'a' 'A'
        set any_off 0
        for e in $list
          if test (string split '|' $e)[3] -eq 0
            set any_off 1; break
          end
        end
        for i in (seq (count $list))
          set e $list[$i]
          set tag (string split '|' $e)[1]
          set label (string split '|' $e)[2]
          if test $any_off -eq 1
            set list[$i] "$tag|$label|1"
          else
            set list[$i] "$tag|$label|0"
          end
        end
      case 'd' 'D'
        set -l e $list[$cursor]
        set -l tag (string split '|' $e)[1]
        set -l label (string split '|' $e)[2]
        set -l st (string split '|' $e)[3]
        if test $st -eq 1
          set st 0
        else
          set st 1
        end
        set list[$cursor] "$tag|$label|$st"
      case 'q' 'Q'
        stty echo icanon
        printf '\033[?25h'
        return 1
      case '*'
    end
  end
end

if status --is-interactive
  :
else
  __fish_checklist_main $argv
end

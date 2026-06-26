# ============================================================
# Title: fu.ps1
# Author: C-Fu
# Description: PowerShell equivalent of fu.sh for Windows
# Compatibility: Windows PowerShell 5.1+ / PowerShell 7+
# ============================================================

# Colors
$ESC = [char]27
$RED = "$ESC[0;31m"
$GREEN = "$ESC[0;32m"
$YELLOW = "$ESC[1;33m"
$BLUE = "$ESC[0;34m"
$CYAN = "$ESC[0;36m"
$MAGENTA = "$ESC[0;35m"
$WHITE = "$ESC[1;37m"
$BOLD = "$ESC[1m"
$DIM = "$ESC[2m"
$NC = "$ESC[0m"
$BCYAN = "$ESC[1;36m"

# Box Drawing
$BOX_TL = "┌"
$BOX_TR = "┐"
$BOX_BL = "└"
$BOX_BR = "┘"
$BOX_H = "─"
$BOX_V = "│"

# Emojis
$EMOJI_DOCKER = "🐳"
$EMOJI_STATUS = "🔍"
$EMOJI_DEV = "🛠️"
$EMOJI_GSD = "🚀"
$EMOJI_PHP = "🐘"
$EMOJI_CHECK = "✓"
$EMOJI_CROSS = "✗"
$EMOJI_ARROW = "➜"
$EMOJI_HEART = "💜"
$EMOJI_PROMPT = "✨"
$EMOJI_PROMPT_BLUE = "💎"
$EMOJI_UPGRADE = "⬆️"
$EMOJI_NETWORK = "🌐"
$EMOJI_GO = "🐹"
$EMOJI_RUST = "☢️"
$EMOJI_PYTHON = "🐍"
$EMOJI_NODE = "📦"
$EMOJI_BUN = "🥟"
$EMOJI_COMPARE = "🔄"
$EMOJI_SPARKLE = "⚡"
$EMOJI_MOUSE = "🐁"

$MENU_LABELS = @(
    "Status Check"
    "Compare With Latest"
    "Upgrade All Tools"
    "Set GitHub Token"
    "Install Docker"
    "Create Fancy Prompt (Purple-Pink)"
    "Create Fancy Prompt (Shades of Blue)"
    "Install Hostname Discovery (Linux only)"
    "Install Go"
    "Install Rust"
    "Install Python + Pip + UV + Pipx"
    "Install NVM + Node LTS"
    "Install Bun"
    "Install Yarn"
    "Disable Mouse Reporting in Terminal"
    "Install PHP + Laravel"
    "Install Tailscale"
    "Install OpenCode + GSD (Rokicool) + OpenChamber"
)
$EMOJI_TOKEN = "🔑"
$EMOJI_TAILSCALE = "🔒"
$MENU_EMOJIS = @($EMOJI_STATUS, $EMOJI_COMPARE, $EMOJI_UPGRADE, $EMOJI_TOKEN, $EMOJI_DOCKER, $EMOJI_PROMPT, $EMOJI_PROMPT_BLUE, $EMOJI_NETWORK, $EMOJI_GO, $EMOJI_RUST, $EMOJI_PYTHON, $EMOJI_NODE, $EMOJI_BUN, $EMOJI_SPARKLE, $EMOJI_MOUSE, $EMOJI_PHP, $EMOJI_TAILSCALE, $EMOJI_GSD)
$MENU_INSTALL_FN = @("Get-StatusCheck", "Get-StatusCompare", "Upgrade-All", "Set-GitHubToken", "Install-Docker", "Install-FancyPrompt", "Install-FancyPromptBlue", "Install-Avahi", "Install-Go", "Install-Rust", "Install-Python", "Install-NvmNode", "Install-Bun", "Install-Yarn", "Disable-MouseReporting", "Install-PHP", "Install-Tailscale", "Install-OpenCode")
$MENU_REMOVE_FN = @("", "", "", "", "Remove-Docker", "Remove-FancyPrompt", "Remove-FancyPromptBlue", "Remove-Avahi", "Remove-Go", "Remove-Rust", "Remove-Python", "Remove-NvmNode", "Remove-Bun", "Remove-Yarn", "Enable-MouseReporting", "Remove-PHP", "Remove-Tailscale", "Remove-OpenCode")
$MENU_SINGLE_SELECT = @(0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
$Script:BATCH_MODE = $false

# Detect OS and Architecture
function Get-DetectOs {
    if ($IsWindows) { return "windows" }
    return "windows"
}

function Get-DetectArch {
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { return "arm" }
    return "x86"
}

$DETECTED_OS = Get-DetectOs
$DETECTED_ARCH = Get-DetectArch

# Detect Package Manager
function Get-PackageManager {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        return "winget"
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        return "choco"
    }
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        return "scoop"
    }
    return "winget"
}

# System Info Display
function Show-PreflightStatus {
    Write-Host ""
    Write-Host "${CYAN}$BOX_TL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H${BOX_TR}${NC}"
    Write-Host "${BOX_V} ${WHITE}Architecture:${NC} $DETECTED_ARCH                        ${BOX_V}"
    Write-Host "${BOX_V} ${WHITE}OS:${NC} Windows                                   ${BOX_V}"
    Write-Host "${BOX_V} ${WHITE}Package Mgr:${NC} $(Get-PackageManager)                            ${BOX_V}"
    Write-Host "${BOX_V} ${WHITE}Shell:${NC} PowerShell                               ${BOX_V}"
    Write-Host "${CYAN}$BOX_BL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H${BOX_BR}${NC}"
    Write-Host ""
}

$_GITHUB_TOKEN_FILE = Join-Path $env:USERPROFILE ".config\dev-fu\github-token"

function Set-GitHubToken {
    Write-Host "`n${CYAN}${EMOJI_TOKEN}  ${BOLD}Set GitHub Personal Access Token${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Increases GitHub API rate limit from 60 to 5,000 requests/hr${NC}" -ForegroundColor DarkGray
    Write-Host ""

    if (Test-Path $_GITHUB_TOKEN_FILE) {
        $cur = Get-Content $_GITHUB_TOKEN_FILE -Raw 2>$null
        if ($cur -and $cur.Trim()) {
            $t = $cur.Trim()
            $masked = $t.Substring(0,4) + "****" + $t.Substring($t.Length - 4)
            Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Token already set ($masked)" -ForegroundColor Green
        }
    }

    Write-Host "${BOLD}  How to create a GitHub Personal Access Token:${NC}" -ForegroundColor White
    Write-Host "  1. Go to ${CYAN}https://github.com/settings/tokens${NC}"
    Write-Host "  2. Click ${BOLD}Generate new token${NC} (classic)"
    Write-Host "  3. Give it a name (e.g. 'dev-fu')"
    Write-Host "  4. Select scopes: ${DIM}public_repo${NC} is enough for version checks"
    Write-Host "  5. Click ${BOLD}Generate token${NC}"
    Write-Host "  6. Copy the token (starts with ghp_)"
    Write-Host ""

    $token = Read-Host "  Paste your token (or press Enter to cancel)"
    if (-not $token) {
        Write-Host "${DIM}  Cancelled.${NC}" -ForegroundColor DarkGray
        return
    }

    $dir = Split-Path $_GITHUB_TOKEN_FILE
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $_GITHUB_TOKEN_FILE -Value $token -NoNewline

    try {
        $headers = @{ Authorization = "token $token" }
        $resp = Invoke-RestMethod -Uri "https://api.github.com/rate_limit" -Headers $headers -ErrorAction Stop
        $remaining = $resp.rate.remaining
        Write-Host "${GREEN}  Token saved — API rate limit: $remaining requests remaining${NC}" -ForegroundColor Green
    } catch {
        Write-Host "${YELLOW}  Token saved but verification failed — check if the token is valid${NC}" -ForegroundColor Yellow
    }
}

# Docker Install
function Install-Docker {
    Write-Host "${BLUE}${EMOJI_DOCKER}  ${BOLD}Install Docker${NC}" -ForegroundColor Blue
    Write-Host "${DIM}   Docker Desktop for Windows${NC}"
    Write-Host ""

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $version = docker --version 2>$null
        if ($version) {
            Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Docker already installed: $version"
            return
        }
    }

    Write-Host "${YELLOW}  → This will install: Docker Desktop${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Installing Docker via winget...${NC}"
        winget install Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Installing Docker via chocolatey...${NC}"
        choco install docker-desktop -y
    } else {
        Write-Host "${YELLOW}  Please install Docker from: https://www.docker.com/products/docker-desktop/${NC}"
    }
    Write-Host "${GREEN}  ✓ Docker installation initiated${NC}"
}

# Docker Remove
function Remove-Docker {
    Write-Host "${RED}🗑️  ${BOLD}Remove Docker${NC}"
    Write-Host ""

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "${DIM}  Docker is not installed${NC}"
        return
    }

    Write-Host "${YELLOW}  → This will remove Docker${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Removing Docker via winget...${NC}"
        winget uninstall Docker.DockerDesktop
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${RED}  Docker removal failed${NC}"
            return
        }
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Removing Docker via chocolatey...${NC}"
        choco uninstall docker-desktop -y
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${RED}  Docker removal failed${NC}"
            return
        }
    }

    Write-Host "${GREEN}  ✓ Docker removed${NC}"
}

function Reset-Prompt {
    $targets = @(
        "$env:USERPROFILE\.fancy-prompt.ps1",
        "$env:USERPROFILE\.fancy-prompt-blue.ps1"
    )
    foreach ($t in $targets) {
        if (Test-Path $t) { Remove-Item -Force $t }
    }

    $profilePath = $PROFILE
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $cleaned = $content -replace "\r?\n?\s*\.\s*['""]$([regex]::Escape("$env:USERPROFILE\.fancy-prompt.ps1"))['""]\s*", ""
            $cleaned = $cleaned -replace "\r?\n?\s*\.\s*['""]$([regex]::Escape("$env:USERPROFILE\.fancy-prompt-blue.ps1"))['""]\s*", ""
            Set-Content -Path $profilePath -Value $cleaned -NoNewline
        }
    }
}

function Write-PromptPurple($path) {
    $content = @'
#################################
#            ICONS              #
#################################

declare -A __ICONS=( \
  ["separator"]="" \
  ["local_branch"]="" \
  ["remote_branch"]="" \
  ["merged_branch"]="" \
  ["stashed"]="󰏢" \
)


#################################
#            COLORS             #
#################################

declare -A __THEME=(\
  ["default"]="-1"\
  ["fg"]="253"\
  ["bglighter"]="238"\
  ["bglight"]="237"\
  ["bg"]="236"\
  ["bgdark"]="235"\
  ["bgdarker"]="234"\
  ["violet"]="69"\
  ["selection"]="239"\
  ["subtle"]="238"\
  ["cyan"]="74"\
  ["green"]="28"\
  ["sky"]="38"\
  ["orange"]="215"\
  ["pink"]="169"\
  ["mauve"]="99"\
  ["red"]="203"\
  ["yellow"]="226"\
  ["lightgray"]="252"\
  ["white"]="255"\
)

__bg() {
  local color_code=$1
  if [ "-1" = "${color_code}" ]
  then
    echo "\\[\\e[49m\\]"
  else
    echo "\\[\\e[48;5;${color_code}m\\]"
  fi
}

__fg() {
  local color_code=$1
  if [ "-1" = "${color_code}" ]
  then
    echo "\\[\\e[39m\\]"
  else
    echo "\\[\\e[38;5;${color_code}m\\]"
  fi
}

__colorized_separator() {
  local left_color="$1"
  local right_color="$2"
  echo "$(__fg $left_color)$(__bg $right_color)${__ICONS[separator]}"
}

user_text="\u@\h"
path_text="\w"

__branch_name() {
  git rev-parse --abbrev-ref HEAD 2> /dev/null
}

__remote_branch_name() {
  is_only_local_branch=$(git branch -r 2> /dev/null | grep -c "$param_branch_name")
  if [ 0 -eq "$is_only_local_branch" ]; then echo "";fi
  local branch_name
  branch_name=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2> /dev/null | cut -d"/" -f1)
  branch_name=${branch_name:-origin}
  echo "$branch_name"
}

__branch_is_local_only() {
  local param_branch_name="$1"
  local is_only_local_branch
  is_only_local_branch=$(git branch -r 2> /dev/null | grep -c "$param_branch_name")
  if [ 0 -eq "$is_only_local_branch" ]; then return 0; fi
  return 1
}

__branch_is_merged() {
  local branch
  local merged=""
  branch=$(__branch_name)
  merged=$(git branch -r --merged master 2> /dev/null | grep "$branch" 2> /dev/null)
  if [ "" != "$merged" ]; then return 0; fi
  merged=$(git branch -r --merged develop 2> /dev/null | grep "$branch" 2> /dev/null)
  if [ "" != "$merged" ]; then return 0; fi
  merged=$(git branch -r --merged main 2> /dev/null | grep "$branch" 2> /dev/null)
  if [ "" != "$merged" ]; then return 0; else return 1; fi
}

__branch_icon() {
  local param_branch_name="$1"
  if $(__branch_is_local_only)
  then
      echo "${__ICONS[local_branch]}"
      return
  fi
  if $(__branch_is_merged)
  then
      echo "${__ICONS[merged_branch]}"
      return
  fi
  echo "${__ICONS[remote_branch]}"
}

__branch_text() {
  local branch_text=""
  if [ "" != "$(__branch_name)" ]; then branch_text="$(__branch_icon) $(__branch_name)"; fi
  echo "${branch_text}"
}

__staged() {
  git diff --name-only --cached 2> /dev/null
}

__untracked() {
  git ls-files --others --exclude-standard 2> /dev/null
}

__changed() {
  git ls-files -m 2> /dev/null
}

__stashed() {
  local msg="$(git stash list 2> /dev/null)"
  if [[ "" != "${msg}" ]]; then echo "${__ICONS[stashed]}"; else echo ""; fi
}

__unpushed() {
    local branch_name=$(__branch_name)
    local remote_name=$(__remote_branch_name)
    git log --pretty=oneline "${remote_name}"/"${branch_name}"..HEAD 2> /dev/null
}

__needs_pull() {
  local local_only=$(__branch_is_local_only)
  if [ "0" != "${local_only}" ]
  then
    echo "0"
    return 0
  fi
  local branch_name=$(__branch_name)
  if [ "" != "${branch_name}" ]
  then
    if [ $(git rev-parse HEAD) = $(git rev-parse @{u}) ]; then echo "0"; else echo "0"; fi
  else
		echo "0"
  fi
}

__venv() {
  if [ "${VIRTUAL_ENV}" ]
  then
    echo $(basename "${VIRTUAL_ENV}")
  else
    echo ""
  fi
}

__block() {
  local prev_bg="$1"
  local bg="$2"
  local fg="$3"
  local text="$4"
  local color_separator="$(__colorized_separator $prev_bg $bg)"
  local foreground="$(__fg $fg)"
  local color_text="${foreground}${text}"
  if [ "" = "${text}" ]
  then
    echo ${color_text}
  else
    echo " ${color_separator} ${color_text}"
  fi
}

__chain() {
  local blocks=("$@")
  local block
  local chain=""
  local default_background="$(__bg "${__THEME[default]}")"
  local default_fontcolor=$(__fg "${__THEME[default]}")
  local prev_background
  for raw_block in "${blocks[@]}";
  do
    local block_array
    IFS=';' block_array=($raw_block)
    local background="${block_array[0]}"
    local font_color="${block_array[1]}"
    local text="${block_array[2]}"
    if [ -z "$prev_background" ]; then prev_background=$background; fi
    if [ "" != "${text}" ]
    then
      block=$(__block "${prev_background}" "${background}" "${font_color}" "${text}")
      chain+="${block}"
      prev_background="${background}"
    fi
  done
  chain+=" $(__colorized_separator "${prev_background}" "${__THEME[default]}")"
  chain+="${default_background}${default_fontcolor} "
  echo "${chain}"
}

prompt() {
  local user="${__THEME[mauve]};${__THEME[white]};${user_text}"
  local path="${__THEME[violet]};${__THEME[white]};${path_text}"
  local branch="$(__branch_text)"
  local branch_color="${__THEME[subtle]};${__THEME[white]}"
  if [ "0" != "$(__needs_pull)" ]; then branch_color="${__THEME[red]};${__THEME[white]}"; fi
  if [ "" != "$(__unpushed)" ]; then branch_color="${__THEME[green]};${__THEME[white]}"; fi
  if [ "" != "$(__staged)" ]; then branch_color="${__THEME[yellow]};${__THEME[bgdark]}"; fi
  if [ "" != "$(__changed)" ]; then branch_color="${__THEME[orange]};${__THEME[white]}"; fi
  if [ "" != "$(__untracked)" ]; then branch_color="${__THEME[pink]};${__THEME[bgdark]}"; fi
  branch="${branch_color};${branch}"
  local stash="${__THEME[sky]};${__THEME[white]};$(__stashed)"
  local venv=$(__venv)
  if [ "" != __venv ]
  then
    venv="${__THEME[lightgray]};${__THEME[bgdark]};${venv}"
  fi
  declare -a chain=( ${user} ${path} "${stash}" "${branch}" "${venv}" )
  PS1=$(__chain "${chain[@]}")
}

PROMPT_COMMAND="prompt"
'@
    Set-Content -Path $path -Value $content -NoNewline
}

function Write-PromptBlue($path) {
    $content = @'
#!/bin/sh

bash_prompt_command() {
  local pwdmaxlen=25
  local trunc_symbol=".."
  local dir=${PWD##*/}
  pwdmaxlen=$(( ( pwdmaxlen < ${#dir} ) ? ${#dir} : pwdmaxlen ))
  NEW_PWD=${PWD/#$HOME/\~}
  local pwdoffset=$(( ${#NEW_PWD} - pwdmaxlen ))
  if [ ${pwdoffset} -gt "0" ]
  then
    NEW_PWD=${NEW_PWD:$pwdoffset:$pwdmaxlen}
    NEW_PWD=${trunc_symbol}/${NEW_PWD#*/}
  fi
}

format_font()
{
  local output=$1
  case $# in
  2)
    eval $output="'\[\033[0;${2}m\]'"
    ;;
  3)
    eval $output="'\[\033[0;${2};${3}m\]'"
    ;;
  4)
    eval $output="'\[\033[0;${2};${3};${4}m\]'"
    ;;
  *)
    eval $output="'\[\033[0m\]'"
    ;;
  esac
}

bash_prompt() {
  local      NONE='0'
  local      BOLD='1'
  local       DIM='2'
  local UNDERLINE='4'
  local     BLINK='5'
  local    INVERT='7'
  local    HIDDEN='8'

  local   DEFAULT='9'
  local     BLACK='0'
  local       RED='1'
  local     GREEN='2'
  local    YELLOW='3'
  local      BLUE='4'
  local   MAGENTA='5'
  local      CYAN='6'
  local    L_GRAY='7'
  local    D_GRAY='60'
  local     L_RED='61'
  local   L_GREEN='62'
  local  L_YELLOW='63'
  local    L_BLUE='64'
  local L_MAGENTA='65'
  local    L_CYAN='66'
  local     WHITE='67'

  local     RESET='0'
  local    EFFECT='0'
  local     COLOR='30'
  local        BG='40'

  local NO_FORMAT="\[\033[0m\]"
  local CYAN_BOLD="\[\033[1;38;5;87m\]"
  local BLUE_BOLD="\[\033[1;38;5;74m\]"

  local FONT_COLOR_1=$WHITE
  local BACKGROUND_1=$BLUE
  local TEXTEFFECT_1=$BOLD

  local FONT_COLOR_2=$WHITE
  local BACKGROUND_2=$L_BLUE
  local TEXTEFFECT_2=$BOLD

  local FONT_COLOR_3=$D_GRAY
  local BACKGROUND_3=$WHITE
  local TEXTEFFECT_3=$BOLD

  local PROMT_FORMAT=$BLUE_BOLD

  FC1=$(($FONT_COLOR_1+$COLOR))
  BG1=$(($BACKGROUND_1+$BG))
  FE1=$(($TEXTEFFECT_1+$EFFECT))

  FC2=$(($FONT_COLOR_2+$COLOR))
  BG2=$(($BACKGROUND_2+$BG))
  FE2=$(($TEXTEFFECT_2+$EFFECT))

  FC3=$(($FONT_COLOR_3+$COLOR))
  BG3=$(($BACKGROUND_3+$BG))
  FE3=$(($TEXTEFFECT_3+$EFFECT))

  local TEXT_FORMAT_1
  local TEXT_FORMAT_2
  local TEXT_FORMAT_3
  format_font TEXT_FORMAT_1 $FE1 $FC1 $BG1
  format_font TEXT_FORMAT_2 $FE2 $FC2 $BG2
  format_font TEXT_FORMAT_3 $FC3 $FE3 $BG3

  local PROMT_USER=$"$TEXT_FORMAT_1 \u "
  local PROMT_HOST=$"$TEXT_FORMAT_2 \h "
  local PROMT_PWD=$"$TEXT_FORMAT_3 \${NEW_PWD} "
  local PROMT_INPUT=$"$PROMT_FORMAT "

  TSFC1=$(($BACKGROUND_1+$COLOR))
  TSBG1=$(($BACKGROUND_2+$BG))

  TSFC2=$(($BACKGROUND_2+$COLOR))
  TSBG2=$(($BACKGROUND_3+$BG))

  TSFC3=$(($BACKGROUND_3+$COLOR))
  TSBG3=$(($DEFAULT+$BG))

  local SEPARATOR_FORMAT_1
  local SEPARATOR_FORMAT_2
  local SEPARATOR_FORMAT_3
  format_font SEPARATOR_FORMAT_1 $TSFC1 $TSBG1
  format_font SEPARATOR_FORMAT_2 $TSFC2 $TSBG2
  format_font SEPARATOR_FORMAT_3 $TSFC3 $TSBG3

  local TRIANGLE=$'\uE0B0'
  local SEPARATOR_1=$SEPARATOR_FORMAT_1$TRIANGLE
  local SEPARATOR_2=$SEPARATOR_FORMAT_2$TRIANGLE
  local SEPARATOR_3=$SEPARATOR_FORMAT_3$TRIANGLE

  case $TERM in
  xterm*|rxvt*)
    local TITLEBAR='\[\033]0;\u:${NEW_PWD}\007\]'
    ;;
  *)
    local TITLEBAR=""
    ;;
  esac

  PS1="$TITLEBAR\n${PROMT_USER}${SEPARATOR_1}${PROMT_HOST}${SEPARATOR_2}${PROMT_PWD}${SEPARATOR_3}${PROMT_INPUT}"

  none="$(tput sgr0)"
  trap 'echo -ne "${none}"' DEBUG
}

PROMPT_COMMAND=bash_prompt_command
bash_prompt
unset bash_prompt
'@
    Set-Content -Path $path -Value $content -NoNewline
}

# Fancy Prompt Install
function Install-FancyPrompt {
    Write-Host "${MAGENTA}✨  ${BOLD}Create Fancy Prompt (Purple-Pink)${NC}" -ForegroundColor Magenta
    Write-Host ""

    $target = "$env:USERPROFILE\.fancy-prompt.ps1"

    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Replace current fancy prompt? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    Reset-Prompt

    Write-PromptPurple $target

    $profilePath = $PROFILE
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    $sourceLine = ". '$target'"
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -notmatch [regex]::Escape($sourceLine)) {
        Add-Content -Path $profilePath -Value $sourceLine
    }

    . $target
    Write-Host "${GREEN}  ✓ Fancy prompt (Purple-Pink) installed${NC}"
    Write-Host "${DIM}  Run `. $PROFILE` or open a new terminal to see the prompt${NC}"
}

# Fancy Prompt Remove
function Remove-FancyPrompt {
    Write-Host "${RED}➜ Remove Fancy Prompt${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove fancy prompt? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $target = "$env:USERPROFILE\.fancy-prompt.ps1"
    if (Test-Path $target) {
        Remove-Item -Force $target
    }

    $profilePath = $PROFILE
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $cleaned = $content -replace "\r?\n?\s*\.\s*['""]$([regex]::Escape($target))['""]\s*", ""
            Set-Content -Path $profilePath -Value $cleaned -NoNewline
        }
    }

    Write-Host "${GREEN}  ✓ Fancy prompt removed${NC}"
}

function Install-FancyPromptBlue {
    Write-Host "${BLUE}${EMOJI_PROMPT_BLUE}  ${BOLD}Create Fancy Prompt (Shades of Blue)${NC}" -ForegroundColor Blue
    Write-Host ""

    $target = "$env:USERPROFILE\.fancy-prompt-blue.ps1"

    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Install blue fancy prompt? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    Reset-Prompt

    Write-PromptBlue $target

    $profilePath = $PROFILE
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    $sourceLine = ". '$target'"
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -notmatch [regex]::Escape($sourceLine)) {
        Add-Content -Path $profilePath -Value $sourceLine
    }

    . $target
    Write-Host "${GREEN}  ✓ Blue fancy prompt installed${NC}"
    Write-Host "${DIM}  Run `. $PROFILE` or open a new terminal to see the prompt${NC}"
}

function Remove-FancyPromptBlue {
    Write-Host "${RED}➜ Remove Blue Fancy Prompt${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove blue fancy prompt? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $target = "$env:USERPROFILE\.fancy-prompt-blue.ps1"
    if (Test-Path $target) {
        Remove-Item -Force $target
    }

    $profilePath = $PROFILE
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $cleaned = $content -replace "\r?\n?\s*\.\s*['""]$([regex]::Escape($target))['""]\s*", ""
            Set-Content -Path $profilePath -Value $cleaned -NoNewline
        }
    }

    Write-Host "${GREEN}  ✓ Blue fancy prompt removed${NC}"
}

# Avahi Install (Windows note)
function Install-Avahi {
    Write-Host "${CYAN}🌐  ${BOLD}Install Hostname Discovery${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   avahi-daemon (mDNS/NSS) + systemd-resolved (DNS)${NC}"
    Write-Host ""
    Write-Host "  ${RED}${EMOJI_CROSS}${NC} ${RED}This option is not available on Windows.${NC}"
    Write-Host "  ${YELLOW}  Avahi Daemon and systemd-resolved are Linux-only services.${NC}"
    Write-Host "  ${YELLOW}  Windows uses Bonjour for mDNS and has its own DNS resolver.${NC}"
    Write-Host "  ${YELLOW}  If using WSL2, run fu.sh inside the Linux distribution instead.${NC}"
}

# Avahi Remove (Windows note)
function Remove-Avahi {
    Write-Host "${RED}🗑️  ${BOLD}Remove Hostname Discovery${NC}"
    Write-Host ""
    Write-Host "  ${RED}${EMOJI_CROSS}${NC} ${RED}This option is not available on Windows.${NC}"
    Write-Host "  ${YELLOW}  Avahi Daemon and systemd-resolved are Linux-only services.${NC}"
    Write-Host "  ${YELLOW}  If using WSL2, run fu.sh inside the Linux distribution instead.${NC}"
}

# Status Check
function Get-StatusCheck {
    Write-Host "${CYAN}${EMOJI_STATUS}  ${BOLD}Status Check${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Checking developer tools...${NC}"
    Write-Host ""

    $tools = @(
        @{Name = "Docker"; Cmd = "docker"; Args = "--version"},
        @{Name = "Go"; Cmd = "go"; Args = "version"},
        @{Name = "Rustc"; Cmd = "rustc"; Args = "--version"},
        @{Name = "Cargo"; Cmd = "cargo"; Args = "--version"},
        @{Name = "Bun"; Cmd = "bun"; Args = "--version"},
        @{Name = "Node.js"; Cmd = "node"; Args = "--version"},
        @{Name = "Python"; Cmd = "python"; Args = "--version"},
        @{Name = "pip"; Cmd = "pip"; Args = "--version"},
        @{Name = "pipx"; Cmd = "pipx"; Args = "--version"},
        @{Name = "uv"; Cmd = "uv"; Args = "--version"},
        @{Name = "PHP"; Cmd = "php"; Args = "--version"},
        @{Name = "Yarn"; Cmd = "yarn"; Args = "--version"},
        @{Name = "Composer"; Cmd = "composer"; Args = "--version"}
    )

    foreach ($tool in $tools) {
        try {
            $result = & $tool.Cmd $tool.Args 2>$null
            if ($LASTEXITCODE -eq 0 -or $result) {
                $ver = if ($result) { ($result -split "`n")[0] } else { "installed" }
                Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} $($tool.Name.PadRight(12)) : ${GREEN}$ver${NC}"
            } else {
                Write-Host "  ${RED}${EMOJI_CROSS}${NC} $($tool.Name.PadRight(12)) : ${RED}NOT installed${NC}"
            }
        } catch {
            Write-Host "  ${RED}${EMOJI_CROSS}${NC} $($tool.Name.PadRight(12)) : ${RED}NOT installed${NC}"
        }
    }

    # Check NVM
    if (Get-Command nvm -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} NVM          : ${GREEN}installed${NC}"
    } else {
        Write-Host "  ${RED}${EMOJI_CROSS}${NC} NVM          : ${RED}NOT installed${NC}"
    }

    # Check OpenCode
    if (Get-Command opencode -ErrorAction SilentlyContinue) {
        $ocVer = opencode --version 2>$null
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} OpenCode     : ${GREEN}$ocVer${NC}"
    } elseif ((npm list -g opencode-ai 2>$null) -match "opencode-ai") {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} OpenCode     : ${GREEN}(npm global)${NC}"
    } else {
        Write-Host "  ${RED}${EMOJI_CROSS}${NC} OpenCode     : ${RED}NOT installed${NC}"
    }

    # Check GSD
    if (Get-Command gsd-opencode -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} GSD          : ${GREEN}installed${NC}"
    } else {
        Write-Host "  ${RED}${EMOJI_CROSS}${NC} GSD          : ${RED}NOT available${NC}"
    }

    # Check OpenChamber
    if (Get-Command openchamber -ErrorAction SilentlyContinue) {
        $ocVer = openchamber --version 2>$null
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} OpenChamber  : ${GREEN}$ocVer${NC}"
    } elseif (npm list -g @openchamber/web 2>$null) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} OpenChamber  : ${GREEN}(npm global)${NC}"
    } else {
        Write-Host "  ${RED}${EMOJI_CROSS}${NC} OpenChamber  : ${RED}NOT installed${NC}"
    }

    # Check Tailscale
    if (Get-Command tailscale -ErrorAction SilentlyContinue) {
        $tsVer = tailscale version 2>$null | Select-Object -First 1
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Tailscale    : ${GREEN}$tsVer${NC}"
    } else {
        Write-Host "  ${RED}${EMOJI_CROSS}${NC} Tailscale    : ${RED}NOT installed${NC}"
    }

    Write-Host ""
    Write-Host "${GREEN}  ✓ Status check complete${NC}"
}

function Get-StatusCompare {
    Write-Host "${CYAN}${EMOJI_COMPARE}  ${BOLD}Compare Local vs Latest Versions${NC}"
    Write-Host "${DIM}   Fetching latest versions online...${NC}"
    Write-Host ""

    function Get-GhLatest($repo) {
        $headers = @{}
        if (Test-Path $_GITHUB_TOKEN_FILE) {
            $tok = (Get-Content $_GITHUB_TOKEN_FILE -Raw 2>$null).Trim()
            if ($tok) { $headers["Authorization"] = "token $tok" }
        }

        $tag = $null
        try {
            $resp = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 10 -ErrorAction Stop
            $tag = $resp.tag_name
        } catch {}

        if (-not $tag) {
            try {
                $tags = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/tags?per_page=1" -Headers $headers -TimeoutSec 10 -ErrorAction Stop
                if ($tags -is [array]) { $tag = $tags[0].name } else { $tag = $tags.name }
            } catch {}
        }

        if (-not $tag) {
            switch ($repo) {
                "nvm-sh/nvm" {
                    try {
                        $r = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/package.json" -TimeoutSec 10 -ErrorAction Stop
                        $tag = $r.version
                    } catch {}
                }
                "astral-sh/uv" {
                    try {
                        $r = Invoke-RestMethod -Uri "https://pypi.org/pypi/uv/json" -TimeoutSec 10 -ErrorAction Stop
                        $tag = $r.info.version
                    } catch {}
                }
                "anomalyco/opencode" {
                    try {
                        $r = Invoke-RestMethod -Uri "https://registry.npmjs.org/opencode-ai/latest" -TimeoutSec 10 -ErrorAction Stop
                        $tag = $r.version
                    } catch {}
                }
                "rokicool/gsd-opencode" {
                    try {
                        $r = Invoke-RestMethod -Uri "https://registry.npmjs.org/gsd-opencode/latest" -TimeoutSec 10 -ErrorAction Stop
                        $tag = $r.version
                    } catch {}
                }
                "moby/moby" {
                    try {
                        $r = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/moby/moby/refs/heads/master/VERSION" -TimeoutSec 10 -ErrorAction Stop
                        $tag = [regex]::Match($r, '\d+\.\d+\.\d+').Value
                    } catch {}
                }
                "rust-lang/rust" {
                    try {
                        $r = Invoke-RestMethod -Uri "https://static.rust-lang.org/dist/channel-rust-stable.toml" -TimeoutSec 10 -ErrorAction Stop
                        $m = [regex]::Match($r, 'version\s*=\s*"(\d+\.\d+\.\d+)"')
                        if ($m.Success) { $tag = $m.Groups[1].Value }
                    } catch {}
                }
                "oven-sh/bun" {
                    try {
                        $r = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/oven-sh/bun/refs/heads/main/package.json" -TimeoutSec 10 -ErrorAction Stop
                        $tag = $r.version
                    } catch {}
                }
                "php/php-src" {
                    try {
                        $r = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/php/php-src/refs/heads/master/main/php_version.h" -TimeoutSec 10 -ErrorAction Stop
                        $m = [regex]::Match($r, 'PHP_VERSION\s+"(\d+\.\d+\.\d+)"')
                        if ($m.Success) { $tag = $m.Groups[1].Value }
                    } catch {}
                }
                "composer/composer" {
                    try {
                        $r = Invoke-WebRequest -Uri "https://getcomposer.org/download/" -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                        $tag = [regex]::Match($r.Content, '\d+\.\d+\.\d+').Value
                    } catch {}
                }
                "tailscale/tailscale" {
                    try {
                        $r = Invoke-RestMethod -Uri "https://pkgs.tailscale.com/stable/?mode=json" -TimeoutSec 10 -ErrorAction Stop
                        $tag = [regex]::Match(($r | ConvertTo-Json -Compress), '\d+\.\d+\.\d+').Value
                    } catch {}
                }
            }
        }

        if ($tag) {
            $tag = $tag -replace '^v', '' -replace '^docker-v', '' -replace '^bun-v', '' -replace '^php-', ''
            return $tag
        }
        return "GH-ERR:$repo"
    }

    function Get-LocalVer($cmd, $flag) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            try {
                $result = & $cmd $flag 2>$null
                if ($result) { return ($result -split "`n")[0] }
            } catch {}
        }
        return ""
    }

    function Get-VerNum($raw) {
        if ([string]::IsNullOrEmpty($raw)) { return "" }
        $m = [regex]::Match($raw, '\d+\.\d+(\.\d+)?([._-]?[a-zA-Z0-9]+)*')
        if ($m.Success) { return $m.Value }
        return ""
    }

    function Show-CompareRow($name, $localRaw, $latest) {
        $localVer = Get-VerNum $localRaw
        $lat = $latest
        $isGhErr = $latest -match '^GH-ERR:'
        if ($isGhErr) { $lat = "GH-ERR" }

        $namePad = $name.PadRight(13)

        if ($isGhErr) {
            $localDisplay = if ($localVer) { $localVer } else { "not installed" }
            Write-Host ("  {0} {1,-22} " -f $namePad, $localDisplay) -NoNewline
            Write-Host "${DIM}${lat} (rate limited)${NC}"
        } elseif ([string]::IsNullOrEmpty($localRaw)) {
            Write-Host ("  {0} {1,-22} {2,-16} " -f $namePad, "not installed", $lat) -NoNewline
            Write-Host "${DIM}—${NC}"
        } elseif ([string]::IsNullOrEmpty($latest)) {
            Write-Host ("  {0} {1,-22} {2,-16} " -f $namePad, $localVer, "—") -NoNewline
            Write-Host "${DIM}?${NC}"
        } elseif ([string]::IsNullOrEmpty($localVer)) {
            Write-Host ("  {0} {1,-22} {2,-16} " -f $namePad, "?", $lat) -NoNewline
            Write-Host "${DIM}?${NC}"
        } elseif ($localVer -eq $latest) {
            Write-Host ("  {0} {1,-22} {2,-16} " -f $namePad, $localVer, $lat) -NoNewline
            Write-Host "${GREEN}✓ up to date${NC}"
        } else {
            Write-Host ("  {0} {1,-22} {2,-16} " -f $namePad, $localVer, $lat) -NoNewline
            Write-Host "${YELLOW}⬆ update available${NC}"
        }
    }

    Write-Host "  ${BOLD}Tool           Installed              Latest           Status${NC}"
    Write-Host "  $('─' * 70)"

    Show-CompareRow "Docker"   (Get-LocalVer docker "--version")       (Get-GhLatest "moby/moby")

    $goLatest = ""
    try {
        $goResp = Invoke-RestMethod -Uri "https://go.dev/dl/?mode=json" -TimeoutSec 5 -ErrorAction Stop
        $goLatest = $goResp[0].version -replace '^go', ''
    } catch {}
    Show-CompareRow "Go"       (Get-LocalVer go "version")              $goLatest

    Show-CompareRow "Rust"     (Get-LocalVer rustc "--version")        (Get-GhLatest "rust-lang/rust")
    Show-CompareRow "Bun"      (Get-LocalVer bun "--version")          (Get-GhLatest "oven-sh/bun")

    $nvmLocal = ""
    if (Get-Command nvm -ErrorAction SilentlyContinue) {
        $nvmLocal = "nvm $(nvm version 2>$null)"
    }
    Show-CompareRow "NVM"      $nvmLocal                                (Get-GhLatest "nvm-sh/nvm")

    $nodeLatest = ""
    try {
        $nodeResp = Invoke-RestMethod -Uri "https://nodejs.org/dist/index.json" -TimeoutSec 5 -ErrorAction Stop
        $nodeLatest = $nodeResp[0].version -replace '^v', ''
    } catch {}
    Show-CompareRow "Node.js"  (Get-LocalVer node "--version")          $nodeLatest
    Show-CompareRow "npx"      (Get-LocalVer npx "--version")           ""

    $pyLatest = ""
    try {
        $pyResp = Invoke-RestMethod -Uri "https://endoflife.date/api/python.json" -TimeoutSec 5 -ErrorAction Stop
        $pyLatest = $pyResp[0].latest
    } catch {}
    Show-CompareRow "Python"   (Get-LocalVer python "--version")        $pyLatest
    Show-CompareRow "uv"       (Get-LocalVer uv "--version")            (Get-GhLatest "astral-sh/uv")

    $yarnLatest = ""
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $yarnLatest = npm view yarn version 2>$null
    }
    Show-CompareRow "Yarn"     (Get-LocalVer yarn "--version")          $yarnLatest
    Show-CompareRow "PHP"      (Get-LocalVer php "--version")          (Get-GhLatest "php/php-src")
    Show-CompareRow "Composer" (Get-LocalVer composer "--version")      (Get-GhLatest "composer/composer")
    Show-CompareRow "Tailscale" (Get-LocalVer tailscale "version")      (Get-GhLatest "tailscale/tailscale")
    Show-CompareRow "OpenCode"  (Get-LocalVer opencode "--version")     (Get-GhLatest "anomalyco/opencode")

    $ocLocal = Get-LocalVer openchamber "--version"
    if ([string]::IsNullOrEmpty($ocLocal) -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        $npmList = npm list -g @openchamber/web 2>$null
        if ($npmList -match "openchamber") { $ocLocal = "npm global" }
    }
    $ocLatest = ""
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $ocLatest = npm view @openchamber/web version 2>$null
    }
    Show-CompareRow "OpenChamber" $ocLocal $ocLatest

    $gsdLocal = ""
    if (Get-Command gsd-opencode -ErrorAction SilentlyContinue) {
        $gsdLocal = gsd-opencode --version 2>$null | Select-Object -First 1
    }
    Show-CompareRow "GSD"      $gsdLocal                                (Get-GhLatest "rokicool/gsd-opencode")

    Write-Host "  $('─' * 70)"
    Write-Host ""
    Write-Host "${GREEN}  ✓ Comparison complete${NC}"
}

function Install-Go {
    Write-Host "${CYAN}${EMOJI_GO}  ${BOLD}Install Go${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Go programming language${NC}"
    Write-Host ""

    if (Get-Command go -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Go already installed: $(go version)"
        return
    }

    Write-Host "${YELLOW}  → This will install: Go${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Installing Go via winget...${NC}"
        winget install GoLang.Go --accept-source-agreements --accept-package-agreements
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Installing Go via chocolatey...${NC}"
        choco install go -y
    }
    Write-Host "${GREEN}  ✓ Go installed${NC}"
}

function Remove-Go {
    Write-Host "${RED}🗑️  ${BOLD}Remove Go${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove Go? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        winget uninstall GoLang.Go
    } elseif ($pkgMgr -eq "choco") {
        choco uninstall go -y
    }
    Write-Host "${GREEN}  ✓ Go removed${NC}"
}

function Install-Rust {
    Write-Host "${CYAN}${EMOJI_RUST}  ${BOLD}Install Rust${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Rust programming language via rustup${NC}"
    Write-Host ""

    if (Get-Command rustc -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Rust already installed: $(rustc --version)"
        return
    }

    Write-Host "${YELLOW}  → This will install: Rust (rustup, rustc, cargo)${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Installing Rust via winget...${NC}"
        winget install Rustlang.Rust --accept-source-agreements --accept-package-agreements
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Installing Rust via chocolatey...${NC}"
        choco install rust -y
    }
    Write-Host "${GREEN}  ✓ Rust installed${NC}"
}

function Remove-Rust {
    Write-Host "${RED}🗑️  ${BOLD}Remove Rust${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove Rust? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    if (Get-Command rustup -ErrorAction SilentlyContinue) {
        rustup self uninstall -y
    } else {
        $pkgMgr = Get-PackageManager
        if ($pkgMgr -eq "winget") {
            winget uninstall Rustlang.Rust
        } elseif ($pkgMgr -eq "choco") {
            choco uninstall rust -y
        }
    }
    Write-Host "${GREEN}  ✓ Rust removed${NC}"
}

function Install-Python {
    Write-Host "${CYAN}${EMOJI_PYTHON}  ${BOLD}Install Python + Pip + UV + Pipx${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Python 3 with pip, uv package manager, and pipx${NC}"
    Write-Host ""

    $needInstall = $false
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) { $needInstall = $true }
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { $needInstall = $true }

    if (-not $needInstall) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Python + UV already installed"
        return
    }

    Write-Host "${YELLOW}  → This will install: Python 3, pip, uv, pipx${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager

    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        if ($pkgMgr -eq "winget") {
            Write-Host "${CYAN}  Installing Python via winget...${NC}"
            winget install Python.Python.3.11 --accept-source-agreements --accept-package-agreements
        } elseif ($pkgMgr -eq "choco") {
            Write-Host "${CYAN}  Installing Python via chocolatey...${NC}"
            choco install python -y
        }
    }

    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Host "${CYAN}  Installing uv...${NC}"
        $uvInstalled = $false

        try {
            Write-Host "${DIM}    Trying standalone installer...${NC}"
            powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" 2>$null
            if (Get-Command uv -ErrorAction SilentlyContinue) { $uvInstalled = $true }
        } catch {}

        if (-not $uvInstalled -and (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host "${DIM}    Trying winget...${NC}"
            winget install --id=astral-sh.uv -e --accept-source-agreements --accept-package-agreements 2>$null
            if (Get-Command uv -ErrorAction SilentlyContinue) { $uvInstalled = $true }
        }

        if (-not $uvInstalled -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
            Write-Host "${DIM}    Trying scoop...${NC}"
            scoop install main/uv 2>$null
            if (Get-Command uv -ErrorAction SilentlyContinue) { $uvInstalled = $true }
        }

        if (-not $uvInstalled -and (Get-Command pipx -ErrorAction SilentlyContinue)) {
            Write-Host "${DIM}    Trying pipx...${NC}"
            pipx install uv 2>$null
            if (Get-Command uv -ErrorAction SilentlyContinue) { $uvInstalled = $true }
        }

        if (-not $uvInstalled -and (Get-Command pip -ErrorAction SilentlyContinue)) {
            Write-Host "${DIM}    Trying pip...${NC}"
            pip install uv 2>$null
            if (Get-Command uv -ErrorAction SilentlyContinue) { $uvInstalled = $true }
        }

        if (-not $uvInstalled) {
            Write-Host "${RED}  ✗ uv install failed — no supported install method available${NC}"
        }
    }

    Write-Host "${GREEN}  ✓ Python + Pip + UV + Pipx installed${NC}"
}

function Remove-Python {
    Write-Host "${RED}🗑️  ${BOLD}Remove Python + Pip + UV + Pipx${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove Python, pip, uv, and pipx? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        winget uninstall Python.Python.3.11
    } elseif ($pkgMgr -eq "choco") {
        choco uninstall python -y
    }

    $uvPath = "$env:USERPROFILE\.local\bin\uv.exe"
    $uvData = "$env:USERPROFILE\.local\share\uv"
    if (Test-Path $uvPath) { Remove-Item -Force $uvPath }
    if (Test-Path $uvData) { Remove-Item -Recurse -Force $uvData }
    Write-Host "${GREEN}  ✓ Python + Pip + UV + Pipx removed${NC}"
}

function Install-NvmNode {
    Write-Host "${CYAN}${EMOJI_NODE}  ${BOLD}Install NVM + Node LTS${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Node Version Manager with latest LTS${NC}"
    Write-Host ""

    if ((Get-Command nvm -ErrorAction SilentlyContinue) -and (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} NVM + Node already installed: $(node --version)"
        return
    }

    Write-Host "${YELLOW}  → This will install: NVM + Node.js LTS${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Installing Node.js LTS via winget...${NC}"
        winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Installing Node.js LTS via chocolatey...${NC}"
        choco install nodejs-lts -y
    }

    Write-Host "${GREEN}  ✓ NVM + Node LTS installed${NC}"
}

function Remove-NvmNode {
    Write-Host "${RED}🗑️  ${BOLD}Remove NVM + Node${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove NVM and Node.js? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        winget uninstall OpenJS.NodeJS.LTS
    } elseif ($pkgMgr -eq "choco") {
        choco uninstall nodejs -y
    }
    Write-Host "${GREEN}  ✓ NVM + Node removed${NC}"
}

# Bun Install
function Install-Bun {
    Write-Host "${CYAN}${EMOJI_BUN}  ${BOLD}Install Bun${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Fast JavaScript runtime & package manager${NC}"
    Write-Host ""

    if (Get-Command bun -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Bun already installed: $(bun --version)"
        return
    }

    Write-Host "${YELLOW}  → This will install: Bun${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    Write-Host "${CYAN}  Installing Bun...${NC}"
    powershell -c "irm bun.sh/install.ps1 | iex"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  Bun install failed${NC}"
        return
    }
    Write-Host "${GREEN}  ✓ Bun installed${NC}"
}

# Bun Remove
function Remove-Bun {
    Write-Host "${RED}🗑️  ${BOLD}Remove Bun${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove Bun? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $bunPath = "$env:USERPROFILE\.bun"
    if (Test-Path $bunPath) {
        Remove-Item -Recurse -Force $bunPath
    }
    Write-Host "${GREEN}  ✓ Bun removed${NC}"
}

# Yarn Install
function Install-Yarn {
    Write-Host "${CYAN}${EMOJI_SPARKLE}  ${BOLD}Install Yarn${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Fast, reliable dependency management${NC}"
    Write-Host ""

    if (Get-Command yarn -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Yarn already installed: $(yarn --version)"
        return
    }

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Host "  ${RED}${EMOJI_CROSS} npm missing - install NVM + Node LTS first (option 12)${NC}"
        return
    }

    Write-Host "${YELLOW}  → This will install: Yarn${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    Write-Host "${CYAN}  Installing Yarn...${NC}"
    npm install -g yarn
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  Yarn install failed${NC}"
        return
    }
    Write-Host "${GREEN}  ✓ Yarn installed${NC}"
}

# Yarn Remove
function Remove-Yarn {
    Write-Host "${RED}🗑️  ${BOLD}Remove Yarn${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove Yarn? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    npm uninstall -g yarn 2>$null
    Write-Host "${GREEN}  ✓ Yarn removed${NC}"
}

# Disable Mouse Reporting
function Disable-MouseReporting {
    Write-Host "${CYAN}${EMOJI_SPARKLE}  ${BOLD}Disable Mouse Reporting in Terminal${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Prevents terminal mouse events from interfering with CLI tools${NC}"
    Write-Host ""

    $profilePath = $PROFILE
    $mouseLine = 'Write-Host "$([char]27)[?1000l$([char]27)[?1002l$([char]27)[?1003l$([char]27)[?1006l" -NoNewline'

    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($content -and $content -match '\?\s*1000l.*\?\s*1002l.*\?\s*1006l') {
            Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Mouse reporting already disabled in profile"
            return
        }
    }

    Write-Host "${YELLOW}  → This will add mouse disable commands to your PowerShell profile${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    Add-Content -Path $profilePath -Value $mouseLine
    Write-Host "${GREEN}  ✓ Mouse reporting disabled${NC}"
}

# Enable Mouse Reporting
function Enable-MouseReporting {
    Write-Host "${RED}🗑️  ${BOLD}Re-enable Mouse Reporting${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Re-enable mouse reporting? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $profilePath = $PROFILE
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $cleaned = $content -replace "(?m)^\s*Write-Host.*\?\s*1000l.*\?\s*1006l.*-NoNewline\s*\r?\n?", ""
            Set-Content -Path $profilePath -Value $cleaned -NoNewline
        }
    }
    Write-Host "${GREEN}  ✓ Mouse reporting re-enabled${NC}"
}

# Tailscale Install
function Install-Tailscale {
    Write-Host "${CYAN}${EMOJI_TAILSCALE}  ${BOLD}Install Tailscale${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Mesh VPN — connect devices across networks${NC}"
    Write-Host ""

    if (Get-Command tailscale -ErrorAction SilentlyContinue) {
        $ver = tailscale version 2>$null | Select-Object -First 1
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Tailscale already installed: $ver"
        return
    }

    if (-not $Script:BATCH_MODE) {
        Write-Host "${BYELLOW}  -> This will install Tailscale${NC}"
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    Write-Host "${CYAN}  Installing Tailscale...${NC}"
    try {
        winget install Tailscale.Tailscale --accept-package-agreements --accept-source-agreements -ErrorAction Stop
    } catch {
        Write-Host "${RED}  Tailscale install failed${NC}"
        return
    }

    Write-Host "${GREEN}  ✓ Tailscale installed${NC}"
    Write-Host "${DIM}  Run 'tailscale up' to connect${NC}"
}

# Tailscale Remove
function Remove-Tailscale {
    Write-Host "${RED}➜ Remove Tailscale${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove Tailscale? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    try {
        winget uninstall Tailscale.Tailscale -ErrorAction Stop
    } catch {
        Write-Host "${RED}  Tailscale removal failed${NC}"
        return
    }

    Write-Host "${GREEN}  ✓ Tailscale removed${NC}"
}

# OpenCode + GSD Install
function Install-OpenCode {
    Write-Host "${MAGENTA}${EMOJI_GSD}  ${BOLD}Install OpenCode + GSD (Rokicool) + OpenChamber${NC}" -ForegroundColor Magenta
    Write-Host "${DIM}   AI-powered development environment${NC}"
    Write-Host ""

    $opencodeInstalled = $false
    if (Get-Command opencode -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} OpenCode already installed"
        $opencodeInstalled = $true
    } else {
        Write-Host "${YELLOW}  → OpenCode will be installed${NC}"
    }

    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Host "${YELLOW}  → Node.js required — installing first...${NC}"
        $pkgMgr = Get-PackageManager
        if ($pkgMgr -eq "winget") {
            Write-Host "${CYAN}  Installing Node.js LTS via winget...${NC}"
            winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
        } elseif ($pkgMgr -eq "choco") {
            Write-Host "${CYAN}  Installing Node.js LTS via chocolatey...${NC}"
            choco install nodejs-lts -y
        }
    }

    if (-not $opencodeInstalled) {
        if (-not $Script:BATCH_MODE) {
            $confirm = Read-Host "  Proceed? (y/n)"
            if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
        }
    }

    Write-Host "${CYAN}  Installing OpenCode...${NC}"
    npm install -g opencode-ai
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  OpenCode install failed${NC}"
        return
    }

    Write-Host "${CYAN}  Installing GSD...${NC}"
    npx gsd-opencode@latest
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  GSD install failed${NC}"
        return
    }

    Write-Host "${CYAN}  Installing OpenChamber...${NC}"
    npm install -g @openchamber/web
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  OpenChamber install failed${NC}"
        return
    }

    Write-Host ""
    Write-Host "${GREEN}  ✓ OpenCode + GSD + OpenChamber installed successfully${NC}"
}

# OpenCode Remove
function Remove-OpenCode {
    Write-Host "${RED}🗑️  ${BOLD}Remove OpenCode${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove OpenCode? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }
    npm uninstall -g opencode-ai @openchamber/web
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  OpenCode removal failed${NC}"
        return
    }
    Write-Host "${GREEN}  ✓ OpenCode removed${NC}"
}

# GSD Remove
function Remove-GSD {
    Write-Host "${RED}🗑️  ${BOLD}Remove GSD${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove GSD? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }
    if (Get-Command gsd-opencode -ErrorAction SilentlyContinue) {
        gsd-opencode uninstall
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${RED}  GSD removal failed${NC}"
            return
        }
    } else {
        Write-Host "${YELLOW}  GSD not found${NC}"
        return
    }
    Write-Host "${GREEN}  ✓ GSD removed${NC}"
}

# Upgrade All Tools
function Upgrade-All {
    Write-Host "${BCYAN}⬆️  ${BOLD}Upgrade All Tools${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Updating installed developer tools...${NC}"
    Write-Host ""

    $upgraded = $false

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading Docker...${NC}"
        $pkgMgr = Get-PackageManager
        if ($pkgMgr -eq "winget") {
            winget upgrade Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
        } elseif ($pkgMgr -eq "choco") {
            choco upgrade docker-desktop -y
        }
        $upgraded = $true
    }

    if (Get-Command rustup -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading Rust...${NC}"
        rustup update
        $upgraded = $true
    }

    if (Get-Command node -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading Node.js...${NC}"
        if (Get-Command nvm -ErrorAction SilentlyContinue) {
            nvm install latest
            nvm use latest
        } else {
            Write-Host "${YELLOW}  NVM not found — consider installing it to manage Node versions${NC}"
        }
        $upgraded = $true
    }

    if (Get-Command bun -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading Bun...${NC}"
        powershell -c "irm bun.sh/install.ps1 | iex"
        $upgraded = $true
    }

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading Yarn...${NC}"
        npm upgrade -g yarn
        $upgraded = $true
    }

    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading uv...${NC}"
        uv self update
        $upgraded = $true
    }

    if (Get-Command php -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading PHP...${NC}"
        $pkgMgr = Get-PackageManager
        if ($pkgMgr -eq "winget") {
            winget upgrade PHP.PHP --accept-source-agreements --accept-package-agreements
        } elseif ($pkgMgr -eq "choco") {
            choco upgrade php -y
        }
        $upgraded = $true
    }

    if ((Get-Command opencode -ErrorAction SilentlyContinue) -or ((npm list -g opencode-ai 2>$null) -match "opencode-ai")) {
        Write-Host "${CYAN}  Upgrading OpenCode...${NC}"
        $ocOk = $false
        $ocOfficial = Join-Path $HOME ".opencode/bin/opencode.exe"
        if (Get-Command curl -ErrorAction SilentlyContinue) {
            try {
                $tmp = New-TemporaryFile
                Invoke-WebRequest -UseBasicParsing -Uri "https://opencode.ai/install" -OutFile "$tmp.ps1" -ErrorAction Stop
                & "$tmp.ps1" *>$null
                Remove-Item "$tmp.ps1" -ErrorAction SilentlyContinue
                if ((Test-Path $ocOfficial) -and (& $ocOfficial --version 2>$null)) {
                    $ocOk = $true
                }
            } catch {}
            if (-not $ocOk) {
                try {
                    npm upgrade -g opencode-ai *>$null
                    if (Get-Command opencode -ErrorAction SilentlyContinue) { $ocOk = $true }
                } catch {}
            }
        } else {
            try {
                npm upgrade -g opencode-ai *>$null
                if (Get-Command opencode -ErrorAction SilentlyContinue) { $ocOk = $true }
            } catch {}
        }
        if ($ocOk) {
            $upgraded = $true
            $ocVer = ((& $ocOfficial --version 2>$null) -replace "`r`n","" -replace "`n","")
            if (-not $ocVer) { $ocVer = (opencode --version 2>$null) -replace "`r`n","" -replace "`n","" }
            if (-not $ocVer) { $ocVer = "updated" }
            Write-Host "${DIM}  OpenCode: ${NC}$ocVer"
        } else {
            Write-Host "${YELLOW}  OpenCode upgrade failed${NC}"
        }
    }

    if ((Get-Command openchamber -ErrorAction SilentlyContinue) -or ((npm list -g @openchamber/web 2>$null) -match "openchamber")) {
        Write-Host "${CYAN}  Upgrading OpenChamber...${NC}"
        npm upgrade -g @openchamber/web
        $upgraded = $true
    }

    if (Get-Command tailscale -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading Tailscale...${NC}"
        try {
            winget upgrade Tailscale.Tailscale --accept-source-agreements --accept-package-agreements -ErrorAction Stop
        } catch {
            Write-Host "${YELLOW}  Tailscale upgrade failed${NC}"
        }
        $upgraded = $true
    }

    if (Get-Command gsd-opencode -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading GSD...${NC}"
        npx gsd-opencode@latest 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${YELLOW}  GSD upgrade failed${NC}"
        }
        $upgraded = $true
    }

    if (-not $upgraded) {
        Write-Host "  ${YELLOW}${EMOJI_ARROW} No installed tools found to upgrade. Install tools first (options 5+).${NC}"
    } else {
        Write-Host ""
        Write-Host "${GREEN}  ✓ Upgrade complete${NC}"
    }
}

# PHP + Laravel Install
function Install-PHP {
    Write-Host "${MAGENTA}🐘  ${BOLD}Install PHP + Laravel${NC}" -ForegroundColor Magenta
    Write-Host "${DIM}   PHP 8.x with Laravel installer${NC}"
    Write-Host ""

    if (Get-Command php -ErrorAction SilentlyContinue) {
        $version = php --version 2>$null | Select-Object -First 1
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} PHP already installed: $version"
        return
    }

    Write-Host "${YELLOW}  → This will install: PHP 8.x, Composer, Laravel installer${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Installing PHP via winget...${NC}"
        winget install PHP.PHP --accept-source-agreements --accept-package-agreements
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Installing PHP via chocolatey...${NC}"
        choco install php -y
    }

    Write-Host ""
    Write-Host "${GREEN}  ✓ PHP installed${NC}"
}

# PHP Remove
function Remove-PHP {
    Write-Host "${RED}🗑️  ${BOLD}Remove PHP + Laravel${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove PHP and Laravel? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        winget uninstall PHP.PHP
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${RED}  PHP removal failed${NC}"
            return
        }
    } elseif ($pkgMgr -eq "choco") {
        choco uninstall php -y
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${RED}  PHP removal failed${NC}"
            return
        }
    }

    Write-Host "${GREEN}  ✓ PHP and Laravel removed${NC}"
}

# Show Menu
function Show-Menu {
    Clear-Host

    Write-Host "${MAGENTA}"
    Write-Host "  ██╗ ██╗██████╗ ███████╗██╗   ██╗      ███████╗██╗   ██╗"
    Write-Host " ██╔╝██╔╝██╔══██╗██╔════╝██║   ██║      ██╔════╝██║   ██║"
    Write-Host " ╚═╝ ██╔╝██║  ██║█████╗  ██║   ██║█████╗█████╗  ██║   ██║"
    Write-Host " ██╔╝██╔╝ ██║  ██║██╔══╝  ╚██╗ ██╔╝╚════╝██╔══╝  ██║   ██║"
    Write-Host " ╚═╝██╔╝██╔╝   ██████╔╝███████╗ ╚████╔╝       ██║     ╚██████╔╝"
    Write-Host "     ╚═╝ ╚═╝    ╚═════╝ ╚══════╝  ╚═══╝        ╚═╝      ╚═════╝"
    Write-Host "${NC}"

    Write-Host "${CYAN}$BOX_TL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H${BOX_TR}${NC}"
    Write-Host "${BOX_V} ${BOLD}${WHITE}Environment Setup Utility${NC}                  ${BOX_V}"
    Write-Host "${CYAN}$BOX_BL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H${BOX_BR}${NC}"
    Write-Host ""

    for ($i = 0; $i -lt $MENU_LABELS.Count; $i++) {
        $num = $i + 1
        $pad = if ($num -lt 10) { " " } else { "" }
        if ($i -eq 4) {
            Write-Host "${BOX_V} ${GREEN}${DIM}$num${NC}${DIM})${pad} $($MENU_EMOJIS[$i])  $($MENU_LABELS[$i])${NC}"
        } else {
            Write-Host "${BOX_V} ${GREEN}$num${NC})${pad} $($MENU_EMOJIS[$i])  $($MENU_LABELS[$i])"
        }
    }
    Write-Host ""
    Write-Host "${DIM}  Enter your selected options, split by commas or spaces (1,2 3 4)${NC}"
    Write-Host "${DIM}  Enter -N to remove (e.g. -3 removes Docker)${NC}"
    Write-Host ""

    Write-Host "${CYAN}$BOX_TL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H${BOX_TR}${NC}"
    Write-Host "${BOX_V}${DIM}  Press ${BOLD}q${NC}${DIM} to quit              ${BOX_V}"
    Write-Host "${CYAN}$BOX_BL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H${BOX_BR}${NC}"

    Write-Host -NoNewline -ForegroundColor Cyan "▸ Choice: "
}

function Parse-Input {
    param([string]$RawInput)

    $Script:InstallIndices = @()
    $Script:RemoveIndices = @()

    if ([string]::IsNullOrWhiteSpace($RawInput)) {
        Write-Host "${YELLOW}No selection made. Enter numbers (1-18) or 'q' to quit.${NC}"
        return $false
    }

    $tokens = $RawInput -split '[,\s]+' | Where-Object { $_ -ne '' }

    if ($tokens.Count -eq 0) {
        Write-Host "${YELLOW}No selection made. Enter numbers (1-18) or 'q' to quit.${NC}"
        return $false
    }

    $candidates = @()
    $errors = @()
    foreach ($token in $tokens) {
        if ($token -match '^-?[1-9]$' -or $token -match '^-?1[0-8]$') {
            $candidates += $token
        } else {
            $errors += $token
        }
    }

    if ($errors.Count -gt 0) {
        if ($errors.Count -eq 1) {
            Write-Host "${RED}Invalid: '$($errors[0])' is not a valid option (1-18)${NC}"
        } else {
            $errorStr = ($errors | ForEach-Object { "'$_'" }) -join ', '
            Write-Host "${RED}Invalid: $errorStr are not valid options (1-18)${NC}"
        }
        return $false
    }

    $seen = @{}
    $unique = @()
    foreach ($token in $candidates) {
        if (-not $seen.ContainsKey($token)) {
            $seen[$token] = $true
            $unique += $token
        }
    }

    $addIndices = @()
    $rmIndices = @()
    foreach ($token in $unique) {
        if ($token.StartsWith('-')) {
            $num = $token.TrimStart('-')
            $rmIndices += [int]$num - 1
        } else {
            $addIndices += [int]$token - 1
        }
    }

    foreach ($ridx in $rmIndices) {
        if ($addIndices -contains $ridx) {
            $clabel = $MENU_LABELS[$ridx] -replace '^(Install|Create) ',''
            Write-Host "${RED}Cannot both install and remove $clabel${NC}"
            return $false
        }
    }

    $totalCount = $addIndices.Count + $rmIndices.Count
    if ($totalCount -gt 1) {
        foreach ($idx in $addIndices) {
            if ($MENU_SINGLE_SELECT[$idx] -eq 1) {
                Write-Host "${RED}Option $($idx + 1) ($($MENU_LABELS[$idx])) must be used alone${NC}"
                return $false
            }
        }
        foreach ($idx in $rmIndices) {
            if ($MENU_SINGLE_SELECT[$idx] -eq 1) {
                Write-Host "${RED}Option $($idx + 1) ($($MENU_LABELS[$idx])) must be used alone${NC}"
                return $false
            }
        }
    }

    foreach ($idx in $rmIndices) {
        if ($MENU_REMOVE_FN[$idx] -eq '') {
            $rlabel = $MENU_LABELS[$idx] -replace '^(Install|Create) ',''
            Write-Host "${RED}Cannot remove $rlabel — no remove operation available${NC}"
            return $false
        }
    }

    $Script:InstallIndices = $addIndices
    $Script:RemoveIndices = $rmIndices
    return $true
}

function Show-ConfirmationScreen {
    $total = $Script:InstallIndices.Count + $Script:RemoveIndices.Count

    if ($total -eq 0) { return $false }
    if ($total -eq 1) { return $true }

    Write-Host "${BOLD}${WHITE}Operations to execute:${NC}"

    $boxInner = 54
    $border = "${BOX_TL}" + ($BOX_H * $boxInner) + "${BOX_TR}"
    Write-Host "${CYAN}${border}${NC}"

    $num = 1
    foreach ($idx in $Script:InstallIndices) {
        $label = "$($MENU_EMOJIS[$idx])  $($MENU_LABELS[$idx])"
        $padded = $label.PadRight($boxInner - 5).Substring(0, $boxInner - 5)
        Write-Host "${BOX_V} ${GREEN}${num}) ${padded}${NC} ${BOX_V}"
        $num++
    }
    foreach ($idx in $Script:RemoveIndices) {
        $label = "$($MENU_EMOJIS[$idx])  $($MENU_LABELS[$idx])"
        $padded = $label.PadRight($boxInner - 6).Substring(0, $boxInner - 6)
        Write-Host "${BOX_V} ${RED}-${num}) ${padded}${NC} ${BOX_V}"
        $num++
    }

    $bottom = "${BOX_BL}" + ($BOX_H * $boxInner) + "${BOX_BR}"
    Write-Host "${CYAN}${bottom}${NC}"

    Write-Host "${YELLOW}Run ${total} operations? (y/n)${NC}"
    $confirm = Read-Host "  ▸"
    if ($confirm -notin @('y','Y')) {
        Write-Host "${DIM}  Cancelled.${NC}"
        return $false
    }
    return $true
}

# CLI mode: run non-interactively if args passed
# Usage: .\fu.ps1 3 5 -9   (upgrade all, install docker, remove go)
if ($args.Count -gt 0) {
    $Script:BATCH_MODE = $true
    $cliInput = $args -join " "

    if ($cliInput -eq "u" -or $cliInput -eq "U") {
        Upgrade-All
        exit 0
    }

    if (Parse-Input $cliInput) {
        foreach ($idx in $Script:InstallIndices) {
            if ($idx -eq 7) { continue }
            & $MENU_INSTALL_FN[$idx]
        }
        foreach ($idx in $Script:RemoveIndices) {
            & $MENU_REMOVE_FN[$idx]
        }
    }
    exit 0
}

# Main loop (interactive)
while ($true) {
    Show-PreflightStatus
    Show-Menu
    $choice = Read-Host
    Write-Host ""

    if ($choice -eq "q" -or $choice -eq "Q") {
        Write-Host "${MAGENTA}Goodbye — stay productive! ${EMOJI_HEART}${NC}"
        break
    }

    if ($choice -eq "u" -or $choice -eq "U") {
        Upgrade-All
    } else {
        if (Parse-Input $choice) {
            if (Show-ConfirmationScreen) {
                if ($Script:InstallIndices -contains 7) {
                    Write-Host "${YELLOW}Hostname Discovery is not available on Windows${NC}"
                    $Script:InstallIndices = @($Script:InstallIndices | Where-Object { $_ -ne 7 })
                }
                $Script:BATCH_MODE = $true
                foreach ($idx in $Script:InstallIndices) {
                    & $MENU_INSTALL_FN[$idx]
                }
                foreach ($idx in $Script:RemoveIndices) {
                    & $MENU_REMOVE_FN[$idx]
                }
                $Script:BATCH_MODE = $false
            }
        }
    }

    Write-Host ""
    $null = Read-Host "  Press Enter to continue..."
}
#!/usr/bin/env bash

# Claude Code statusline script
# Reads JSON input from stdin and outputs a formatted status line to stdout
# Add to your ~/.claude/settings.json
#
# "statusLine": {
#   "type": "command",
#   "command": "bash ~/.claude/statusline-command.sh"
# }
#

DEBUG="${STATUSLINE_DEBUG:-0}"

# Color codes for better visual separation
readonly BLUE='\033[94m'      # Bright blue for model/main info
readonly GREEN='\033[92m'     # Bright green for clean git status
readonly YELLOW='\033[93m'    # Bright yellow for modified git status
readonly RED='\033[91m'       # Bright red for conflicts/errors
readonly PURPLE='\033[95m'    # Bright purple for directory
readonly CYAN='\033[96m'      # Bright cyan for python venv
readonly WHITE='\033[97m'     # Bright white for time
readonly GRAY='\033[37m' # Gray for separators
readonly RESET='\033[0m'      # Reset colors
readonly BOLD='\033[1m'       # Bold text

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON input using jq
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "."')
version=$(echo "$input" | jq -r '.version // "?.?.?"')

# Get current directory relative to home directory with smart truncation
if [[ "$current_dir" == "$HOME"* ]]; then
    # Replace home path with ~ for display
    dir_display="${current_dir/#$HOME/~}"
else
    # Keep full path if not under home directory
    dir_display="$current_dir"
fi

# Smart path truncation - show beginning and end for context
if [[ ${#dir_display} -gt 50 ]]; then
    # For very long paths, show important parts
    if [[ "$dir_display" == "~"/* ]]; then
        # Keep home indicator and last parts
        # shellcheck disable=SC2088  # We want literal ~ for display, not expansion
        dir_display="~/.../$(basename "$(dirname "$current_dir")")/$(basename "$current_dir")"
    else
        # Show first and last directory
        dir_display="...$(echo "$dir_display" | grep -o '/[^/]*/[^/]*$')"
    fi

    # If still too long, just show current directory
    if [[ ${#dir_display} -gt 50 ]]; then
        dir_display="...$(basename "$current_dir")"
    fi
fi

# Git status
git_info=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git branch --show-current 2>/dev/null)
    git_dirty=""
    
    # Check if there are any changes
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        git_dirty="*"
    fi
    
    git_info="${git_branch}${git_dirty}"
fi


# print_string <key> <value> <color>
# Colors the VALUE (bold) using <color>; key stays default.
print_string() {
    local key="$1"
    local value="$2"
    local color="$3"
    # key then a space, then colored+bold value, then reset
    printf '%s %b%s%b' "${GRAY}$key" "${color}${BOLD}" "$value"
}

# gray separator: " | "
print_separator() {
    printf ' %b|%b ' "$GRAY"
}

# output_string=" ${BLUE}${RESET} ${BOLD}${BLUE}${model_name}${RESET} ${GRAY}│${RESET} ${PURPLE}📁${dir_display}${RESET}"
output_string="$(
  print_string 'model:' "$model_name" "$RED"
  print_separator
  print_string 'dir:' "$dir_display" "$BLUE"
)"

# Add git info if present
if [[ -n "$git_info" ]]; then
    output_string="${output_string}$(
      print_separator
      print_string '' " $git_info" "$YELLOW"
    )"
fi

output_string="${output_string}$(
  print_separator
  print_string '' "v$version" "$GRAY"
)"

# Output the complete string
echo -e "$output_string"

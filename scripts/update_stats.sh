#!/usr/bin/env bash
set -e

# Configuration
USERNAME="eayushsingh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Fetching live GitHub metrics for $USERNAME..."

# Fetch user public stats
USER_JSON=$(curl -s "https://api.github.com/users/$USERNAME")
PUBLIC_REPOS=$(echo "$USER_JSON" | grep -o '"public_repos": [0-9]*' | awk '{print $2}')
FOLLOWERS=$(echo "$USER_JSON" | grep -o '"followers": [0-9]*' | awk '{print $2}')

# Fallbacks if API rate limited or empty
if [ -z "$PUBLIC_REPOS" ]; then PUBLIC_REPOS="45"; fi
if [ -z "$FOLLOWERS" ]; then FOLLOWERS="14"; fi

# Fetch repositories to sum stars
REPOS_JSON=$(curl -s "https://api.github.com/users/$USERNAME/repos?per_page=100")
STARS=$(echo "$REPOS_JSON" | grep -o '"stargazers_count": [0-9]*' | awk '{sum += $2} END {print (sum == "" ? 0 : sum)}')
if [ "$STARS" -eq 0 ] 2>/dev/null; then
  STARS_DISPLAY="★"
else
  STARS_DISPLAY="$STARS"
fi

echo "Metrics: Repos: $PUBLIC_REPOS | Followers: $FOLLOWERS | Stars: $STARS_DISPLAY"

# Generate fresh SVG
cd "$REPO_ROOT"
perl "$SCRIPT_DIR/build_full_svg.pl" "$PUBLIC_REPOS" "$STARS_DISPLAY" "$FOLLOWERS"
echo "assets/terminal.svg synchronized successfully!"

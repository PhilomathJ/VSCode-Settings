# VSCode-Settings Sync

## Description

Settings and config files I use across profiles and workspaces

## How it works

- The VSCode profiles directories are actually symlinked from this cloned repo to their native loaction in `~/.config/Code/User/profiles`
- There exists a shell function stages the contens of the `profiles` directory within this repo then commits, and pushes
- To address newly-created profiles (which VSCode creates normally directly within the `~/.config/Code/User/profiles`)
  - There is a shell script that compares the contents of `~/.config/Code/User/profiles` to the contents of the `profiles` dir within the repo
  - If a new repo exists that is not yet in the repo, it moves the dir to the repo then symlinks it back to the VSCode dir
  - The shell function runs this script each time to ensure it is always pushing all profiles available

### The shell function

<details open>
    <summary>Shell function</summary>

```sh
# This gets run by the user directly whenever a sync to the repo is needed
function vscode-sync-profiles() {
  local REPO_DIR=$HOME/code/vscode-settings
  local SYNC_SCRIPT=$REPO_DIR/scripts/sync-profiles.sh

  # Ensure the repo directory exists
  if [ ! -d "$REPO_DIR" ]; then
    echo "Error: Repository directory not found at '$REPO_DIR'." >$2
    exit 1
  fi

  # Ensure the sync script exists
  if [ ! -f "$SYNC_SCRIPT" ]; then
    echo "Error: Sync script not found at '$SYNC_SCRIPT'." >$2
    exit 1
  fi

  # Sync the VSCode profile folders to the repo
  $SYNC_SCRIPT

  # Enter the repo directory
  cd $REPO_DIR || return

  # Perform Git operations
  git add .
  git commit -m "Syncing profiles: $(date +'%Y-%m-%d %H:%M')"
  git push

  # Return to previous directory
  cd - >/dev/null
}
```

</details>

### The shell script

<details open>
    <summary>Shell script</summary>

```sh
#!/bin/bash
# This script location: ~/code/vscode-settings/scripts/sync-profiles.sh

# Paths
VSCODE_DIR="$HOME/.config/Code/User/profiles"
REPO_DIR="$HOME/code/vscode-settings"
PROFILES_DIR="$REPO_DIR/profiles"
STORAGE_FILE="$HOME/.config/Code/User/globalStorage/storage.json"

# Check if the repository dir and storage.json exists
if [ ! -d "$PROFILES_DIR" ]; then
  echo "Error: Repo profiles directory $PROFILES_DIR not found!" >$2
  exit 1
fi
if [ ! -f "$STORAGE_FILE" ]; then
  echo "Error: $STORAGE_FILE not found!" >$2
  exit 1
fi

# Parse storage.json to get the list of profile Name -> ID mappings
# This requires 'jq' (sudo pacman -S jq or sudo apt install jq)
mappings=$(jq -r '.userDataProfiles[] | "\(.name):\(.location)"' "$STORAGE_FILE")

echo "Found the following profile mappings within VSCode:"
echo "$mappings"
echo "--------------------------------------"

# Use a do loop with IFS to handle spaces correctly
echo "$mappings" | while IFS=':' read -r NAME ID_PATH; do
  [ -z "$NAME" ] && continue

  # Sanitize the name for the filesystem (replace spaces with dashes)
  # e.g., "3D Printing" becomes "3D-Printing"
  SAFE_NAME=$(echo "$NAME" | sed 's/ /-/g')

  # Use -- to prevent IDs starting with '-' from being treated as flags
  ID_FOLDER=$(basename -- "$ID_PATH")
  echo "ID_FOLDER: $ID_FOLDER"

  # Skip Default
  if [ "$NAME" == "Default" ] || [ "$ID_FOLDER" == "User" ]; then
    continue
  fi

  # Check if already in Repo
  # if not, move and link
  if [ ! -d "$PROFILES_DIR/$SAFE_NAME" ]; then
    # Profile not found in repo, processing...
    echo "Processing: $NAME ($ID_FOLDER)"

    if [ -d "$VSCODE_DIR/$ID_FOLDER" ]; then
      # Move data to Repo
      echo "Moving data to repository..."
      # echo "mv -- "$VSCODE_DIR/$ID_FOLDER" "$PROFILES_DIR/$SAFE_NAME""
      mv -- "$VSCODE_DIR/$ID_FOLDER" "$PROFILES_DIR/$SAFE_NAME"

      # Link it back
      echo "Creating symlink..."
      # echo "ln -s "$PROFILES_DIR/$SAFE_NAME" "$VSCODE_DIR/$ID_FOLDER""
      ln -s "$PROFILES_DIR/$SAFE_NAME" "$VSCODE_DIR/$ID_FOLDER"

      echo "Successfully linked $NAME."
    else
      echo "Warning: Folder $ID_FOLDER not found for $NAME"
    fi
  else
    echo "Skipping: $NAME (Already linked)"
  fi
done
```

</details>

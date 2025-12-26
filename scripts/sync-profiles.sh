#!/bin/bash

# This script location: ~/code/vscode-settings/scripts/sync-profiles.sh

# Paths
VSCODE_DIR="$HOME/.config/Code/User/profiles"
REPO_DIR="$HOME/code/vscode-settings"
PROFILES_DIR="$REPO_DIR/profiles"
STORAGE_FILE="$HOME/.config/Code/User/globalStorage/storage.json"

#0.5 Check if the repository dir and storage.json exists
if [ ! -d "$PROFILES_DIR" ]; then
  echo "Error: Repo profiles directory $PROFILES_DIR not found!" >$2
  exit 1
fi
if [ ! -f "$STORAGE_FILE" ]; then
  echo "Error: $STORAGE_FILE not found!" >$2
  exit 1
fi
# 1. Parse storage.json to get the list of profile Name -> ID mappings
# This requires 'jq' (sudo pacman -S jq or sudo apt install jq)
mappings=$(jq -r '.userDataProfiles[] | "\(.name):\(.location)"' "$STORAGE_FILE")

echo "Found the following profile mappings within VSCode:"
echo "$mappings"
echo "--------------------------------------"

# 2. Use a do loop with IFS to handle spaces correctly
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

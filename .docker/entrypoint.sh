#!/bin/sh -l
CONFIG_PATH=$3
LUACHECK_ARGS="--default-config $CONFIG_PATH $1"
LUACHECK_PATH="$2"
LUACHECK_CAPTURE_OUTFILE="$GITHUB_WORKSPACE/$4"
LUACHECK_EXIT_ON_WARN="$5"
ONLY_CHANGED="$7"

# extra luacheck definitions
if [[ ! -z "$6" ]]; then
  OLD_DIR=$(pwd)
  # regenerate with extras
  cd /luacheck-fivem/
  yarn build "$6"
  # go back
  cd $OLD_DIR
fi

EXIT_CODE=0

echo "Args => 1: $1, 2: $2, 3: $3, 4: $4, 5: $5, 6: $6, 7: $7"

cd $GITHUB_WORKSPACE

# Detect changed resources if only_changed is enabled
if [ "$ONLY_CHANGED" = "true" ]; then
  echo "Detecting changed resource folders..."

  # Get the list of changed files
  if [[ ! -z "$GITHUB_BASE_REF" ]]; then
    # For PRs, compare against the base branch
    git fetch origin "$GITHUB_BASE_REF" --depth=1
    CHANGED_FILES=$(git diff --name-only "origin/$GITHUB_BASE_REF" HEAD)
  elif [[ ! -z "$GITHUB_EVENT_BEFORE" ]] && [ "$GITHUB_EVENT_BEFORE" != "0000000000000000000000000000000000000000" ]; then
    # For pushes with previous commit available
    CHANGED_FILES=$(git diff --name-only "$GITHUB_EVENT_BEFORE" HEAD)
  else
    # Fallback: compare with HEAD~1
    CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || git ls-files)
  fi

  echo "Changed files:"
  echo "$CHANGED_FILES"

  # Extract unique resource folders (first two directory levels)
  # Resources are typically in [category]/resource_name/ format
  RESOURCE_FOLDERS=$(echo "$CHANGED_FILES" | grep -E '\.lua$' | cut -d'/' -f1-2 | sort -u)

  if [ -z "$RESOURCE_FOLDERS" ]; then
    echo "No Lua files changed, skipping lint"
    exit 0
  fi

  echo "Resource folders to lint:"
  echo "$RESOURCE_FOLDERS"

  # Convert newlines to spaces for luacheck
  LUACHECK_PATH=$(echo "$RESOURCE_FOLDERS" | tr '\n' ' ')
  echo "Updated lint paths: $LUACHECK_PATH"
fi

echo "outfile => $LUACHECK_CAPTURE_OUTFILE"

if [[ ! -z "$LUACHECK_CAPTURE_OUTFILE" ]]; then
  echo "exec => luacheck $LUACHECK_ARGS $LUACHECK_PATH 2>>$LUACHECK_CAPTURE_OUTFILE"
  luacheck --operators "+=" $LUACHECK_ARGS $LUACHECK_PATH >$LUACHECK_CAPTURE_OUTFILE 2>&1 || true

  echo "exec => luacheck $LUACHECK_ARGS --formatter default $LUACHECK_PATH"
  luacheck --operators "+=" $LUACHECK_ARGS --formatter default $LUACHECK_PATH || EXIT_CODE=$?
else
  echo "exec => luacheck $LUACHECK_ARGS $LUACHECK_PATH"
  luacheck --operators "+=" $LUACHECK_ARGS $LUACHECK_PATH || EXIT_CODE=$?
fi

echo "exit => $EXIT_CODE"
if [ "$LUACHECK_EXIT_ON_WARN" = true ]; then
 exit $EXIT_CODE
elif [ $EXIT_CODE -ge 2 ]; then
 exit $EXIT_CODE
fi

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a GitHub Action that runs `luacheck` on Lua codebases with FiveM native functions support. It fetches FiveM natives from the runtime API, generates a `.luacheckrc` configuration file with proper global definitions, and runs luacheck in a Docker container. The action supports FiveM Lua backtick syntax and provides JUnit reporting for GitHub Actions.

## Build and Development Commands

### Build the luacheck configuration
```bash
# Install dependencies
yarn install

# Generate .luacheckrc.default from template
yarn build

# With extra library definitions (e.g., esx+ox_lib)
yarn build "esx+ox_lib"
```

### Format code
```bash
yarn format
```

### Run tests locally
```bash
# Generate config first
node -r ts-node/register ./generate-rc.ts

# Run luacheck on test files
luacheck --config .luacheckrc.default -t tests/
```

### Build Docker image
```bash
docker build -t fivem-lua-lint-action .
```

## Architecture

### Core Components

**generate-rc.ts** - The build script that:
1. Fetches FiveM natives from two endpoints:
   - `https://runtime.fivem.net/doc/natives_cfx.json` (CFX natives)
   - `https://runtime.fivem.net/doc/natives.json` (GTA/RDR natives)
2. Categorizes natives by apiset: `shared`, `client`, or `server`
3. Converts native names from MACRO_CASE to CamelCase using `macroCaseToSnake()`
4. Replaces placeholders in `.luacheckrc.template`:
   - `%%SHARED_GLOBALS%%` - shared natives
   - `%%SERVER_GLOBALS%%` - server-only natives
   - `%%CLIENT_GLOBALS%%` - client-only natives
   - `%%EXTRA%%` - optional library definitions (e.g., `+esx+ox_lib`)
5. Outputs `.luacheckrc.default` for the Docker container

**.luacheckrc.template** - Luacheck configuration template containing:
- Standard definitions for FiveM (`cfx`, `cfx_sv`, `cfx_cl`, `cfx_manifest`)
- Framework-specific definitions (ESX, QBox, QB-Core)
- Library definitions (MySQL, PolyZone, MenuV, ox_lib)
- File pattern matching for auto-detection:
  - `**/fxmanifest.lua` → manifest standard
  - `**/client.lua`, `**/cl_*.lua`, `**/client/**/*.lua` → client standard
  - `**/server.lua`, `**/sv_*.lua`, `**/server/**/*.lua` → server standard
  - `**/shared.lua`, `**/shared/**/*.lua` → shared standard
- Custom operators support: `+=`, `-=`, `*=`, `/=`

**.docker/entrypoint.sh** - Docker entrypoint that:
1. Accepts action inputs as positional arguments ($1-$7)
2. Regenerates `.luacheckrc.default` if extra_libs are provided (arg $6)
3. Detects changed resources if `only_changed=true` (arg $7):
   - For PRs: compares against base branch using `GITHUB_BASE_REF`
   - For pushes: compares against previous commit using `GITHUB_EVENT_BEFORE`
   - Filters for changed `.lua` files
   - Extracts unique resource folders (first 2 directory levels: `category/resource_name/`)
   - Overrides `LUACHECK_PATH` to only lint changed resources
   - Exits early with code 0 if no `.lua` files changed
4. Runs luacheck with `--operators "+="` flag for custom operators
5. Handles output capture to JUnit XML or other formats
6. Manages exit codes: exits with code 0 on warnings (unless fail_on_warnings=true), exits with code ≥2 on errors

**Dockerfile** - Multi-stage build:
1. Base: `ghcr.io/illeniumstudios/luacheck:v1.1.1-fivem-lua-v1.3.1` (custom luacheck with FiveM backtick support)
2. Installs Node.js and Yarn
3. Runs `yarn build` to generate default config
4. Sets entrypoint to `.docker/entrypoint.sh`

**action.yml** - GitHub Action definition with inputs:
- `args`: luacheck CLI arguments (default: `-t`)
- `paths`: directory to lint (default: `.`)
- `config_path`: config file location (default: `/luacheck-fivem/.luacheckrc.default`)
- `capture`: output file for results (e.g., `junit.xml`)
- `extra_libs`: additional library definitions in format `a+b+c`
- `fail_on_warnings`: whether to fail on warnings (default: `false`)
- `only_changed`: only lint changed resources by detecting changed `.lua` files and linting entire resource folders (default: `false`)

### Build Flow

1. User triggers action in their repository
2. Docker container starts from published image
3. If `extra_libs` provided, entrypoint regenerates config via `yarn build "$extra_libs"`
4. Entrypoint runs luacheck with generated config on user's codebase
5. Results captured to file (if specified) and/or printed to console
6. Action exits with appropriate code based on findings and `fail_on_warnings` setting

### Test Structure

`tests/` directory contains sample FiveM resources:
- `fxmanifest.lua` - FiveM resource manifest
- `shared.lua` - shared code
- `client/` - client-side test scripts
- `server/` - server-side test scripts

Tests verify that luacheck correctly recognizes FiveM natives and framework globals based on file patterns.

## CI/CD

- **ci.yml**: Runs on all pushes/PRs, builds Docker image and runs tests
- **multi-arch.yaml**: Publishes multi-architecture Docker images (amd64/arm64) to GitHub Container Registry on version tags (v*)

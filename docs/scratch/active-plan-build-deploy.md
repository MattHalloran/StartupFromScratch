# Active Plan: Update build.sh and deploy.sh

## Goals

- Align CLI scaffolding with `setup.sh` and `develop.sh`
- Support multiple build outputs/sources and local/remote destinations

## Steps

1. Update `scripts/main/build.sh`
   - Add `usage()` with `-o|--output`, `-d|--dest`, and `-h|--help` flags
   - Parse into `OUTPUTS` array and `DEST` variable
   - Loop over `OUTPUTS`, calling appropriate build functions (e.g., `build_packages`, `package_cli`, `zip_artifacts`)
   - Implement local (`DEST=local`) copy to `dist/$out/`, and placeholder for remote upload

2. Update `scripts/main/deploy.sh`
   - Add `usage()` with `-s|--source`, `-t|--target`, `-d|--dest`, and `-h|--help` flags
   - Parse into `SOURCES` array, `TARGET`, and `DEST` variables
   - Loop over `SOURCES`, unpack artifacts locally or pull from remote, then call `deploy_*` functions

3. Source required helper scripts and maintain existing logging and error handling
4. Add TODO placeholders for new platform logic and remote operations
5. Ensure backward compatibility: default behaviors when flags are omitted
6. Verify correctness by testing locally

## File Locations

- `scripts/main/build.sh`
- `scripts/main/deploy.sh` 
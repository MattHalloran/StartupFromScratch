#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/locations.sh"
# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/log.sh"

# Zips a folder into a tarball
zip::folder() {
    local folder="$1"
    local outfile="$2"
    log::info "Zipping folder $folder into $outfile..."
    tar -czf "$outfile" "$folder"
    log::success "Zipped folder $folder into $outfile"
}

# Unzips a tarball into a folder
zip::unzip() {
    local infile="$1"
    local outdir="$2"
    log::info "Unzipping $infile into $outdir..."
    tar -xzf "$infile" -C "$outdir"
    log::success "Unzipped $infile into $outdir"
}

zip::compress() {
    local infile="$1"
    local outfile="$2"
    log::info "Compressing $infile into $outfile..."
    gzip -f "$infile"
    log::success "Compressed $infile into $outfile"
}

zip::decompress() {
    local infile="$1"
    local outdir="$2"
    log::info "Decompressing $infile into $outdir..."
    tar -xzf "$infile" -C "$outdir" --strip-components=1
    log::success "Decompressed $infile into $outdir"
}

zip::build_artifacts() {
    local outdir="$1"
    log::info "Copy build artifacts to $outdir..."
  
    mkdir -p "$outdir"
    # Copy (not zip - that happens later) each package's dist folder
    for pkg in "${PACKAGES_DIR}/"*; do
        if [ -d "$pkg/dist" ]; then
            log::info "Copying $(basename "$pkg") distribution..."
            cp -r "$pkg/dist" "$outdir/$(basename "$pkg")-dist"
        fi
    done
} 

zip::copy_project_files() {
    local outdir="$1"
    log::info "Copying project files to $outdir..."

    mkdir -p "$outdir"
    cp "${ROOT_DIR}/package.json" "$outdir"
    cp "${ROOT_DIR}/pnpm-lock.yaml" "$outdir"
    cp "${ROOT_DIR}/pnpm-workspace.yaml" "$outdir"
}

zip::copy_project() {
    local outdir="$1"
    mkdir -p "$outdir"
    log::header "Preparing project (minus Docker/Kubernetes files) for deployment..."
    zip::copy_project_files "$outdir"
    zip::build_artifacts "$outdir"
    log::success "Project artifacts have been copies to $outdir"
}

zip::artifacts() {
    local folder="$1"
    local outdir="$2"
    log::info "Zipping and compressing build artifacts to ${outdir}..."
    mkdir -p "${outdir}"
    zip::folder "${folder}" "${outdir}/artifacts.zip"
    trap "rm -f ${outdir}/artifacts.zip" EXIT
    zip::compress "${outdir}/artifacts.zip" "${outdir}/artifacts.zip.gz"
    log::success "Created tarball: ${outdir}/artifacts.zip.gz"
}
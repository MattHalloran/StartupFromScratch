#!/usr/bin/env bash
# This script handles the creation of the Twilio domain verification file.

BUILD_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/log.sh"
# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/var.sh"

twilio_verification::create_verification_file() {
    log::info "Checking for Twilio domain verification setup..."

    if [ -z "${TWILIO_DOMAIN_VERIFICATION_CODE-}" ]; then
        log::warning "TWILIO_DOMAIN_VERIFICATION_CODE is not set. Skipping creation of Twilio domain verification file."
        log::warning "This file might be needed to send SMS messages with Twilio."
        return 0
    fi

    log::info "Creating Twilio domain verification file (${TWILIO_DOMAIN_VERIFICATION_CODE}.html)..."

    # IMPORTANT WARNING FROM ORIGINAL SCRIPT:
    # This probably won't work as expected when serving, as it's an HTML file.
    # The application server might interpret it as a page route that doesn't exist.
    # If this happens, a DNS TXT record should be used instead:
    # Host: _twilio
    # Type: TXT
    # Value: (the content that would have been in this file, i.e., twilio-domain-verification=YOUR_CODE)
    log::warning "---------------------------------------------------------------------------------"
    log::warning "TWILIO VERIFICATION FILE WARNING:"
    log::warning "The created ${TWILIO_DOMAIN_VERIFICATION_CODE}.html file might not be served correctly by the web server."
    log::warning "If Twilio verification via this HTML file fails, consider using a DNS TXT record instead."
    log::warning "(Host: _twilio, Type: TXT, Value: twilio-domain-verification=${TWILIO_DOMAIN_VERIFICATION_CODE})"
    log::warning "---------------------------------------------------------------------------------"

    local ui_dist_dir="${var_ROOT_DIR}/packages/ui/dist"
    local verification_file_name="${TWILIO_DOMAIN_VERIFICATION_CODE}.html"
    local verification_file_path="${ui_dist_dir}/${verification_file_name}"

    # Ensure the packages/ui/dist directory exists
    if [ ! -d "${ui_dist_dir}" ]; then
        log::error "Directory ${ui_dist_dir} not found. Cannot create Twilio verification file."
        log::error "This usually means 'build_packages' did not run or failed."
        return 1
    fi

    # No need to create a subdirectory like .well-known, file goes in ui/dist directly.

    # Create the verification file
    if echo "twilio-domain-verification=${TWILIO_DOMAIN_VERIFICATION_CODE}" > "${verification_file_path}"; then
        log::success "Successfully created ${verification_file_path}"
    else
        log::error "Failed to create ${verification_file_path}"
        return 1
    fi

    return 0
} 
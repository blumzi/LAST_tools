#!/bin/bash
#
# deb_insert_meta.sh
#
# Inserts CI metadata into all deb files in parent directory
# Intended for use with:
# `dpkg-buildpackage --hook-buildinfo='fakeroot deb_insert_meta.sh'`
# which is the first hook after the binary deb files are generated
# but before checksums for .changes are calculated
# Should be called with 'fakeroot' so that the repacked binaries
# have their content/control ownership/permissions preserved.

pushd .. > /dev/null || exit 1

    for deb_file in *.deb; do
        [ -e "$deb_file" ] || continue

        DEB_TMPDIR=$(mktemp -d)
        if [ -z "${DEB_TMPDIR}" ]; then
            echo "Failed to create a temporary work directory"
            exit 1
        fi

        dpkg-deb -R "${deb_file}" "${DEB_TMPDIR}"

        if [ -e "${DEB_TMPDIR}/DEBIAN/control" ]; then
            if [ -n "${CI_PROJECT_PATH}" ]; then
                echo "Git-Repo: ${CI_PROJECT_PATH}" >> "${DEB_TMPDIR}/DEBIAN/control"
            fi
            if [ -n "${CI_COMMIT_SHA}" ]; then
                echo "Git-Hash: ${CI_COMMIT_SHA}" >> "${DEB_TMPDIR}/DEBIAN/control"
            fi
            if [ -n "${CI_COMMIT_BRANCH}" ]; then
                echo "Git-Branch: ${CI_COMMIT_BRANCH}" >> "${DEB_TMPDIR}/DEBIAN/control"
            fi

            dpkg-deb -b "${DEB_TMPDIR}" "${deb_file}"

        fi

        rm -rf "${DEB_TMPDIR}"

    done

popd > /dev/null || exit 1

exit 0

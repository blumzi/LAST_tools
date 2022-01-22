PACKAGE_VERSION=1.0.0
PACKAGE_NAME=last-tool-${PACKAGE_VERSION}
PACKAGE_DIR=packaging/${PACKAGE_NAME}
SHELL=bash

package: clean
	mkdir -m 755 -p ${PACKAGE_DIR}/usr/local/share/last-tool ${PACKAGE_DIR}/usr/local/bin ${PACKAGE_DIR}/etc/profile.d
	tar cf - --exclude=LAST-CONTAINER ./bin ./lib ./files ./sections | (cd ${PACKAGE_DIR}/usr/local/share/last-tool ; tar xf -)
	ln -sf /usr/local/share/last-tool/bin/last-tool ${PACKAGE_DIR}/usr/local/bin/last-tool
	ln -sf /usr/local/share/last-tool/bin/last-fetch-from-github ${PACKAGE_DIR}/usr/local/bin/last-fetch-from-github
	ln -sf /usr/local/share/last-tool/files/last.sh ${PACKAGE_DIR}/etc/profile.d/last.sh
	mkdir -m 755 ${PACKAGE_DIR}/DEBIAN
	install -m 644 debian/control ${PACKAGE_DIR}/DEBIAN/control
	install -m 644 debian/changelog ${PACKAGE_DIR}/DEBIAN/changelog
	install -m 755 debian/rules ${PACKAGE_DIR}/DEBIAN/rules
	cd packaging; dpkg --build ${PACKAGE_NAME}
	mv packaging/*.deb .
	${MAKE} clean

clean:
	/bin/rm -rf packaging

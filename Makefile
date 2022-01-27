PACKAGE_VERSION=1.0.0
PACKAGE_NAME=last-tool-${PACKAGE_VERSION}
PACKAGE_DIR=packaging/${PACKAGE_NAME}
SHELL=bash
FSTYPE=$(shell mapfile -t type < <(df --output=fstype .); echo $${type[1]})

package: clean
	mkdir -m 755 -p ${PACKAGE_DIR}/usr/local/share/last-tool ${PACKAGE_DIR}/usr/local/bin ${PACKAGE_DIR}/etc/profile.d
	tar cf - --exclude=LAST-CONTAINER ./bin ./lib ./files ./sections | (cd ${PACKAGE_DIR}/usr/local/share/last-tool ; tar xf -)
	chmod 755 ${PACKAGE_DIR}/usr/local/share/last-tool/*	
ifeq (${FSTYPE},fuse.vmhgfs-fuse)
	mkdir -p ${PACKAGE_DIR}/usr/local/bin ${PACKAGE_DIR}/etc/profile.d
	install -m 755 ${PACKAGE_DIR}/usr/local/share/last-tool/bin/last-tool ${PACKAGE_DIR}/usr/local/bin/last-tool
	install -m 755 ${PACKAGE_DIR}/usr/local/share/last-tool/bin/last-fetch-from-github ${PACKAGE_DIR}/usr/local/bin/last-fetch-from-github
	install -m 644 ${PACKAGE_DIR}//usr/local/share/last-tool/files/last.sh ${PACKAGE_DIR}/etc/profile.d/last.sh
else
	ln -sf /usr/local/share/last-tool/bin/last-tool ${PACKAGE_DIR}/usr/local/bin/last-tool
	ln -sf /usr/local/share/last-tool/bin/last-fetch-from-github ${PACKAGE_DIR}/usr/local/bin/last-fetch-from-github
	ln -sf /usr/local/share/last-tool/files/last.sh ${PACKAGE_DIR}/etc/profile.d/last.sh
endif
	mkdir -m 755 ${PACKAGE_DIR}/DEBIAN
	install -m 644 debian/control ${PACKAGE_DIR}/DEBIAN/control
	install -m 644 debian/changelog ${PACKAGE_DIR}/DEBIAN/changelog
	install -m 755 debian/rules ${PACKAGE_DIR}/DEBIAN/rules	
ifeq (${FSTYPE},fuse.vmhgfs-fuse)
	cd packaging; dpkg-deb  --nocheck --build ${PACKAGE_NAME}
else
	cd packaging; dpkg-deb --build ${PACKAGE_NAME}
endif
	mv packaging/*.deb .
	${MAKE} clean

clean:
	/bin/rm -rf packaging

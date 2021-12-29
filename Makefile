PACKAGE_VERSION=1.0.0
PACKAGE_NAME=last-tool-${PACKAGE_VERSION}
PACKAGE_DIR=packaging/${PACKAGE_NAME}
SHELL=bash

package:
	/bin/rm -rf packaging
	mkdir -p ${PACKAGE_DIR}/usr/local/share/last-tool ${PACKAGE_DIR}/usr/local/bin ${PACKAGE_DIR}/etc/profile.d
	tar cf - --exclude=LAST-DEPLOYER ./bin ./lib ./files ./sections | (cd ${PACKAGE_DIR}/usr/local/share/last-tool ; tar xf -)
	ln -sf /usr/local/share/last-tool/bin/last-tool ${PACKAGE_DIR}/usr/local/bin/last-tool
	ln -sf /usr/local/share/last-tool/bin/last-fetch-from-github ${PACKAGE_DIR}/usr/local/bin/last-fetch-from-github
	ln -sf /usr/local/share/last-tool/files/last.sh ${PACKAGE_DIR}/etc/profile.d/last.sh
	mkdir ${PACKAGE_DIR}/DEBIAN
	cp debian/{control,rules,compat,changelog} ${PACKAGE_DIR}/DEBIAN
	cd packaging; dpkg --build ${PACKAGE_NAME}
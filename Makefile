PACKAGE_VERSION=1.0.0
PACKAGE_NAME=last-tool-${PACKAGE_VERSION}
PACKAGE_DIR=packaging/${PACKAGE_NAME}
SHELL=bash

package:
	/bin/rm -rf packaging
	mkdir -p ${PACKAGE_DIR}
	tar cf - ./bin ./lib ./files ./sections | (cd ${PACKAGE_DIR} ; tar xf -)
	mkdir ${PACKAGE_DIR}/debian
	cp debian/{control,rules,compat,changelog} ${PACKAGE_DIR}/debian
	cd ${PACKAGE_DIR}; dpkg-buildpackage --build=all -d -nc
	#cd ${PACKAGE_DIR}; dh_make --indep --createorig
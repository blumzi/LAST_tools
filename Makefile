PACKAGE_VERSION=1.0.0
PACKAGE_NAME=last-tool-${PACKAGE_VERSION}
PACKAGE_DIR=packaging/${PACKAGE_NAME}
SHELL=bash

VMWARE = 
ifeq ($(shell mapfile -t type < <(df --output=fstype .); echo $${type[1]}),fuse.vmhgfs-fuse)
	VMWARE = true
endif

package: LAST_TOP  = /usr/local/share/last-tool
package: LOCAL_TOP = /usr/local
package: clean check-for-github-tokens
	mkdir -m 755 -p ${PACKAGE_DIR}/${LAST_TOP} ${PACKAGE_DIR}/${LOCAL_TOP}/bin ${PACKAGE_DIR}/etc/profile.d
	tar cf - --exclude=LAST-CONTAINER ./bin ./lib ./files ./sections | (cd ${PACKAGE_DIR}/${LAST_TOP} ; tar xf -)
	chmod 755 ${PACKAGE_DIR}/${LAST_TOP}/*	
ifeq (${VMWARE},true)
	mkdir -p ${PACKAGE_DIR}/${LOCAL_TOP}/bin ${PACKAGE_DIR}/etc/profile.d
	install -m 755 ${PACKAGE_DIR}/${LAST_TOP}/bin/last-tool 				${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-tool
	install -m 755 ${PACKAGE_DIR}/${LAST_TOP}/bin/last-pswitch 				${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-pswitch
	install -m 755 ${PACKAGE_DIR}/${LAST_TOP}/bin/last-lights 				${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-lights
	install -m 755 ${PACKAGE_DIR}/${LAST_TOP}/bin/last-matlab 				${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-matlab
	install -m 755 ${PACKAGE_DIR}/${LAST_TOP}/bin/last-matlab 				${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-matlab-R2022a
	install -m 755 ${PACKAGE_DIR}/${LAST_TOP}/bin/last-hosts 				${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-hosts
	install -m 755 ${PACKAGE_DIR}/${LAST_TOP}/bin/last-fetch-from-github	${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-fetch-from-github
	install -m 644 ${PACKAGE_DIR}/${LAST_TOP}/files/last.sh 				${PACKAGE_DIR}/etc/profile.d/last.sh
	install -m 644 ${PACKAGE_DIR}/${LAST_TOP}/files/root/etc/systemd/system/last-pipeline.service 	${PACKAGE_DIR}/etc/systemd/system/last-pipeline.service
else
	ln -sf ${LAST_TOP}/bin/last-tool 						${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-tool
	ln -sf ${LAST_TOP}/bin/last-matlab 						${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-matlab
	ln -sf ${LAST_TOP}/bin/last-matlab 						${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-matlab-R2022a
	ln -sf ${LAST_TOP}/bin/last-hosts 						${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-hosts
	ln -sf ${LAST_TOP}/bin/last-pswitch 					${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-pswitch
	ln -sf ${LAST_TOP}/bin/last-lights 						${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-lights
	ln -sf ${LAST_TOP}/bin/last-ds9-feeder 					${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-ds9-feeder
	ln -sf ${LAST_TOP}/bin/last-ds9		 					${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-ds9
	ln -sf ${LAST_TOP}/bin/last-fetch-from-github 			${PACKAGE_DIR}/${LOCAL_TOP}/bin/last-fetch-from-github
	ln -sf ${LAST_TOP}/files/root/etc/profile.d/last.sh 	${PACKAGE_DIR}/etc/profile.d/last.sh
	mkdir -p  ${PACKAGE_DIR}/etc/systemd/system
	ln -sf ${LAST_TOP}/files/root/etc/systemd/system/last-pipeline.service 	${PACKAGE_DIR}/etc/systemd/system/last-pipeline.service
endif
	@(  \
        repo=$$(git remote get-url --all origin | sed -e 's;//.*@;//;'); \
        commit=$$(git rev-parse --short HEAD); \
		echo "Git-repo:      $$(git remote show -n origin | grep Fetch | cut -d: -f2- | sed -e 's;^[[:space:]]*;;' -e 's;//.*@;//;')"; \
		echo "Git-branch:    $$(git branch --show-current)"; \
		echo "Git-commit:    $${repo}/commits/$${commit}"; \
		echo "Build-time:    $$(date)"; \
		echo "Build-machine: $$(hostname)" \
	) > ${PACKAGE_DIR}/${LAST_TOP}/files/info 
	mkdir -m 755 ${PACKAGE_DIR}/DEBIAN
	install -m 644 debian/control ${PACKAGE_DIR}/DEBIAN/control
	install -m 644 debian/changelog ${PACKAGE_DIR}/DEBIAN/changelog
	install -m 755 debian/rules ${PACKAGE_DIR}/DEBIAN/rules	
ifeq (${VMWARE},true)
	cd packaging; dpkg-deb  --nocheck --build ${PACKAGE_NAME}
else
	cd packaging; dpkg-deb --build ${PACKAGE_NAME}
endif
	mv packaging/*.deb .
	${MAKE} clean

clean:
	/bin/rm -rf packaging

check-for-github-tokens:
	test -r files/github-tokens

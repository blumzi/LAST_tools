PACKAGE_VERSION=1.0.0
PACKAGE_NAME=last-tool-${PACKAGE_VERSION}
PACKAGE_DIR=packaging/${PACKAGE_NAME}
SHELL=bash

VMWARE = 
ifeq ($(shell mapfile -t type < <(df --output=fstype .); echo $${type[1]}),fuse.vmhgfs-fuse)
	VMWARE = true
endif

package: clean check-for-github-tokens
	mkdir -m 755 -p ${PACKAGE_DIR}/usr/local/share/last-tool ${PACKAGE_DIR}/usr/local/bin ${PACKAGE_DIR}/etc/profile.d
	tar cf - --exclude=LAST-CONTAINER ./bin ./lib ./files ./sections | (cd ${PACKAGE_DIR}/usr/local/share/last-tool ; tar xf -)
	chmod 755 ${PACKAGE_DIR}/usr/local/share/last-tool/*	
ifeq (${VMWARE},true)
	mkdir -p ${PACKAGE_DIR}/usr/local/bin ${PACKAGE_DIR}/etc/profile.d
	install -m 755 ${PACKAGE_DIR}/usr/local/share/last-tool/bin/last-tool ${PACKAGE_DIR}/usr/local/bin/last-tool
	install -m 755 ${PACKAGE_DIR}/usr/local/share/last-tool/bin/last-pswitch ${PACKAGE_DIR}/usr/local/bin/last-pswitch
	install -m 755 ${PACKAGE_DIR}/usr/local/share/last-tool/bin/last-plights ${PACKAGE_DIR}/usr/local/bin/last-plights
	install -m 755 ${PACKAGE_DIR}/usr/local/share/last-tool/bin/last-matlab ${PACKAGE_DIR}/usr/local/bin/last-matlab
	install -m 755 ${PACKAGE_DIR}/usr/local/share/last-tool/bin/last-matlab ${PACKAGE_DIR}/usr/local/bin/last-matlab-R2022a
	install -m 755 ${PACKAGE_DIR}/usr/local/share/last-tool/bin/last-hosts ${PACKAGE_DIR}/usr/local/bin/last-hosts
	install -m 755 ${PACKAGE_DIR}/usr/local/share/last-tool/bin/last-fetch-from-github ${PACKAGE_DIR}/usr/local/bin/last-fetch-from-github
	install -m 644 ${PACKAGE_DIR}//usr/local/share/last-tool/files/last.sh ${PACKAGE_DIR}/etc/profile.d/last.sh
else
	ln -sf /usr/local/share/last-tool/bin/last-tool ${PACKAGE_DIR}/usr/local/bin/last-tool
	ln -sf /usr/local/share/last-tool/bin/last-matlab ${PACKAGE_DIR}/usr/local/bin/last-matlab
	ln -sf /usr/local/share/last-tool/bin/last-matlab ${PACKAGE_DIR}/usr/local/bin/last-matlab-R2022a
	ln -sf /usr/local/share/last-tool/bin/last-hosts ${PACKAGE_DIR}/usr/local/bin/last-hosts
	ln -sf /usr/local/share/last-tool/bin/last-pswitch ${PACKAGE_DIR}/usr/local/bin/last-pswitch
	ln -sf /usr/local/share/last-tool/bin/last-lights ${PACKAGE_DIR}/usr/local/bin/last-lights
	ln -sf /usr/local/share/last-tool/bin/last-watch-fits ${PACKAGE_DIR}/usr/local/bin/last-watch-fits
	ln -sf /usr/local/share/last-tool/bin/last-fetch-from-github ${PACKAGE_DIR}/usr/local/bin/last-fetch-from-github
	ln -sf /usr/local/share/last-tool/files/last.sh ${PACKAGE_DIR}/etc/profile.d/last.sh
endif
	@( \
        repo=$$(git remote get-url --all origin | sed -s 's;//.*@;//;'); \
        commit=$$(git rev-parse --short HEAD); \
		echo "Git-repo:     $$(git remote show -n origin | grep Fetch | cut -d: -f2- | sed -e 's;//.*@;//;')"; \
		echo "Git-branch:    $$(git branch --show-current)"; \
		echo "Git-commit:    $${repo}/commits/$${commit}"; \
		echo "Build-time:    $$(date)"; \
		echo "Build-machine: $$(hostname)"\
	) > ${PACKAGE_DIR}/usr/local/share/last-tool/files/info 
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

WORKDIR?=	${PWD}/tmp

BOOTDIR?=	${WORKDIR}/boot
MFSROOTDIR?=	${WORKDIR}/mfsroot
DESTDIR?=	${WORKDIR}/base
CRUNCHDIR?=	${WORKDIR}/crunch

ISOIMAGE?=	${WORKDIR}/Live_FreeBSD.iso

MAKECONF?=	/dev/null
SRCCONF?=	/dev/null
KERNCONF?=	GENERIC

JOBS?=		2

TIMEZONE?=
HOSTNAME?=	livebsd
NETWORK?=	DHCP
ROUTER?=
KEYMAP?=
ROOTPASS?=	root
NTPSERVER?=

SRCIMG?=
OBJIMG?=

all: iso

.if exists(live.conf)
.include "live.conf"
.endif

clean:
	@echo "--------------------------------------------------------------"
	@echo ">>> Clean Directory ${WORKDIR}"
	@echo "--------------------------------------------------------------"
	@if [ -d ${WORKDIR} ]; then \
		chflags -R noschg ${WORKDIR}; \
		rm -fr ${WORKDIR}; \
	fi

	@mkdir -p ${WORKDIR}
	@mkdir -p ${BOOTDIR}/uzip
	@mkdir -p ${MFSROOTDIR}
	@mkdir -p ${DESTDIR}
	@mkdir -p ${CRUNCHDIR}

build: clean ${WORKDIR}/.build_done
${WORKDIR}/.build_done:
.if defined(_BUILD)
	@echo "--------------------------------------------------------------"
	@echo ">>> MAKECONF ${MAKECONF}"
	@echo ">>> SRCCONF  ${SRCCONF}"
	@echo ">>> KERNCONF ${KERNCONF}"
	@echo "--------------------------------------------------------------"
	@echo ">>> make -j ${JOBS} buildworld"
	@cd /usr/src && \
		make -j ${JOBS} DESTDIR=${DESTDIR} __MAKE_CONF=${MAKECONF} SRCCONF=${SRCCONF} \
		KERNCONF=${KERNCONF} buildworld > /dev/null
	@echo ">>> make -j ${JOBS} buildkernel"
	@cd /usr/src && \
		make -j ${JOBS} DESTDIR=${DESTDIR} __MAKE_CONF=${MAKECONF} SRCCONF=${SRCCONF} \
		KERNCONF=${KERNCONF} buildkernel > /dev/null
.endif
	@touch ${WORKDIR}/.build_done

install: build ${WORKDIR}/.install_done
${WORKDIR}/.install_done:
.if defined(_INSTALL)
	@echo "--------------------------------------------------------------"
	@echo ">>> MAKECONF ${MAKECONF}"
	@echo ">>> SRCCONF  ${SRCCONF}"
	@echo ">>> KERNCONF ${KERNCONF}"
	@echo "--------------------------------------------------------------"

	@echo ">>> make installworld"
	@cd /usr/src && \
		make DESTDIR=${DESTDIR} __MAKE_CONF=${MAKECONF} SRCCONF=${SRCCONF} \
		KERNCONF=${KERNCONF} installworld > /dev/null

	@echo ">>> make distrib-dirs"
	@cd /usr/src && \
		make DESTDIR=${DESTDIR} __MAKE_CONF=${MAKECONF} SRCCONF=${SRCCONF} \
		KERNCONF=${KERNCONF} distrib-dirs > /dev/null

	@echo ">>> make distribution"
	@cd /usr/src && \
		make DESTDIR=${DESTDIR} __MAKE_CONF=${MAKECONF} SRCCONF=${SRCCONF} \
		KERNCONF=${KERNCONF} distribution > /dev/null

	@echo ">>> make installkernel"
	@cd /usr/src && \
		make DESTDIR=${DESTDIR} __MAKE_CONF=${MAKECONF} SRCCONF=${SRCCONF} \
		KERNCONF=${KERNCONF} installkernel > /dev/null

	@rm -rf ${DISTDIR}/boot/kernel/*.symbols
.elif !empty(BASE)
	@if [ ! -d "${BASE}" ]; then \
		exit 1; \
	fi
	@for DIR in base kernels; do \
		if [ ! -d "${BASE}/$$DIR" ]; then \
			exit 1; \
		fi \
	done
	@cat ${BASE}/base/base.?? | tar --unlink -xpzf - -C ${DISTDIR}
	@cat ${BASE}/kernels/generic.?? | ${TAR} --unlink -xpzf - -C ${DISTDIR}/boot
	@mv ${DISTDIR}/boot/GENERIC/* ${DISTDIR}/boot/kernel
	@rm -rf ${DISTDIR}/boot/kernel/*.symbols
.else
	@exit 1
.endif

.if defined(GLOADER)
	@echo ">>> Install Graphics Boot Loader"
	@echo ">>> Not Support CD Boot"
	@echo ">>> See also http://wiki.freebsd.org/OliverFromme/BootLoader"
#	@fetch -q -o "${WORKDIR}/gloader.tar.gz" "http://www.secnetix.de/olli/tmp/gloader.tar.gz"
#	@cd ${DESTDIR}/boot && tar xpzf ${WORKDIR}/gloader.tar.gz
.endif

	@touch ${WORKDIR}/.install_done

config: install ${WORKDIR}/.config_done
${WORKDIR}/.config_done:
.if defined(_BUILD) || defined(_INSTALL) && ${MAKECONF} != "/dev/null"
	@cp ${MAKECONF} ${DESTDIR}/etc
.endif

.if defined(_BUILD) || defined(_INSTALL) && ${SRCCONF} != "/dev/null"
	@cp ${SRCCONF} ${DESTDIR}/etc
.endif

.if !empty(TIMEZONE)
	@cp -a ${DESTDIR}/usr/share/zoneinfo/${TIMEZONE} ${DESTDIR}/etc/localtime
	@touch ${DESTDIR}/etc/wall_cmos_clock
	@chmod 444 ${DESTDIR}/etc/wall_cmos_clock
.endif

	@echo '' > ${DESTDIR}/etc/fstab

	@echo '# Network Configuration' > ${DESTDIR}/etc/rc.conf
.if !empty(ROUTER)
	@printf "defaultrouter=\42${ROUTER}\42\n" >> ${DESTDIR}/etc/rc.conf
.elif ${NETWORK} != "DHCP"
	@echo "Please check ROUTER=${ROUTER} and NETWORK=${NETWORK}"
	@exit 1
.endif
	@printf "ifconfig_DEFAULT=\42${NETWORK}\42\n" >> ${DESTDIR}/etc/rc.conf
	@printf "hostname=\42${HOSTNAME}\42\n" >> ${DESTDIR}/etc/rc.conf
	@echo '' >> ${DESTDIR}/etc/rc.conf
	@echo '# Network Option' >> ${DESTDIR}/etc/rc.conf
	@echo 'tcp_drop_synfin="YES"' >> ${DESTDIR}/etc/rc.conf
	@echo 'icmp_drop_redirect="YES"' >> ${DESTDIR}/etc/rc.conf
	@echo '' >> ${DESTDIR}/etc/rc.conf
	@echo '# Kerboard Configuration' >> ${DESTDIR}/etc/rc.conf
.if !empty(KEYMAP)
	@printf "keymap=\42${KEYMAP}\42\n" >> ${DESTDIR}/etc/rc.conf
.endif
	@echo 'keyrate="fast"' >> ${DESTDIR}/etc/rc.conf
	@echo 'keybell="off"' >> ${DESTDIR}/etc/rc.conf
.if !empty(NTPSERVER)
	@echo '' >> ${DESTDIR}/etc/rc.conf
	@echo '# NTP' >> ${DESTDIR}/etc/rc.conf
	@echo 'ntpdate_enable="YES"' >> ${DESTDIR}/etc/rc.conf
	@printf "ntpdate_hosts=\42${NTPSERVER}\42\n" >> ${DESTDIR}/etc/rc.conf
.endif
	@echo '' >> ${DESTDIR}/etc/rc.conf
	@echo '# SSH' >> ${DESTDIR}/etc/rc.conf
	@echo 'sshd_enable="YES"' >> ${DESTDIR}/etc/rc.conf
	@echo '' >> ${DESTDIR}/etc/rc.conf
	@echo '# Sendmail' >> ${DESTDIR}/etc/rc.conf
	@echo 'sendmail_enable="NO"' >> ${DESTDIR}/etc/rc.conf
	@echo 'sendmail_submit_enable="NO"' >> ${DESTDIR}/etc/rc.conf
	@echo 'sendmail_outbound_enable="NO"' >> ${DESTDIR}/etc/rc.conf
	@echo 'sendmail_msp_queue_enable="NO"' >> ${DESTDIR}/etc/rc.conf
	@echo '' >> ${DESTDIR}/etc/rc.conf
	@echo '# Not change /etc/motd' >> ${DESTDIR}/etc/rc.conf
	@echo 'update_motd="NO"' >> ${DESTDIR}/etc/rc.conf
	@echo '' >> ${DESTDIR}/etc/rc.conf
	@echo '# For Ramdisk Root' >> ${DESTDIR}/etc/rc.conf
	@echo 'root_rw_mount="NO"' >> ${DESTDIR}/etc/rc.conf
	@echo 'tmpmfs="NO"' >> ${DESTDIR}/etc/rc.conf
	@echo 'varmfs="NO"' >> ${DESTDIR}/etc/rc.conf

	@printf "Welcome to Live FreeBSD\n\n" > ${DESTDIR}/etc/motd

	@printf "hosts\ndns\n" > ${DESTDIR}/etc/host.conf

	@perl -p -i -e 's/^(ttyv[1-8].*)on (.*)/\1off\2/g' ${DESTDIR}/etc/ttys

	@echo "hw.syscons.bell=0" >> ${DESTDIR}/etc/sysctl.conf
	@echo "net.inet.tcp.blackhole=2" >> ${DESTDIR}/etc/sysctl.conf
	@echo "net.inet.udp.blackhole=1" >> ${DESTDIR}/etc/sysctl.conf
	@echo "net.inet.icmp.icmplim=50" >> ${DESTDIR}/etc/sysctl.conf

	@perl -p -i -e 's/.*(PermitRootLogin).*/\1 yes/' /etc/ssh/sshd_config

	@ssh-keygen -t rsa1 -b 1024 -f ${DESTDIR}/etc/ssh/ssh_host_key -N '' > /dev/null
	@ssh-keygen -t dsa -f ${DESTDIR}/etc/ssh/ssh_host_dsa_key -N '' > /dev/null
	@ssh-keygen -t rsa -f ${DESTDIR}/etc/ssh/ssh_host_rsa_key -N '' > /dev/null

	@echo ${ROOTPASS} | pw -V ${DESTDIR}/etc usermod root -h 0

	@touch ${WORKDIR}/.config_done

mfsroot: install config ${WORKDIR}/.mfsroot_done
${WORKDIR}/.mfsroot_done:
.if defined(CRUNCH)
.else
	@mkdir ${MFSROOTDIR}/rescue
	@tar -cf - -C ${DESTDIR}/rescue . | tar -xpf - -C ${MFSROOTDIR}/rescue

	@cd ${MFSROOTDIR} && ln -s rescue bin
	@cd ${MFSROOTDIR} && ln -s rescue sbin
.endif

	@mkdir ${MFSROOTDIR}/dev
	@mkdir ${MFSROOTDIR}/etc
	@mkdir -p ${MFSROOTDIR}/var/empty

	@cp newroot.rc ${MFSROOTDIR}/etc

	@cp -a ${DESTDIR}/etc/login.conf ${MFSROOTDIR}/etc
	@cap_mkdb -f ${DESTDIR}/etc/login.conf ${DESTDIR}/etc/login.conf

	@echo '' > ${MFSROOTDIR}/etc/fstab

	@touch ${WORKDIR}/.mfsroot_done

boot: install config mfsroot ${WORKDIR}/.boot_done
${WORKDIR}/.boot_done:
	@mkdir ${BOOTDIR}/boot
	@tar -cf - -C ${DESTDIR}/boot . | tar -xpf - -C ${BOOTDIR}/boot

	@echo 'autoboot_delay="1"' > ${BOOTDIR}/boot/loader.conf
	@echo 'mfsroot_load="YES"' >> ${BOOTDIR}/boot/loader.conf
	@echo 'mfsroot_type="mfs_root"' >> ${BOOTDIR}/boot/loader.conf
	@echo 'mfsroot_name="/boot/mfsroot"' >> ${BOOTDIR}/boot/loader.conf
.if defined(CRUNCH)
.else
	@echo 'init_path="/rescue/init"' >> ${BOOTDIR}/boot/loader.conf
	@echo 'init_shell="/rescue/sh"' >> ${BOOTDIR}/boot/loader.conf
.endif
	@echo 'init_script="/etc/newroot.rc"' >> ${BOOTDIR}/boot/loader.conf
	@echo 'init_chroot="/newroot"' >> ${BOOTDIR}/boot/loader.conf
	@echo 'geom_uzip_load="YES"' >> ${BOOTDIR}/boot/loader.conf
	@echo 'nullfs_load="YES"' >> ${BOOTDIR}/boot/loader.conf
	@echo 'unionfs_load="YES"' >> ${BOOTDIR}/boot/loader.conf
.if defined(GLOADER)
#	@echo 'beastie_theme="/boot/themes/default/theme.conf"' >> ${BOOTDIR}/boot/loader.conf
.endif

	@makefs -t ffs -b 5% -f 5% ${WORKDIR}/root.img ${DESTDIR} > /dev/null
	@mkuzip -o ${BOOTDIR}/uzip/root.uzip ${WORKDIR}/root.img
	@rm ${WORKDIR}/root.img

	@makefs -t ffs -b 5% -f 5% ${BOOTDIR}/boot/mfsroot ${MFSROOTDIR} > /dev/null

	@gzip -9 ${BOOTDIR}/boot/mfsroot
	@gzip -9 ${BOOTDIR}/boot/kernel/kernel

.if !empty(SRCIMG)
	@cp ${SRCIMG} ${BOOTDIR}/uzip
.endif

.if !empty(OBJIMG)
	@cp ${OBJIMG} ${BOOTDIR}/uzip
.endif

	@touch ${WORKDIR}/.boot_done

iso: install config mfsroot boot ${ISOIMAGE}
${ISOIMAGE}:
	@mkisofs -b boot/cdboot -no-emul-boot -l -ldots -allow-lowercase -allow-multidot \
		-hide boot.catalog -hide-joliet boot.catalog -R -J -V "Live_FreeBSD" \
		-o ${WORKDIR}/Live_FreeBSD.iso ${BOOTDIR} > /dev/null

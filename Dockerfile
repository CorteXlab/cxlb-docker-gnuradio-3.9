FROM debian:buster

ENV APT="apt-get -y"

# pinning
RUN echo "deb http://ftp.debian.org/debian/ bullseye main non-free contrib" >> /etc/apt/sources.list
RUN echo "Package: *\nPin: release a=buster\nPin-Priority: 700\n\nPackage: *\nPin: release a=bullseye\nPin-Priority: -1" > /etc/apt/preferences.d/pinning

RUN ${APT} update && ${APT} dist-upgrade

WORKDIR /root

# set an empty password for root
RUN sed -i -e 's%root:\*:%root:$6$fEFUE2YaNmTEH51Z$1xRO8/ytEYIo10ajp4NZSsoxhCe1oPLIyjDjqSOujaPZXFQxSSxu8LDHNwbPiLSjc.8u0Y0wEqYkBEEc5/QN5/:%' /etc/shadow

# install ssh server, listening on port 2222
RUN ${APT} install openssh-server
RUN sed -i 's/^#\?[[:space:]]*Port 22$/Port 2222/' /etc/ssh/sshd_config
RUN sed -i 's/^#\?[[:space:]]*PermitEmptyPasswords no$/PermitEmptyPasswords yes/' /etc/ssh/sshd_config
RUN sed -i 's/^#\?[[:space:]]*PermitRootLogin.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN mkdir /run/sshd
RUN chmod 755 /run/sshd

# tweaks for macos / windows
RUN sed -i 's/^#\?[[:space:]]*X11UseLocalhost.*$/X11UseLocalhost no/' /etc/ssh/sshd_config
RUN echo "AddressFamily inet" >> /etc/ssh/sshd_config
RUN touch /root/.Xauthority

# cxlb-build-toolchain.git
RUN ${APT} install git
RUN git clone https://github.com/CorteXlab/cxlb-build-toolchain.git cxlb-build-toolchain.git

# build toolchain (separate build steps to benefit from docker cache in case of build issues on a specific module)
ENV BUILD="cxlb-build-toolchain.git/cxlb-build-toolchain -y /usr/bin/python3 -as"
ENV PARMS="cxlb_toolchain_build /cortexlab/toolchains/current"
RUN ${APT} install udev
RUN ${BUILD} uhd=master ${PARMS}
RUN ${BUILD} uhd-firmware ${PARMS}
RUN ${APT} install python3-pybind11/bullseye python3-pygccxml/bullseye
RUN ${BUILD} volk=main ${PARMS}
RUN ${BUILD} gnuradio=maint-3.9 ${PARMS}
#RUN ${BUILD} gr-bokehgui=maint-3.8 ${PARMS} # gr-bokehgui doesn't work with gnuradio-3.9
RUN ${BUILD} gr-iqbal=master ${PARMS}
# RUN ${BUILD} fft-web ${PARMS}

# activate toolchain configuration
RUN /cortexlab/toolchains/current/bin/cxlb-toolchain-system-conf
RUN echo source /cortexlab/toolchains/current/bin/cxlb-toolchain-user-conf >> /etc/profile
RUN ln -s /cortexlab/toolchains/current/bin/cxlb-toolchain-user-conf /etc/profile.d/cxlb-toolchain-user-conf.sh
# RUN sysctl -w net.core.wmem_max=2500000

# remove toolchain sources
#RUN rm -rf cxlb_toolchain_build/

# the container's default executable: ssh daemon
CMD [ "/usr/sbin/sshd", "-p", "2222", "-D" ]

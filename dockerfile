FROM scratch
ADD ubuntu-base-20.04.1-base-amd64.tar.gz /

### a few minor docker-specific tweaks
### see https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap
RUN set -xe \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L40-L48
	&& echo '#!/bin/sh' > /usr/sbin/policy-rc.d \
	&& echo 'exit 101' >> /usr/sbin/policy-rc.d \
	&& chmod +x /usr/sbin/policy-rc.d \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L54-L56
	&& dpkg-divert --local --rename --add /sbin/initctl \
	&& cp -a /usr/sbin/policy-rc.d /sbin/initctl \
	&& sed -i 's/^exit.*/exit 0/' /sbin/initctl \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L71-L78
	&& echo 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L85-L105
	&& echo 'DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' > /etc/apt/apt.conf.d/docker-clean \
	&& echo 'APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' >> /etc/apt/apt.conf.d/docker-clean \
	&& echo 'Dir::Cache::pkgcache ""; Dir::Cache::srcpkgcache "";' >> /etc/apt/apt.conf.d/docker-clean \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L109-L115
	&& echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/docker-no-languages \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L118-L130
	&& echo 'Acquire::GzipIndexes "true"; Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/docker-gzip-indexes \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L134-L151
	&& echo 'Apt::AutoRemove::SuggestsImportant "false";' > /etc/apt/apt.conf.d/docker-autoremove-suggests

# delete all the apt list files since they're big and get stale quickly
RUN rm -rf /var/lib/apt/lists/*
# this forces "apt-get update" in dependent images, which is also good
# (see also https://bugs.launchpad.net/cloud-images/+bug/1699913)

# make systemd-detect-virt return "docker"
# See: https://github.com/systemd/systemd/blob/aa0c34279ee40bce2f9681b496922dedbadfca19/src/basic/virt.c#L434
RUN mkdir -p /run/systemd && echo 'docker' > /run/systemd/container


### Init
SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND noninteractive
RUN apt update && apt upgrade -y
RUN apt-get update && apt upgrade -y


### Basic tools
RUN apt-get install sudo
RUN apt-get install vim -y
RUN apt-get install iputils-ping -y
RUN apt-get install software-properties-common -y
RUN apt-get install htop -y
RUN apt-get install net-tools -y
RUN apt install iproute2 -y
# Not so basic tools
RUN apt-get install terminator gedit -y
RUN apt update -y

#Install ROS
RUN sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
RUN apt install curl -y
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -
RUN apt update -y
RUN apt install ros-noetic-desktop-full -y

#Setup ROS environment
RUN apt install python3-rosdep python3-rosinstall python3-rosinstall-generator python3-wstool build-essential -y
RUN apt install python3-rosdep -y
RUN rosdep init
RUN rosdep fix-permissions
RUN rosdep update
RUN source /opt/ros/noetic/setup.bash

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES \
    ${NVIDIA_VISIBLE_DEVICES:-all}
ENV NVIDIA_DRIVER_CAPABILITIES \
    ${NVIDIA_DRIVER_CAPABILITIES:+$NVIDIA_DRIVER_CAPABILITIES,}graphics

### Epilogue
#WORKDIR /root/catkin_ws/
RUN source /root/.bashrc
ENV DEBIAN_FRONTEND noninteractive
CMD /usr/bin/terminator -u

#Root to Python3
RUN ln -L /usr/bin/python3 /usr/bin/python

#Permission fot the docker
RUN useradd -Um user
RUN echo user 'ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN echo "source /opt/ros/noetic/setup.bash" >> /home/user/.bashrc

#numpy installation
RUN apt-get install python3-pip -y
RUN apt-get install ros-noetic-ros-numpy
RUN pip install scipy
RUN pip install pandas

#install gnome-terminal
RUN apt install gnome-terminal -y
RUN apt-get install psmisc


#docker run --rm -it --privileged --net host --env="DISPLAY" --gpus=all -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY --ipc=host --tmpfs=/run --env=DISPLAY --volume=/etc/localtime:/etc/localtime --volume=D:\devops:/home/ --volume=/tmp:/tmp --user user --entrypoint=/bin/bash -it --cap-add=NET_ADMIN ubuntu_20-04


FROM tiryoh/ros2-desktop-vnc:humble

ENV DEBIAN_FRONTEND=noninteractive

###Add Sudo
# RUN add-apt-repository ppa:kisak/kisak-mesa \
RUN apt update \
  && apt install -y \
  sudo \
  tzdata\
  vim \
  wget \
  curl \
  lsb-release \
  gnupg \
  wmctrl \
  git \
  software-properties-common \
  mesa-utils \
  bash-completion \
  python3-pip \
  xfce4-terminal \
  && apt full-upgrade -y \
  && rm -rf /var/lib/apt/list/

## Install gazebo
RUN wget https://packages.osrfoundation.org/gazebo.gpg -O /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null

RUN apt update && apt install -y \
  gz-harmonic \
	&& rm -rf /var/lib/apt/lists/

RUN pip uninstall empy && pip install empy==3.3.4 && pip install -U colcon-common-extensions && pip uninstall numpy -y && pip install numpy==1.21.5

###Add the USER env var
RUN groupadd -g 1000 ubuntu-user \
  && adduser --disabled-password --gid 1000 --uid 1000 --gecos '' ubuntu-user \
  && adduser ubuntu-user sudo
# RUN passwd --delete ubuntu
RUN echo 'ubuntu-user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
ENV HOME=/home/ubuntu-user
USER ubuntu-user
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR $HOME

# Install ArduSub
RUN git clone https://github.com/ArduPilot/ardupilot.git
WORKDIR $HOME/ardupilot
RUN git checkout 2dd0bb7d4c85ac48437f139d66df648fc0e1d4ae
RUN git submodule update --init --recursive
RUN rm $HOME/ardupilot/Tools/environment_install/install-prereqs-ubuntu.sh
RUN wget -P $HOME/ardupilot/Tools/environment_install/ https://raw.githubusercontent.com/ArduPilot/ardupilot/c623ae8b82db4d7e195f4b757e2ae5d049f941e5/Tools/environment_install/install-prereqs-ubuntu.sh
RUN chmod +x $HOME/ardupilot/Tools/environment_install/install-prereqs-ubuntu.sh
RUN USER=ubuntu-user Tools/environment_install/install-prereqs-ubuntu.sh -y

RUN sudo pip3 install -U mavproxy PyYAML

ENV PATH=/opt/gcc-arm-none-eabi-10-2020-q4-major/bin:$PATH
ENV PATH=$PATH:$HOME/ardupilot/Tools/autotest
ENV PATH=/usr/lib/ccache:$PATH

RUN ["/bin/bash","-c","./waf configure && make sub"]

# Install ardupilot gazebo plugin
RUN sudo apt update && sudo apt install -y \
  rapidjson-dev \
  libgz-sim8-dev \
  libopencv-dev \
  libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-libav \
  gstreamer1.0-gl \
  && sudo rm -rf /var/lib/apt/list/

WORKDIR $HOME
RUN git clone https://github.com/ArduPilot/ardupilot_gazebo

ENV GZ_VERSION=harmonic
RUN ["/bin/bash", "-c", "source /opt/ros/humble/setup.bash \
  && sudo wget https://raw.githubusercontent.com/osrf/osrf-rosdep/master/gz/00-gazebo.list -O /etc/ros/rosdep/sources.list.d/00-gazebo.list \
  && rosdep update \
  && rosdep resolve gz-$GZ_VERSION"]

WORKDIR $HOME/ardupilot_gazebo
RUN [ "/bin/bash","-c","mkdir build && cd build \
  && cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo\
  && make"]

ENV GZ_SIM_SYSTEM_PLUGIN_PATH=$HOME/ardupilot_gazebo/build:${GZ_SIM_SYSTEM_PLUGIN_PATH}
ENV GZ_SIM_RESOURCE_PATH=$HOME/ardupilot_gazebo/models:$HOME/ardupilot_gazebo/worlds:${GZ_SIM_RESOURCE_PATH}

ENV GZ_VERSION=harmonic
RUN mkdir -p $HOME/suave_ws/src
RUN git clone https://github.com/kas-lab/suave.git $HOME/suave_ws/src/suave
WORKDIR $HOME/suave_ws/
RUN vcs import src < $HOME/suave_ws/src/suave/suave.rosinstall --recursive

# Install suave deps
WORKDIR $HOME/suave_ws
RUN ["/bin/bash", "-c", "source /opt/ros/humble/setup.bash \
  && rosdep update \
  && rosdep install --from-paths src --ignore-src -r -y"]

RUN ["/bin/bash", "-c", "sudo ./src/mavros/mavros/scripts/install_geographiclib_datasets.sh"]

RUN pip uninstall empy -y && pip install empy==3.3.4

# Build suave
RUN ["/bin/bash", "-c", "source /opt/ros/humble/setup.bash \
  && colcon build --symlink-install \
  && echo 'source ~/suave_ws/install/setup.bash' >> ~/.bashrc"]


RUN sudo apt autoremove -y && sudo rm -rf /var/lib/apt/lists/

USER root
COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh
RUN dos2unix /entrypoint.sh

ENV USER=ubuntu-user
ENV PASSWD=ubuntu

## Install rosbridge-server
RUN sudo apt update && sudo apt install -y \
  ros-humble-rosbridge-server \
  && sudo rm -rf /var/lib/apt/list/

## Install maven
WORKDIR $HOME/
RUN wget https://dlcdn.apache.org/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz
RUN tar -xvf apache-maven-3.9.9-bin.tar.gz
RUN mv apache-maven-3.9.9 /opt/
ENV M2_HOME='/opt/apache-maven-3.9.9'
ENV PATH="$M2_HOME/bin:$PATH"

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

ENV JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64
# ENV JAVA_HOME=/usr/bin/java

## Install rosbridge-server
RUN sudo apt update && sudo apt install -y \
  ant \
  && sudo rm -rf /var/lib/apt/list/

## Install java_rosbridge
RUN git clone https://github.com/h2r/java_rosbridge.git
WORKDIR $HOME/java_rosbridge
RUN mvn compile && mvn package && mvn install

## Install MCAPL
WORKDIR $HOME
# RUN git clone https://github.com/mcapl/mcapl.git --branch mcapl2024
RUN git clone https://github.com/mcapl/mcapl.git
RUN mkdir -p $HOME/.jpf && touch $HOME/.jpf/site.properties
RUN echo "mcapl = $HOME/mcapl" >> $HOME/.jpf/site.properties

ENV AJPF_HOME=$HOME/macpl
ENV CLASSPATH=$HOME/macpl/bin
WORKDIR $HOME/mcapl
# RUN ant compile && ant build
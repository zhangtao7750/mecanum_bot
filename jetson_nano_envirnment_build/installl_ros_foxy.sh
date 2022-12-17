# Build ROS2 foxy on jetson L4t 18.04 Ubuntu
# Mostly from Dusty-NV's foxy Dockerfile

mkdir -p $HOME/ros_ws/src
cd $HOME/ros_ws

# add the ROS deb repo to the apt sources list
apt update 
apt install -y --no-install-recommends curl wget gnupg2 lsb-release ca-certificates


curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# install development packages
apt update && \
apt install -y build-essential \
    cmake \
    git \
    libbullet-dev \
    libpython3-dev \
    python3-colcon-common-extensions \
    python3-rosdistro \
    python3-rospkg \
    python3-rosdep-modules \
    python3-catkin-pkg \
    python3-flake8 \
    python3-pip \
    python3-pytest-cov \
    python3-rosdep \
    python3-setuptools \
    python3-vcstool \
    python3-rosinstall-generator \
    libasio-dev \
    libtinyxml2-dev \
    libcunit1-dev 

python3 -m pip install --upgrade pip

# install some pip packages needed for testing
python3 -m pip install -U \
    argcomplete \
    pyqt5 \
    flake8-blind-except \
    flake8-builtins \
    flake8-class-newline \
    flake8-comprehensions \
    flake8-deprecated \
    flake8-docstrings \
    flake8-import-order \
    flake8-quotes \
    pytest-repeat \
    pytest-rerunfailures \
    pytest
    
# compile yaml-cpp-0.6, which some ROS packages may use (but is not in the 18.04 apt repo)
git clone --branch yaml-cpp-0.6.0 https://github.com/jbeder/yaml-cpp yaml-cpp-0.6 && \
    cd yaml-cpp-0.6 && \
    mkdir build && \
    cd build && \
    cmake -DBUILD_SHARED_LIBS=ON .. && \
    make -j$(nproc) && \
    sudo cp libyaml-cpp.so.0.6.0 /usr/lib/aarch64-linux-gnu/ && \
    sudo ln -s /usr/lib/aarch64-linux-gnu/libyaml-cpp.so.0.6.0 /usr/lib/aarch64-linux-gnu/libyaml-cpp.so.0.6 
 
# add this to make sdl_vendor build
   
wget https://www.libsdl.org/release/SDL2-2.0.12.tar.gz
sed -i \
    's/ros_env_setup="\/opt\/ros\/$ROS_DISTRO\/setup.bash"/ros_env_setup="${ROS_ROOT}\/install\/setup.bash"/g' \
    /ros_entrypoint.sh && \
    cat /ros_entrypoint.sh
tar xf SDL2-2.0.12.tar.gz
cd SDL2-2.0.12 
./autogen.sh
./configure
make
make install
ldconfig

# https://answers.ros.org/question/325245/minimal-ros2-installation/?answer=325249#post-id-325249

cd ~/ros_ws && \
    rosinstall_generator --deps --rosdistro foxy desktop launch_xml launch_yaml example_interfaces > ros2.foxy.desktop.rosinstall && \
    vcs import src < ros2.foxy.desktop.rosinstall
    
rm ~/ros_ws/src/libyaml_vendor/CMakeLists.txt && \
wget --no-check-certificate https://raw.githubusercontent.com/ros2/libyaml_vendor/master/CMakeLists.txt -P ~/ros_ws/src/libyaml_vendor/  

# download unreleased packages
git clone --branch ros2 https://github.com/Kukanani/vision_msgs ~/ros_ws/src/vision_msgs && \
git clone --branch ${ROS_DISTRO} https://github.com/ros2/demos demos && \
    cp -r demos/demo_nodes_cpp ~/ros_ws/src && \
    cp -r demos/demo_nodes_py ~/ros_ws/src && 

# install additional ros packages
cd $HOME/ros_ws
git clone --branch ros2 https://github.com/ros/xacro.git src/xacro && \
git clone --branch foxy-devel https://github.com/ros/urdf_parser_py.git src/urdf_parser_py && \
git clone --branch foxy https://github.com/ros/joint_state_publisher.git src/joint_state_publisher && \

# install dependencies using rosdep
apt update && \
    cd ~/ros_ws && \
rosdep init && \
     rosdep update && \
     rosdep install --from-paths src --ignore-src --rosdistro foxy -y --skip-keys "console_bridge fastcdr fastrtps rti-connext-dds-5.3.1 urdfdom_headers qt_gui" && \
    rosdep install --from-paths src --ignore-src --rosdistro foxy -y --skip-keys "" 

# build it!
cd ~/ros_ws && colcon build --symlink-install --parallel-workers 2

chown -R $USER $HOME/ros_ws
chgrp -R $USER $HOME/ros_ws
chown -R $USER $HOME/.ros
chgrp -R $USER $HOME/.ros



 
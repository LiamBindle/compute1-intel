FROM spack/centos7 AS dependency_builder

# Install intel compilers and mpi
COPY intel/rpm /intel/rpm
COPY *.lic /opt/intel/licenses
RUN  rpm -i /intel/rpm/*.rpm && rm -rf /intel

# Detect intel compilers with spack
RUN  . /opt/intel/compilers_and_libraries_2019.5.281/linux/bin/compilervars.sh intel64 \
&&   spack compiler find

# Create intel/19 modulefile
COPY packages.yaml $SPACK_ROOT/etc/spack/packages.yaml
COPY env2 /env2
RUN  mkdir /usr/share/modulefiles/intel \
&&   echo "#%Module" > /usr/share/modulefiles/intel/19 \
&&   chmod +x /env2 \
&&   perl /env2 -from bash -to modulecmd "/opt/intel/compilers_and_libraries_2019.5.281/linux/bin/compilervars.sh intel64" >> /usr/share/modulefiles/intel/19 \
&&   rm /env2

# Install ESMF
RUN module load intel/19 \
&&  spack install -v --no-checksum esmf@8.0.0 target=x86_64 -lapack -pio -pnetcdf -xerces

# Install zsh
RUN yum install -y zsh wget vim cmake3 \
&&  ln -s /usr/bin/cmake3 /usr/bin/cmake \
&&  export ZSH=/usr/share/oh-my-zsh \
&&  wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh

# Install gFTL
RUN git clone https://github.com/Goddard-Fortran-Ecosystem/gFTL.git /gFTL \
&&  cd /gFTL \
&&  mkdir build \
&&  cd build \
&&  cmake .. -DCMAKE_INSTALL_PREFIX=/opt/gFTL \
&&  make -j install \
&&  rm -rf /gFTL

# Remove the intel license
#RUN rm -rf /opt/intel/licenses

# Set up the entrypoint
RUN echo "#!/usr/bin/env bash" > /usr/bin/start-container.sh \
&&  echo ". /usr/share/lmod/lmod/init/bash" >> /usr/bin/start-container.sh \
&&  echo ". $SPACK_ROOT/share/spack/setup-env.sh" >> /usr/bin/start-container.sh \
&&  echo "export MODULEPATH=$MODULEPATH:/usr/share/modulefiles" >> /usr/bin/start-container.sh \
&&  echo "export CC=icc" >> /usr/bin/start-container.sh \
&&  echo "export CXX=icpc" >> /usr/bin/start-container.sh \
&&  echo "export FC=ifort" >> /usr/bin/start-container.sh \
&&  echo "export gFTL_ROOT=/opt/gFTL/1.2/include" >> /usr/bin/start-container.sh \
&&  echo "module load intel/19" >> /usr/bin/start-container.sh \
&&  echo "spack load hdf5" >> /usr/bin/start-container.sh \
&&  echo "spack load netcdf-c" >> /usr/bin/start-container.sh \
&&  echo "spack load netcdf-fortran" >> /usr/bin/start-container.sh \
&&  echo "spack load esmf" >> /usr/bin/start-container.sh \
&&  echo 'if [ $# -gt 0 ]; then exec "$@"; else zsh ; fi' >> /usr/bin/start-container.sh \
&&  chmod +x /usr/bin/start-container.sh
ENTRYPOINT ["start-container.sh"]
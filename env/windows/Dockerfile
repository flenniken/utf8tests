# This builds a development environment for the utf8 tests project.

FROM debian:12
MAINTAINER Steve Flenniken
ENV utf8tests_env=debian

# Install base apps.
RUN apt update && apt -qy install less man sudo tree curl wget nano git

# Install the c language.
RUN apt -qy install libssl-dev build-essential clang

# Install the perl regular expression library to avoid "could not
# load: libpcre.so(.3|.1|)" runtime error.
RUN apt -qy install libpcre3 libpcre3-dev

# Create user utf8tester with sudo permissions and no password.
RUN mkdir -p /etc/sudoers.d \
  && echo "utf8tester ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/utf8tester \
  && chmod 440 /etc/sudoers.d/utf8tester \
  && adduser --disabled-password --gecos '' utf8tester \
  && usermod -aG sudo utf8tester \
  && echo 'utf8tester:devenv' | chpasswd

RUN chown utf8tester:utf8tester /home/utf8tester

# Switch to user utf8tester for following commands.
USER utf8tester
WORKDIR /home/utf8tester

# The debian package manager installs an old nim version.  To get a
# newer version you can download prebuilt binaries or build from
# source.  The prebuilt binaries are built for x86 machines and no
# version for arm64. The x86 version will run using emulation, however
# nimble is very slow.  You can build from source by cloning the git
# repo, checking out a version tag and running a build script.  This
# docker file supports the build from source method.

# Note: You need to manually run build_all.sh once in the container to
# build nim.

# cd ~/Nim
# build_all.sh
# nim -v

# Get nim source for manually building nim.
RUN git clone https://github.com/nim-lang/Nim.git
ARG nim_version=v2.2.0
RUN cd Nim \
  && git checkout $nim_version \
  && git switch -c $nim_version

# Install bashrc for the prompt and some aliases.
COPY --chown=utf8tester:utf8tester bashrc .bashrc

# Start in the utf8tests directory.
WORKDIR /home/utf8tester/utf8tests
CMD ["/bin/bash"]

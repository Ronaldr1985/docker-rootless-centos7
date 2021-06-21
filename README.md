# Docker Rootless Installer for CentOS 7 

## The script

The script that this repository is centered around, `centos-docker-rootless-install.sh` installs [Docker](https://www.docker.com/) in [rootless mode](https://docs.docker.com/engine/security/rootless/).  **PLEASE NOTE, this is not a secure install, and goes against Docker's recommendations for a rootless install.**

### What does the script do?

The script checks to see if Docker is installed, if not it will add the official Docker repository and install the Docker package.  The script then disables the standard Docker service which runs as root.  After, the script creates the user that will be running Docker, this user is called `dockerd` by default however, this can be changed by changing the variables at the top of the script.  The script then installs Docker in rootless mode to this user, this user's home directory is set to `/opt/docker` by default, however this can be changed by changing the `home_dir` variable located at the top of script.  After this, the script then craetes a system wide systemd service file called `docker-rootless`, this is not supported by Docker, however, on CentOS 7 if you want to manage the docker-rootless daemon with systemd we don't have a choice.  The script also sets the environment variable `XDG_RUNTIME_DIR` to a subdirectory of /tmp/.  This once again is not recommended by Docker:

> $XDG_RUNTIME_DIR: an ephemeral directory that is only accessible by the expected user, e,g, ~/.docker/run. The directory should be removed on every host shutdown. The directory can be on tmpfs, however, should not be under /tmp. Locating this directory under /tmp might be vulnerable to TOCTOU attack.

### Security and Support

This script is not the most secure installation of Docker in rootless mode and infact sets things up in an unsupported manor, however, as CentOS 7 doesn't support `systemctl --user` this is the best way of managing the service.

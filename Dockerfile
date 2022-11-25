FROM jupyter/scipy-notebook:ubuntu-18.04
LABEL maintainer="Mark Bentley"
LABEL version=0.2

# Run system updates
USER root
RUN apt-get update

# Install xvfb and X depnedencies
RUN apt-get install -y -q xvfb x11vnc x11-xkb-utils xfonts-100dpi xfonts-75dpi xfonts-scalable xfonts-cyrillic x11-apps

# Set up the virtual frame buffer service
RUN mkdir /var/run/xvfb
RUN chown $NB_UID:users /var/run/xvfb
ADD xvfb.init /etc/init.d/xvfb
RUN chmod +x /etc/init.d/xvfb
RUN update-rc.d xvfb defaults

# Install gwyddion
RUN apt-get update -q && apt-get install -y -q gwyddion gwyddion-plugins

# Install glib and other dependencies
RUN apt-get install -y -q libglib2.0-dev python-gobject-2-dev python-gobject python-gtk2

USER $NB_UID

# remove pinned packaqges - not needed?
# RUN rm /opt/conda/conda-meta/pinned

# update conda to latest
RUN conda update -n base conda

# disble channel priority, which breaks the python2 install
RUN conda config --set channel_priority disabled

# New attempt to create the environment
ADD environment.yml /tmp/environment.yml
RUN conda env create -f /tmp/environment.yml

# initialise conda
RUN conda init

# Make subsequent RUN commands use the newn environment
SHELL ["conda", "run", "-n", "midas", "/bin/bash", "-c"]

# Set up the new kernel spec
RUN python -m ipykernel install --user --name midas --display-name "midas"

# clean up
RUN conda clean -pt -y

# install the MIDAS base code
RUN pip install git+https://github.com/msbentley/midas

USER root

# Perform the symbolic linking of Gwyddion libraries to the environment
RUN ln -s /usr/lib/python2.7/dist-packages/gwy.so /opt/conda/envs/midas/lib/python2.7/site-packages/ \
    && ln -s /usr/share/gwyddion/pygwy/gwyutils.py /opt/conda/envs/midas/lib/python2.7/site-packages/ \
    && ln -s /usr/lib/python2.7/dist-packages/gobject /opt/conda/envs/midas/lib/python2.7/site-packages/ \
    && ln -s /usr/lib/python2.7/dist-packages/glib/ /opt/conda/envs/midas/lib/python2.7/site-packages/ \
    && ln -s /usr/lib/python2.7/dist-packages/gtk-2.0 /opt/conda/envs/midas/lib/python2.7/site-packages/ \
    && ln -s /usr/lib/python2.7/dist-packages/pygtk.pth /opt/conda/envs/midas/lib/python2.7/site-packages/ \
    && ln -s /usr/lib/python2.7/dist-packages/cairo/ /opt/conda/envs/midas/lib/python2.7/site-packages/

# Hack the environment some more!
RUN ln -s /opt/conda/envs/midas/lib/python2.7/site-packages/glib/_glib.x86_64-linux-gnu.so /opt/conda/envs/midas/lib/python2.7/site-packages/glib/_glib.so \
    && ln -s /opt/conda/envs/midas/lib/python2.7/site-packages/gobject/_gobject.x86_64-linux-gnu.so /opt/conda/envs/midas/lib/python2.7/site-packages/gobject/_gobject.so \
    && ln -s /opt/conda/envs/midas/lib/python2.7/site-packages/gtk-2.0/gio/_gio.x86_64-linux-gnu.so /opt/conda/envs/midas/lib/python2.7/site-packages/gtk-2.0/gio/_gio.so \
    && ln -s /opt/conda/envs/midas/lib/python2.7/site-packages/cairo/_cairo.x86_64-linux-gnu.so /opt/conda/envs/midas/lib/python2.7/site-packages/cairo/_cairo.so
    
ADD run_xvfb.sh /usr/local/bin/start-notebook.d/
RUN chmod +x /usr/local/bin/start-notebook.d/run_xvfb.sh

USER $NB_UID

# Set up the frame buffer
ENV DISPLAY :1

# Push the MIB ASCII export files
COPY rmib /home/$NB_USER/rmib

# Set some environment variables
ENV S2K_PATH /home/$NB_USER/rmib
ENV JUPYTER_ENABLE_LAB=yes

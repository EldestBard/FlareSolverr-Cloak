FROM python:3.13-slim-bookworm AS builder

# Build dummy packages to skip installing them and their dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends equivs \
    && equivs-control libgl1-mesa-dri \
    && printf 'Section: misc\nPriority: optional\nStandards-Version: 3.9.2\nPackage: libgl1-mesa-dri\nVersion: 99.0.0\nDescription: Dummy package for libgl1-mesa-dri\n' >> libgl1-mesa-dri \
    && equivs-build libgl1-mesa-dri \
    && mv libgl1-mesa-dri_*.deb /libgl1-mesa-dri.deb \
    && equivs-control adwaiticona-theme \
    && printf 'Section: misc\nPriority: optional\nStandards-Version: 3.9.2\nPackage: adwaita-icon-theme\nVersion: 99.0.0\nDescription: Dummy package for adwaita-icon-theme\n' >> adwaita-icon-theme \
    && equivs-build adwaita-icon-theme \
    && mv adwaita-icon-theme_*.deb /adwaita-icon-theme.deb

FROM python:3.13-slim-bookworm

# Copy dummy packages
COPY --from=builder /*.deb /

# Install dependencies and create flaresolverr user
WORKDIR /app

# Install dummy packages to satisfy chromium dependencies
RUN dpkg -i /libgl1-mesa-dri.deb \
    && dpkg -i /adwaita-icon-theme.deb \
    # Install dependencies
    && apt-get update \
    && apt-get install -y --no-install-recommends chromium chromium-common chromium-driver xvfb dumb-init \
        procps curl vim xauth \
    # Remove temporary files and hardware decoding libraries
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /usr/lib/x86_64-linux-gnu/libmfxhw* \
    && rm -f /usr/lib/x86_64-linux-gnu/mfx/* \
    # Create flaresolverr user
    && useradd --home-dir /app --shell /bin/sh flaresolverr \
    && mv /usr/bin/chromedriver chromedriver \
    && chown -R flaresolverr:flaresolverr . \
    # Create config dir
    && mkdir /config \
    && chown flaresolverr:flaresolverr /config

# Download and install CloakBrowser for anti-detection browsing
# See: https://github.com/CloakHQ/CloakBrowser
ENV CLOAKBROWSER_VERSION=chromium-v146.0.7680.177.4 \
    CLOAKBROWSER_PATH=/usr/local/bin/cloak-browser
RUN curl -sL https://github.com/CloakHQ/CloakBrowser/releases/download/${CLOAKBROWSER_VERSION}/cloakbrowser-linux-x64.tar.gz \
    -o /tmp/cloakbrowser.tar.gz \
    && tar -xzf /tmp/cloakbrowser.tar.gz -C /opt \
    && ln -sf /opt/cloakbrowser-linux-x64/cloakbrowser ${CLOAKBROWSER_PATH} \
    && rm /tmp/cloakbrowser.tar.gz \
    && chown -R flaresolverr:flaresolverr /opt/cloakbrowser-linux-x64

VOLUME /config

# Install Python dependencies
COPY requirements.txt .
RUN pip install --break-system-packages -r requirements.txt \
    # Remove temporary files
    && rm -rf /root/.cache

USER flaresolverr

RUN mkdir -p "/app/.config/chromium/Crash Reports/pending"

COPY src .
COPY package.json ../

EXPOSE 8191
EXPOSE 8192

# dumb-init avoids zombie chromium processes
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["/usr/local/bin/python", "-u", "/app/flaresolverr.py"]

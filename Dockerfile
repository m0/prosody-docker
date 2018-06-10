FROM debian:stretch-slim

LABEL vendor="oclab"
LABEL maintainer="M0 <mo@oclab.net>"

ENV DEBIAN_FRONTEND noninteractive

RUN set -ex; \
	apt-get update -qq; \
	apt-get install -y --no-install-suggests --no-install-recommends \
		apt-utils

RUN set -ex; \
	apt-get update -qq; \
	apt-get install -y --no-install-suggests --no-install-recommends \
		ca-certificates apt-transport-https gnupg2

ADD prosody-debian-packages.key /tmp/prosody-debian-packages.key
RUN apt-key add /tmp/prosody-debian-packages.key; rm -f /tmp/prosody-debian-packages.key

ADD prosody.list /etc/apt/sources.list.d/prosody.list

RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-suggests --no-install-recommends \
		lua-sec \
		lua-event \
		lua-zlib \
		lua-dbi-postgresql \
		lua-dbi-mysql \
		lua-dbi-sqlite3 \
		lua-bitop \
		lua-socket \
		lua-expat \
		lua-filesystem \
		prosody 

ADD configuration/prosody.cfg.lua /etc/prosody/prosody.cfg.lua
ADD configuration/conf.d/ /etc/prosody/conf.d/

RUN set -ex; \
	mkdir /etc/prosody/cmpt.d/ /etc/prosody/vhost.d/ \
		&& chown -R prosody:prosody /etc/prosody/ /var/lib/prosody/ \
		&& chmod -R 760 /etc/prosody/ /var/lib/prosody/

COPY entrypoint.pl /usr/local/bin/
ENTRYPOINT ["entrypoint.pl"]

HEALTHCHECK CMD /usr/bin/prosodyctl check

USER prosody:prosody
CMD ["prosodyctl", "start"]

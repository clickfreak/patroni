## This Dockerfile is meant to aid in the building and debugging patroni whilst developing on your local machine
## It has all the necessary components to play/debug with a single node appliance, running etcd
FROM ubuntu:14.04
MAINTAINER Feike Steenbergen <feike.steenbergen@zalando.de>

# We need curl
RUN apt-get update -y && apt-get install curl -y

# Add PGDG repositories
ENV DEBIAN_FRONTEND noninteractive
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get update -y \
        && apt-get upgrade -y \
        && apt-get install postgresql-common -y \
        && sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf

ENV PGVERSION 9.5
RUN apt-get install postgresql-${PGVERSION} postgresql-contrib-${PGVERSION} postgresql-server-dev-${PGVERSION} -y \
        && apt-get install python python-dev python-pip libyaml-dev -y

ADD requirements.txt /requirements.txt
RUN pip install -r /requirements.txt

ENV PATH /usr/lib/postgresql/${PGVERSION}/bin:$PATH

ADD patroni.py /patroni.py
ADD patronictl.py /patronictl.py
ADD patroni/ /patroni

RUN ln -s /patroni.py /usr/local/bin/patroni
RUN ln -s /patronictl.py /usr/local/bin/patronictl

ENV ETCDVERSION 2.3.4
RUN curl -L https://github.com/coreos/etcd/releases/download/v${ETCDVERSION}/etcd-v${ETCDVERSION}-linux-amd64.tar.gz | tar xz -C /bin --strip=1 --wildcards --no-anchored etcd etcdctl

### Setting up a simple script that will serve as an entrypoint
RUN mkdir /data/ && touch /var/log/etcd.log /var/log/etcd.err /pgpass /patroni/postgres.yml
RUN chown postgres:postgres -R /patroni/ /data/ /pgpass /var/log/etcd.* /patroni/postgres.yml
ADD docker/entrypoint.sh /entrypoint.sh

EXPOSE 4001 5432 2380

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
USER postgres

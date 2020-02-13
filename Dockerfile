FROM alpine:3.10
MAINTAINER Deer Spangle <deer@spangle.org.uk>

ENV BUILD_PACKAGES bash curl-dev ruby-dev build-base
ENV RUBY_PACKAGES ruby ruby-dev ruby-bigdecimal ruby-json ruby-io-console ruby-bundler
ENV REDIS_PACKAGES redis

# Update and install all of the required packages.
# At the end, remove the apk cache
RUN apk update && \
    apk upgrade && \
    apk add $BUILD_PACKAGES && \
    apk add $RUBY_PACKAGES && \
    apk add $REDIS_PACKAGES && \
    rm -rf /var/cache/apk/*

RUN mkdir /usr/faexport
WORKDIR /usr/faexport

COPY Gemfile /usr/faexport/
COPY Gemfile.lock /usr/faexport/
RUN bundle install

COPY . /usr/faexport

EXPOSE 9292/tcp

#CMD bundle exec rackup config.ru -p 9292 --host 0.0.0.0
ENTRYPOINT ["sh","/usr/faexport/entrypoint.sh"]
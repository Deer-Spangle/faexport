# FAExport

[![Build Status](https://travis-ci.org/Deer-Spangle/faexport.svg?branch=master)](https://travis-ci.org/Deer-Spangle/faexport)
[![Docker Build Status](https://img.shields.io/docker/cloud/build/deerspangle/furaffinity-api)](https://hub.docker.com/r/deerspangle/furaffinity-api)
[![Uptime Robot status](https://img.shields.io/uptimerobot/status/m784269615-b492eb3eab4a670e1cd8ab89)](http://faexport.spangle.org.uk)

Simple data export and feeds from FA.
Check out the [documentation](http://faexport.spangle.org.uk/docs) for a full list of functionality.
The file `lib/faexport/scraper.rb` contains all the code required to access data from FA.

This API was originally developed by [boothale](https://github.com/boothale/), but after he had been missing and not 
responding to emails for many months, deer-spangle has forked it and taken care of it instead.

## Authentication

When attempting to use endpoints which require a login cookie to be supplied, or running your own copy of the API, you will need to generate a valid FA cookie string.  
A valid FA cookie string looks like this:
```
"b=3a485360-d203-4a38-97e8-4ff7cdfa244c; a=b1b985c4-d73e-492a-a830-ad238a3693ef"
```
The cookie `a` and `b` values can be obtained by checking your browser's storage inspector while on any FA page.  
The storage inspector can be opened by pressing `Shift+F9` on Firefox, and on Chrome, by opening the developer tools with `F12` and then selecting the "Application" tab, and then "Cookies".  
You may want to do this in a private browsing session as logging out of your account will invalidate
the cookie and break the scraper.

To authenticate with the API, you will need to provide that string in the FA_COOKIE header. (Header. Not a cookie)


## Development Setup

Create a file named `settings.yml` in the root directory containing a valid FA cookie:

```yaml
cookie: "b=3a485360-d203-4a38-97e8-4ff7cdfa244c; a=b1b985c4-d73e-492a-a830-ad238a3693ef"
```

Install [Redis](http://redis.io/), [Ruby](https://www.ruby-lang.org/) and [Bundler](http://bundler.io/),
run `bundle install` then `bundle exec rackup config.ru` to get a development server running.
For example, on a Debian based system you would run:

```text
sudo apt-get install redis-server ruby ruby-dev
sudo gem install bundler
bundle install
bundle exec rackup config.ru
```


## Deploying - Docker

This application is available as a docker image, so that you don't need to install ruby, and bundler and packages and such.
The docker image is available on docker hub here:
https://hub.docker.com/r/deerspangle/furaffinity-api

You can run the docker image like so, starting up the redis container, then starting the FA API container and specifying your FA cookie in the environment variable passed into the image.
```shell script
docker run --name redis_container -d redis 

docker run \
  -e FA_COOKIE="b=..; a=.." \
  -e REDIS_URL="redis://redis:6379/0"
  -p 80:9292 \
  --name fa_api \
  --link redis_container:redis \
  deerspangle/furaffinity-api
```
Internal to the docker image, the API exposes port 9292, you can forward that to whichever port you want outside with the `-p` option, in the case above, we're forwarding port 80 into it.

If cloudflare protection is online, you can specify an environment variable "CF_BYPASS" as a URL to a cloudflare bypass proxy.

## Deploying - Heroku

This application can be run on Heroku, just add an instance of 'Redis To Go' for caching.
Rather than uploading `settings.yml`, set the environment variable `FA_COOKIE`
to the generated cookie you gathered from FA.

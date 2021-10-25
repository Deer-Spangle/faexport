# FAExport

![regression-tests](https://github.com/Deer-Spangle/faexport/workflows/regression-tests/badge.svg)
![Docker Image Version (latest semver)](https://img.shields.io/docker/v/deerspangle/furaffinity-api?label=docker%20version&sort=semver)
[![Uptime Robot status](https://img.shields.io/uptimerobot/status/m784269615-b492eb3eab4a670e1cd8ab89)](http://faexport.spangle.org.uk)

Simple data export and feeds from FA.
Check out the [documentation](http://faexport.spangle.org.uk/docs) for a full list of functionality.
The file `lib/faexport/scraper.rb` contains all the code required to access data from FA.

This API was originally developed by [boothale](https://github.com/boothale/), but after he had been missing and not 
responding to emails for many months, [deer-spangle](https://github.com/Deer-Spangle) has forked it and taken care of 
it instead.

## Authentication

When attempting to use endpoints which require a login cookie to be supplied, or running your own copy of the API, you 
will need to generate a valid FA cookie string.  
A valid FA cookie string looks like this:
```
"b=3a485360-d203-4a38-97e8-4ff7cdfa244c; a=b1b985c4-d73e-492a-a830-ad238a3693ef"
```
The cookie `a` and `b` values can be obtained by checking your browser's storage inspector while on any FA page.  
The storage inspector can be opened by pressing `Shift+F9` on Firefox, and on Chrome, by opening the developer tools 
with `F12` and then selecting the "Application" tab, and then "Cookies".  
You may want to do this in a private browsing session as logging out of your account will invalidate
the cookie and break the scraper.
This cookie must be for an account that is set to view the site in classic mode. Modern style cannot be parsed by this API.

To authenticate with the API, you will need to provide that string in the FA_COOKIE header. (Header. Not a cookie)


## Development Setup
If you simply run:
```
make install
make run
```
It should install required packages, and then run the server, though it may warn of a missing FA_COOKIE environment 
variable.

You can customise the FA_COOKIE value and PORT by passing them like so:
```
make FA_COOKIE="b\=...\;a\=..." PORT=9292 run
```


For ease of development you can remove the need to specify an environment variable for the furaffinity cookie by 
creating a file named `settings.yml` in the root directory containing a valid FA cookie:
```yaml
cookie: "b=3a485360-d203-4a38-97e8-4ff7cdfa244c; a=b1b985c4-d73e-492a-a830-ad238a3693ef"
```

## Deploying - Docker

This application is available as a docker image, so that you don't need to install ruby, and bundler and packages and 
such.
The docker image is available on docker hub here:
https://hub.docker.com/r/deerspangle/furaffinity-api

But to deploy a redis image and furaffinity API docker container, linked together, you can run
```shell script
FA_COOKIE="b\=...\;a\=..." docker-compose up
```
or simple
```shell script
make FA_COOKIE="b\=...\;a\=..." deploy
```
It will default to being exposed on port 80, but you can customise this by passing in the PORT environment variable.
```shell script
make FA_COOKIE="b\=...\;a\=..." PORT=9292 deploy
```

If cloudflare protection is online, you can launch a pair of cloudflare bypass containers alongside the API rather easily:
```shell script
make FA_COOKIE="b\=...\;a\=..." deploy_bypass
```

## Deploying - Heroku

This application can be run on Heroku, just add an instance of 'Redis To Go' for caching.
Rather than uploading `settings.yml`, set the environment variable `FA_COOKIE`
to the generated cookie you gathered from FA.

## Prometheus metrics and security

There are a number of metrics exposed at `/metrics`, which can be used for observability and such.
Metrics are available for deployed version, error rates, request/response times, and usage patterns between endpoints and format types.
Metrics are grouped into API metrics, and scraper metrics. Scraper metrics are prefixed with "faexport_scraper", API endpoint metrics are prefixed with "faexport_endpoint", and all others are prefixed with just "faexport_".

The prometheus metrics endpoint can be secured with basic auth by passing a PROMETHEUS_PASS environment variable. This will set the password for the `/metrics` endpoint, with a blank username. This environment variable can be passed to locally running instances, or to docker or docker compose.


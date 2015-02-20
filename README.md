FAExport
========

Simple data export and feeds from FA.

You'll need to provide valid account credentials either:

* In a file named `settings.yml` in the root directory with the fields `username` and `password`
* Via the environment variables `FD_USERNAME` and `FD_PASSWORD`

This app can be deplyed on Heroku, just add an instance of 'Redis To Go' for caching.
To run locally, install redis, run `bundle install` then `bundle exec rackup config.ru`.

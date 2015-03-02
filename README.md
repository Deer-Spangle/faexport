FAExport
========

Simple data export and feeds from FA.
Check out the [documentation](http://faexport.boothale.net/docs/) for a full list of functionality.
The file `lib/faexport/scraper.rb` contains all the code required to access data from FA.

Development Setup
-----------------

Create a file named `settings.yml` in the root directory containing a valid FA account/password:

~~~yaml
username: myaccount
password: mypassword
~~~

Install [Redis](http://redis.io/), [Ruby](https://www.ruby-lang.org/) and [Bundler](http://bundler.io/),
run `bundle install` then `bundle exec rackup config.ru` to get a development server running.
For example, on a Debian based system you would run:

~~~text
sudo apt-get install redis ruby ruby-dev
sudo gem install bundler
bundle install
bundle exec rackup config.ru
~~~

Deploying
---------

This application can be run on Heroku, just add an instance of 'Redis To Go' for caching.
Rather than uploading `settings.yml`, set the environment variables `FA_USERNAME` and `FA_PASSWORD`
to the username and password you want to use.

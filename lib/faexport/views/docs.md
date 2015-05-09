All routes should have a format appended.  Possible formats are `json`, `xml` and `rss`.
For example, to get json data about Fender's profile, you could request `/user/fender.json`.
RSS feeds are only available on 'list' type data and contain actual info rather than just ids.
For this reason they are limited to the first 10 items and can take a bit longer to load.
Everything is cached for 30 seconds so spamming requests won't do anything.
Please report any bugs to [erra@boothale.net](mailto:erra@boothale.net).

## /user/*{name}*

General information about a user's account.

*Formats:* `json`, `xml`

~~~json
{
  "id": "8",
  "name": "Fender",
  "profile": "http://www.furaffinity.net/user/fender/",
  "account_type": "Administrator",
  "avatar": "http://a.facdn.net/1424255659/fender.gif",
  "full_name": "Fender!",
  "artist_type": "Watcher",
  "registered_since": "December 4th, 2005 10:49",
  "registered_at": "2005-12-04T10:49:00Z",
  "current_mood": "accomplished",
  "artist_profile": "<snip>",
  "pageviews": "532635",
  "submissions": "12",
  "comments_received": "35800",
  "comments_given": "910",
  "journals": "113",
  "favorites": "6388"
}
~~~

## /user/*{name}*/watching

Accounts that the user is watching.
By default, the first 200 users are returned.
You can pass a parameter `?page=2` to load more.

*Formats:* `json`, `xml`

~~~json
[
  "fender",
  "bender",
  "dragoneer",
  <snip>
]
~~~

## /user/*{name}*/watchers

Accounts that are watching the specified user.
By default, the first 200 users are returned.
You can pass a parameter `?page=2` to load more.

*Formats:* `json`, `xml`

~~~json
[
  "fennic288",
  "catsgotyourbag",
  "stalkingturtle",
  <snip>
]
~~~

## /user/*{name}*/shouts

All shouts that are visible on a user's page.

*Formats:* `json`, `xml`, `rss`

~~~json
[
  {
    "id": "shout-260397",
    "name": "SomeArtist",
    "profle": "http://www.furaffinity.net/user/someartist/",
    "avatar": "http://a.facdn.net/1424258659/someartist.gif",
    "posted": "March 2nd, 2015 02:30 AM",
    "posted_at": "2015-03-02T02:30:00Z",
    "text": "Thanks for the watch!"
  },
  {
    "id": "shout-252377",
    "name": "AssConnoisseur",
    "profle": "http://www.furaffinity.net/user/assconnoisseur/",
    "avatar": "http://a.facdn.net/1449252689/assconnoisseur.gif",
    "posted": "March 1st, 2015 03:16 PM",
    "posted_at": "2015-03-01T15:16:00Z",
    "text": "You have a very fine rear end"
  },
  {
    "id": "shout-236568",
    "name": "HyperSquirrel",
    "profle": "http://www.furaffinity.net/user/hypersquirrel/",
    "avatar": "http://a.facdn.net/6442272989/hypersquirrel.gif",
    "posted": "February 28th, 2015 06:33 AM",
    "posted_at": "2015-02-28T06:33:00Z",
    "text": "OMG yr cute, wanna RP"
  },
  <snip>
]
~~~

## /user/*{name}*/journals

Return all journals posted by a user.

*Formats:* `json`, `xml`

By default, this only returns the id of each journal.

~~~json
[
  "6700663",
  "6689390",
  "6636092",
  <snip>
]
~~~

If you want more information, pass `?full=1` to retrieve more fields.

~~~json
[
  {
    "id": "6700663",
    "title": "FA United 2015 Site Live",
    "description": "<snip>",
    "link": "http://www.furaffinity.net/journal/6700663/",
    "posted": "April 30th, 2015 05:27 PM",
    "posted_at": "2015-04-30T17:27:00Z"
  },
  {
    "id": "6689390",
    "title": "4/26/2015 - Site & Beta Update (update 4)",
    "description": "<snip>",
    "link": "http://www.furaffinity.net/journal/6689390/",
    "posted": "April 26th, 2015 06:04 PM",
    "posted_at": "2015-04-26T18:04:00Z"
  },
  {
    "id": "6636092",
    "title": "FA UI Early Beta Preview",
    "description": "<snip>",
    "link": "http://www.furaffinity.net/journal/6636092/",
    "posted": "April 5th, 2015 07:12 PM",
    "posted_at": "2015-04-05T19:12:00Z"
  },
  <snip>
]
~~~

## /user/*{name}*/*{folder}*

Gets the the first few submissions from the specified folder.
Options for `{folder}` are `gallery`, `scraps` and `favorites`.
By default, the first 60 submissions are returned.
You can pass a parameter `?page=2` to load more.

*Formats:* `json`, `xml`, `rss`

By default, this only returns the id of each submission.

~~~json
[
  "12239491",
  "11157906",
  "10796676",
  <snip>
}
~~~

If you want more information, pass `?full=1` to retrieve more fields.

~~~json
[
  {
    "id": "3277777",
    "title": "Epic Five Year Post of Maximum Relaxation (and Carnage)",
    "thumbnail": "http://t.facdn.net/3277777@200-1263612598.jpg",
    "link": "http://www.furaffinity.net/view/3277777/"
  },
  {
    "id": "1896964",
    "title": "Epic Four Year Post of City Crunching Havoc",
    "thumbnail": "http://t.facdn.net/1896964@200-1232143532.jpg",
    "link": "http://www.furaffinity.net/view/1896964/"
  },
  {
    "id": "1010790",
    "title": "Epic Three Year Post of Tie Wearing Destruction",
    "thumbnail": "http://t.facdn.net/1010790@200-1200494770.jpg",
    "link": "http://www.furaffinity.net/view/1010790/"
  }
  <snip>
]
~~~

## /submission/*{id}*

Retrieves information about the submission with the specified id.

*Formats:* `json`, `xml`

~~~json
{
  "title": "Fender (Character Sheet)",
  "description": "<snip>",
  "name": "Fender",
  "profile": "http://www.furaffinity.net/user/fender/",
  "link": "http://www.furaffinity.net/view/4483888/",
  "posted": "September 16th, 2010 08:21 PM",
  "posted_at": "2010-09-16T20:21:00Z",
  "full": "http://d.facdn.net/art/fender/1284661300/1284661300.fender_fender.png",
  "thumbnail": "http://t.facdn.net/4483888@400-1284661300.jpg",
  "category": "Artwork (Digital)",
  "theme": "Doodle",
  "species": "Unspecified / Any",
  "gender": "Male",
  "favorites": "979",
  "comments": "137",
  "views": "22673",
  "resolution": "1146x707",
  "rating": "General",
  "keywords": [
    "fender",
    "ferrox",
    "fur",
    "affinity",
    "mascot",
    "character",
    "sheet"
  ]
}
~~~

## /journal/*{id}*

Retrieves information about the journal with the specified id.

*Formats:* `json`, `xml`

~~~json
{
  "title": "Banner Update",
  "description": "Just a quick update... <snip>",
  "name": "Fender",
  "profile": "http://www.furaffinity.net/user/fender/",
  "link": "http://www.furaffinity.net/journal/6534234/",
  "posted": "February 26th, 2015 07:53 PM",
  "posted_at": "2015-02-26T19:53:00Z"
}
~~~

## /submission/*{id}*/comments

Retrivies a list of comments made on the submission with the specified id.

*Formats:* `json`, `xml`

~~~json
[
  {
    "id": "260397",
    "name": "AnotherArtist",
    "profle": "http://www.furaffinity.net/user/anotherartist/",
    "avatar": "http://a.facdn.net/1424258659/anotherartist.gif",
    "posted": "March 2nd, 2015 02:30 AM",
    "posted_at": "2015-03-02T02:30:00Z",
    "text": "Wow, I love the way you do light and shadow."
  },
  {
    "id": "252377",
    "name": "AnnoyingSalamander",
    "profle": "http://www.furaffinity.net/user/annoyingsalamander/",
    "avatar": "http://a.facdn.net/1424258659/annoyingsalamander.gif",
    "posted": "March 1st, 2015 03:16 PM",
    "posted_at": "2015-03-01T15:16:00Z",
    "text": "This drawing sucks."
  },
  {
    "id": "236568",
    "name": "afreshcat001",
    "profle": "http://www.furaffinity.net/user/afreshcat001/",
    "avatar": "http://a.facdn.net/1424258659/afreshcat001.gif",
    "posted": "February 28th, 2015 06:33 AM",
    "posted_at": "2015-02-28T06:33:00Z",
    "text": "You stole my OC, REPORTED!"
  },
  <snip>
]
~~~

## /journal/*{id}*/comments

Retrivies a list of comments made on the journal with the specified id.

*Formats:* `json`, `xml`

~~~json
[
  {
    "id": "260397",
    "name": "DogFrogLog",
    "profle": "http://www.furaffinity.net/user/dogfroglog/",
    "avatar": "http://a.facdn.net/1424258659/dogfroglog.gif",
    "posted": "March 2nd, 2015 02:30 AM",
    "posted_at": "2015-03-02T02:30:00Z",
    "text": "Glad to hear your doing better."
  },
  {
    "id": "252377",
    "name": "JusticeBeaver",
    "profle": "http://www.furaffinity.net/user/justicebeaver/",
    "avatar": "http://a.facdn.net/1424258659/justicebeaver.gif",
    "posted": "March 1st, 2015 03:16 PM",
    "posted_at": "2015-03-01T15:16:00Z",
    "text": "Any idea when you'll be working on my piece again?"
  },
  {
    "id": "236568",
    "name": "wereplatypus2008",
    "profle": "http://www.furaffinity.net/user/wereplatypus2008/",
    "avatar": "http://a.facdn.net/1424258659/wereplatypus2008.gif",
    "posted": "February 28th, 2015 06:33 AM",
    "posted_at": "2015-02-28T06:33:00Z",
    "text": "Everyone check out my art!"
  },
  <snip>
]
~~~

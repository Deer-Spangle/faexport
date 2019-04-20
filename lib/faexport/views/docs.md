This API can be considered fully stable and will not have backwards incompatible changes made (when possible).
In the case that the markup on FA changes in a way that prevents this API from functioning,
a best effort will be made to update and maintain it (aka uptime not guaranteed).
All requests and data returned from FA are cached for 30 seconds so spamming requests won't do anything.
Be aware that this service runs on limited hardware and is not intended for heavy usage.
Please send any questions, comments or ramblings to [erra@boothale.net](mailto:erra@boothale.net).

## Security

When accessing routes that view or modify account specific data,
you will need to provide a login cookie in the header `FA_COOKIE`.
Run this code in the console of any FA page to get one.

~~~javascript
document.cookie.split('; ').filter(function(x){return/^[ab]=/.test(x)}).sort().reverse().join('; ')
~~~

The output should look something like this:

~~~javascript
"b=3a485360-d203-4a38-97e8-4ff7cdfa244c; a=b1b985c4-d73e-492a-a830-ad238a3693ef"
~~~

If you're having trouble with this, check out [issue 17](https://github.com/boothale/faexport/issues/17).

## Status Codes

In the case of an error, the response will be returned as json with an `error` field
giving details of what happened and a `url` field that includes any FA url that the
error originated from.

~~~json
{
  "error": "Something bad happened",
  "url": "http://www.furaffinity.net/"
}
~~~

### 200 OK

Standard response if everything went well.

### 400 Bad Request

You probably sent an incorrect parameter or didn't include a valid login cookie.
Check the error returned for more information.

### 401 Unauthorized

The login cookie you provided didn't not provide access to a users page.
This is most likely due to an unauthorized or old cookie.

### 404 Not Found

This error is typically returned when you try to access a page that doesn't exist
or a user who has disabled their profile page.

### 500 Internal Server Error

Generic error returned when FAExport encounters some sort of internal error.
This can be anything from the cache going offline to changes in markup breaking the scraper.

### 502 Bad Gateway

A request to FA came back with some sort of error code.

### 503 Service Unavailable

This typically means that the scraper was unable to properly log into FA and/or access the page you want.
Try again later.

## Routes

All routes that return data should have a format appended.  Possible formats are `json`, `xml` and `rss`.
For example, to get json data about Fender's profile, you could request `/user/fender.json`.
All routes that modify data should have the format of the data you will be sending to them.
For example, to post a journal using json data, you would make a request to `/journal.json`.
RSS feeds are only available on 'list' type data and contain actual info rather than just ids.
For this reason they are limited to the first 10 items and can take a bit longer to load.
If you want to return only SFW results, you can add `?sfw=1` to any url.

### GET /home

Fetches all the latest posts from the home page

*Formats:* `json`, `xml`

~~~json
{
  "artwork": [
    {
      "id": "27085784",
      "title": "Stress relief",
      "thumbnail": "http://t.facdn.net/27085784@200-1524291669.jpg",
      "link": "https://www.furaffinity.net/view/27085784/"
    },
    <snip>
  ],
  "writing": [
    {
      "id": "27085745",
      "title": "Fate: chapter 1, bonus",
      "thumbnail": "http://t.facdn.net/27085745@400-1524291268.jpg",
      "link": "https://www.furaffinity.net/view/27085745/"
    },
    <snip>
  ],
  "music": [
    {
      "id": "27085580",
      "title": "os_v2.5",
      "thumbnail": "http://t.facdn.net/27085580@75-1524289114.jpg",
      "link": "https://www.furaffinity.net/view/27085580/"
    },
    <snip>
  ],
  "crafts": [
    {
      "id": "27085767",
      "title": "Kamadan wearing the Amazing Spider-Man Mk.4 Suit/Armor",
      "thumbnail": "http://t.facdn.net/27085767@400-1524291459.jpg",
      "link": "https://www.furaffinity.net/view/27085767/"
    },
    <snip>
  ]
}
~~~

### GET /user/*{name}*

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
  "user_title": "Watcher",
  "registered_since": "December 4th, 2005 10:49",
  "registered_at": "2005-12-04T10:49:00Z",
  "current_mood": "accomplished",
  "artist_profile": "<snip>",
  "pageviews": "532635",
  "submissions": "12",
  "comments_received": "35800",
  "comments_given": "910",
  "journals": "113",
  "favorites": "6388",
  "featured_submission": {
    "id": "4483888",
    "title": "Fender (Character Sheet)",
    "thumbnail": "http://t.facdn.net/4483888@200-1284661300.jpg",
    "link": "http://www.furaffinity.net/view/4483888/"
  },
  profile_id": {
    "id": "1345722",
    "title": "",
    "thumbnail": "http://t.facdn.net/1345722@300-1212292592.jpg",
    "link": "http://www.furaffinity.net/view/1345722/"
  },
  "artist_information": {
    "Species": "Ferrox (Mustlidae Vulpis Vulpis)",
    "Shell of choice": "Pistachio",
    "Operating system": "FeNDOS",
    "Personal quote": "'My error code just gained a level! It's now at 504!'",
    "Favorite animal": "James Belushi",
    "Favorite website": "<a href=\"http://www.furaffinity.net\" title=\"http://www.furaffinity.net\" class=\"auto_link\">http://www.furaffinity.net</a>",
    "Favorite food": "You!"
  },
  "contact_information": [
    {
      "title": "AIM",
      "name": "FenderFA",
      "link": ""
    }
  ],
  "watchers": {
    "count": 11769,
    "recent": [
      {
        "name": "fennic288",
        "link": "http://www.furaffinity.net/fennic288"
      },
      <snip>
    ]
  },
  "watching": {
    "count": 87,
    "recent": [
      {
        "name": "catsgotyourbag",
        "link": "http://www.furaffinity.net/catsgotyourbag"
      },
      <snip>
    ]
  }
}
~~~

### GET /user/*{name}*/watching <br/> GET /user/*{name}*/watchers

Accounts that are watching or watched by the specified user.
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

### GET /user/*{name}*/shouts

All shouts that are visible on a user's page.

*Formats:* `json`, `xml`, `rss`

~~~json
[
  {
    "id": "shout-260397",
    "name": "SomeArtist",
    "profile": "http://www.furaffinity.net/user/someartist/",
    "profile_name": "someartist",
    "avatar": "http://a.facdn.net/1424258659/someartist.gif",
    "posted": "March 2nd, 2015 02:30 AM",
    "posted_at": "2015-03-02T02:30:00Z",
    "text": "Thanks for the watch!"
  },
  {
    "id": "shout-252377",
    "name": "AssConnoisseur",
    "profile": "http://www.furaffinity.net/user/assconnoisseur/",
    "profile_name": "assconnoisseur",
    "avatar": "http://a.facdn.net/1449252689/assconnoisseur.gif",
    "posted": "March 1st, 2015 03:16 PM",
    "posted_at": "2015-03-01T15:16:00Z",
    "text": "You have a very fine rear end"
  },
  {
    "id": "shout-236568",
    "name": "HyperSquirrel",
    "profile": "http://www.furaffinity.net/user/hypersquirrel/",
    "profile_name": "hypersquirrel",
    "avatar": "http://a.facdn.net/6442272989/hypersquirrel.gif",
    "posted": "February 28th, 2015 06:33 AM",
    "posted_at": "2015-02-28T06:33:00Z",
    "text": "OMG yr cute, wanna RP"
  },
  <snip>
]
~~~

### GET /user/*{name}*/commissions

Returns all the information listed on a users Commission Info page.

*Formats:* `json`, `xml`

~~~json
[
  {
    "title": "DO or DON'T",
    "price": "EUR 0.00",
    "description": "<snip>",
    "submission": {
      "id": "",
      "title": "",
      "thumbnail": "http://t.facdn.net/404_thumbnail.gif",
      "link": "http://www.furaffinity.net/"
    }
  },
  {
    "title": "Digital painting",
    "price": "EUR 180.00",
    "description": "<snip>",
    "submission": {
      "id": "12921627",
      "title": "",
      "thumbnail": "http://t.facdn.net/12921627@200-1394373667.jpg",
      "link": "http://www.furaffinity.net/view/12921627"
    }
  },
  <snip>
]
~~~

### GET /user/*{name}*/journals

Return all journals posted by a user.
You can pass a parameter `?page=2` to load more.

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

### GET /user/*{name}*/*{folder}*

Gets the the first few submissions from the specified folder.
Options for `{folder}` are `gallery`, `scraps` and `favorites`.
By default, the first 60 submissions are returned.

If this is `gallery` or `scraps`, you can pass a parameter `?page=2` to load more.

**BREAKING CHANGE**

Due to FA changing the way it handles pagination on favorites using `page` will no longer work.
Instead, all favorites all now come with a `fav_id` field (assuing `?full=1` is used) that can be used with `next` and `prev`.
For instance if the last favorite fetched has an `fav_id` of `29980`, we can set `?next=29980` to
load the next set of favorites that come after it.
Likewise we can also use `?prev=29980` to load the set of favorites directly before it.

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

To return deleted items as well, pass `?include_deleted=1`.
Deleted submissions are displayed in the following format:

~~~json
{
  "id": "",
  "title": "Submission has been deleted",
  "thumbnail": "http:/themes/classic/img/submission-message-deleted.gif",
  "link": "http://www.furaffinity.net/"
}
~~~

### GET /submission/*{id}*

Retrieves information about the submission with the specified id.
Note: the "full" and "thumbnail" members are parsed from the image viewer javascript snippet, the "download" is parsed from the "Download" link. When getting a non-image submission, the "thumbnail" and "full" members are null, but the "download" is guaranteed to point to the submission.

*Formats:* `json`, `xml`

~~~json
{
  "title": "Fender (Character Sheet)",
  "description": "<a href=\"/user/fender/\"><img class=\"avatar\" ... <snip>",
  "description_body": "The official Fender character sheet... <snip>",
  "name": "Fender",
  "profile": "https://www.furaffinity.net/user/fender/",
  "profile_name": "fender",
  "avatar": "https://a.facdn.net/1424255659/fender.gif",
  "link": "https://www.furaffinity.net/view/4483888/",
  "posted": "Sep 16th, 2010 06:21 PM",
  "posted_at": "2010-09-16T18:21:00Z",
  "download": "http://d.facdn.net/art/fender/1284661300/1284661300.fender_fender.png",
  "full": "http://d.facdn.net/art/fender/1284661300/1284661300.fender_fender.png",
  "thumbnail": "http://t.facdn.net/4483888@400-1284661300.jpg",
  "category": "Artwork (Digital)",
  "theme": "Doodle",
  "species": "Unspecified / Any",
  "gender": "Male",
  "favorites": "1129",
  "comments": "148",
  "views": "34036",
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

### GET /journal/*{id}*

Retrieves information about the journal with the specified id.

*Formats:* `json`, `xml`

~~~json
{
  "title": "Banner Update",
  "description": "<div class=\"journal-body\">\nJust a quick update... <snip>",
  "journal_header": null,
  "journal_body": "Just a quick update...<snip>",
  "journal_footer": "<strong class=\"bbcode bbcode_b\">... <snip>",
  "name": "Fender",
  "profile": "http://www.furaffinity.net/user/fender/",
  "profile_name": "fender",
  "avatar": "https://a.facdn.net/1424255659/fender.gif",
  "link": "http://www.furaffinity.net/journal/6534234/",
  "posted": "February 26th, 2015 07:53 PM",
  "posted_at": "2015-02-26T19:53:00Z"
}
~~~

### GET /submission/*{id}*/comments <br/> GET /journal/*{id}*/comments

Retrivies a list of comments made on the submission or journal with the specified id.

*Formats:* `json`, `xml`

~~~json
[
  {
    "id": "260397",
    "name": "AnotherArtist",
    "profile": "http://www.furaffinity.net/user/anotherartist/",
    "profile_name": "anotherartist",
    "avatar": "http://a.facdn.net/1424258659/anotherartist.gif",
    "posted": "March 2nd, 2015 02:30 AM",
    "posted_at": "2015-03-02T02:30:00Z",
    "text": "Wow, I love the way you do light and shadow."
    "reply_to": "",
    "reply_level": 0
  },
  {
    "id": "252377",
    "name": "AnnoyingSalamander",
    "profile": "http://www.furaffinity.net/user/annoyingsalamander/",
    "profile_name": "annoyingsalamander",
    "avatar": "http://a.facdn.net/1424258659/annoyingsalamander.gif",
    "posted": "March 1st, 2015 03:16 PM",
    "posted_at": "2015-03-01T15:16:00Z",
    "text": "This drawing sucks."
    "reply_to": "260397",
    "reply_level": 1
  },
  {
    "id": "236568",
    "name": "afreshcat001",
    "profile": "http://www.furaffinity.net/user/afreshcat001/",
    "profile": "afreshcat001",
    "avatar": "http://a.facdn.net/1424258659/afreshcat001.gif",
    "posted": "February 28th, 2015 06:33 AM",
    "posted_at": "2015-02-28T06:33:00Z",
    "text": "You stole my OC, REPORTED!"
    "reply_to": "",
    "reply_level": 0
  },
  <snip>
]
~~~

Any replies to a hidden comment will contain `"reply_to": "hidden"`.
By default, hidden comments are not included.
If you would like hidden comments to show up, pass `?include_hidden=1`.
Hidden comments are displayed in the following format:

~~~json
{
  "text": "Comment hidden by its author",
  "reply_to": "96267",
  "reply_level": 9
}

~~~

### GET /search

Perfoms a site wide search of Furaffinity.
The following parameters can be provided:

* **q**: Words to search for.
* **page**: Page of results to display.  Defaults to: `1`.
* **perpage**: How many results to display per page.  Can be one of: `24`, `36`, `48` or `60`.  Defaults to: `60`.
* **order_by**: How the results should be ordered.  Can be one of: `relevancy`, `date` or `popularity`.  Defaults to: `date`.
* **order_direction**: if results should be ordered in ascending or descending order.  Can be one of: `asc` or `desc`.  Defaults to: `desc`.
* **range**: How far in the past should results be loaded from.  Can be one of: `day`, `3days`, `week`, `month` or `all`.  Defaults to: `all`.
* **mode**: How the words from this search should be interpreted.  Can be one of: `all`, `any` or `extended`.  Defaults to: `extended`.
* **rating**: what rating levels are included.  Can be any of: `general`, `mature` and `adult` separated by commas.  Defaults to: `general,mature,adult`.
* **type**: Content type of results.  Can be any of: `art`, `flash`, `photo`, `music`, `story` and `poetry` separated by commas.  Defaults to: `art,flash,photo,music,story,poetry`.

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

If you want more information, pass `&full=1` to retrieve more fields.

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

### POST /journal

*Formats:* `json`, `query`

Posts a new journal.
The following parameters must be provided:

* **title**: The title of the journal.
* **description**: Body of the journal.

The response will contain the url of the created journal.

~~~json
{
  "url": "http://www.furaffinity.net/journal/6944093/"
}
~~~

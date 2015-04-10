All routes should have a format appended.  Possible formats are `json`, `xml` and `rss`.
For example, to get json data about Fender's profile, you could request `/user/fender.json`.
RSS feeds are only available on 'list' type data and contain actual info rather than just ids.
For this reason they take much longer to load and should only be checked periodically.
Everything is cached for 30 seconds so spamming requests won't do anything.
Please report any bugs to [erra@boothale.net](mailto:erra@boothale.net).

## /user/*{name}*

General information about a user's account.

*Formats:* `json`, `xml`

~~~json
{
  "name": "fender",
  "full_name": "Fender!",
  "artist_type": "Watcher",
  "registered_since": "December 5th, 2005 12:49",
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

## /user/*{name}*/shouts

All shouts that are visible on a user's page.

*Formats:* `json`, `xml`, `rss`

~~~json
[
  {
    "id": "shout-260397",
    "name": "SomeArtist",
    "posted": "March 2nd, 2015 02:30 AM",
    "text": "Thanks for the watch!"
  },
  {
    "id": "shout-252377",
    "name": "AssConnoisseur",
    "posted": "March 1st, 2015 03:16 PM",
    "text": "You have a very fine rear end"
  },
  {
    "id": "shout-236568",
    "name": "HyperSquirrel",
    "posted": "February 28th, 2015 06:33 AM",
    "text": "OMG yr cute, wanna RP"
  },
  <snip>
]
~~~

## /user/*{name}*/journals

The id's of all journals posted by a user.

*Formats:* `json`, `xml`

~~~json
[
  "6534234",
  "6395579",
  "6311970",
  <snip>
]
~~~

# /user/*{name}*/*{folder}*

Gets the id's of the first few submissions from the specified folder.
Options for `{folder}` are `gallery` and `scraps`.
By default, the first 60 submissions are returned.
You can pass a parameter `?page=2` to load more.

*Formats:* `json`, `xml`, `rss`

~~~json
[
  "12239491",
  "11157906",
  "10796676",
  <snip>
}
~~~

## /submission/*{id}*

Retrieves information about the submission with the specified id.

*Formats:* `json`, `xml`

~~~json
{
  "title": "Fender (Character Sheet)",
  "description": "<snip>",
  "link": "http://www.furaffinity.net/view/4483888/",
  "posted": "September 16th, 2010 08:21 PM",
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
  "link": "http://www.furaffinity.net/journal/6534234/",
  "posted": "February 26th, 2015 07:53 PM"
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
    "posted": "March 2nd, 2015 02:30 AM",
    "text": "Wow, I love the way you do light and shadow."
  },
  {
    "id": "252377",
    "name": "AnnoyingSalamander",
    "posted": "March 1st, 2015 03:16 PM",
    "text": "This drawing sucks."
  },
  {
    "id": "236568",
    "name": "afreshcat001",
    "posted": "February 28th, 2015 06:33 AM",
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
    "posted": "March 2nd, 2015 02:30 AM",
    "text": "Glad to hear your doing better."
  },
  {
    "id": "252377",
    "name": "JusticeBeaver",
    "posted": "March 1st, 2015 03:16 PM",
    "text": "Any idea when you'll be working on my piece again?"
  },
  {
    "id": "236568",
    "name": "wereplatypus2008",
    "posted": "February 28th, 2015 06:33 AM",
    "text": "Everyone check out my art!"
  },
  <snip>
]
~~~

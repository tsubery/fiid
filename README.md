# Fiid

This app purpose is to manage personal media libraries of videos, audio & articles. It basically organizes all the feeds i like to listen/watch into a personal podcast feed and all the articles i'd like to read into [Pocket](https://getpocket.com). Most notable features are:
* Organize pocket reading list.
  *  Syncronize multiple rss feeds into pocket app
  *  Accept emails, render them as web pages and serve it to pocket appit as a webpage, similar functionality to [kill-the-newsletter](https://github.com/leafac/kill-the-newsletter)
  *  Add a particular webpage to pocket app whenever content changes as a workaround for sites that lack of rss
* Organize videos/podcats into a personal podcast
  * Synchronize multiple youtube channels & playlists and present their audio or video content as podcast episodes
  * Present each youtube video added to pocket reading list as a podcast episode

## Main concepts
1. *Media Item* - Can represent a webpage, received email or a youtube video.
2. *Feed* - A source for media items. Can represent an RSS feed, YouTube playlist, Youtube Channel, An Email Inbox or Pocket reading list.
3. *Library* - A destination for media items. A Library can represent a personal podcast that is compatible with PocketCasts. It should be compatible with other podcast apps but I haven't tested it.

Pocket is Special as it's both a Feed (source) for videos to send to podcast and a Libary (destination) for articles.

## Deployment
Pretty standard Ruby on Rails app. Should be straightforward to run it on Heroku or and platform with minor tweaks. The following environment variables are used.
* `PGUSER` - Postgres Database user name
* `PGPASSWORD` - Postgres Database password
* `PGHOST` - Postgres Database Hostname
* `PGPORT` - Posgtres Database Port (defaults to 5432 if missing)
* `SECRET_KEY` - That's a simple token that is used to authenticate a session by admin dashboard. The app is intended to be personal so there's no need for a management system for multiple users.
* `POCKET_CONSUMER_KEY` - If using pocket as a source or destination.
* `POCKET_ACCESS_TOKEN` - If using pocket as a source or destination.
* `RAILS_INBOUND_EMAIL_PASSWORD` - A password that is used by email gateway (Tested with SendGrid).
* `SPAM_EMAIL` - A default email inbox when target mailbox is not found. In case it's not assing to any library emails would be stored but only be visible on admin dashboard. Works great as a replacement for temporary emails services but avoids blacklisted domains.
* `HOSTNAME` - Domain name to be used in link generation

Running `rails db:seed` creates a PocketLibrary, PodcastLibrary, Spam Inbox and Pocket Feed.

## Usage
### Admin endpoints
Accessing `/admin` on the deployed domain redirects to `/login`. Using the `SECRET_KEY` as a password should authenticate the session forever. When authenticated admin presents a dashboard with recent media items and top links to activeadmin database managements. Navigating to `/admin/feeds/new` shows a form where a url for a rss feed, youtube channel or youtube playlist can be added. The association with libraries controls where media items would be routed. For YouTube channels the app expects rss url with the structure `https://www.youtube.com/feeds/videos.xml?channel_id=XXXXX` that can be found by viewing the html source of channels. If url is not recognized as Youtube Playlist/Channel it is defaults to treating it as RSS feed.

### Public endpoints
Articles are accessible using `/media_items/:media_item_id/article`, public access enables pocket parser to get some metadata about the article.
Podcasts are accessible using `/podcasts/:library_id`. This link should be added to a podcast app.

#### Missing features
Right now the system relies on podcasts app periodical requests in order to refresh all feeds, including RSS feeds. In order to use the app without podcast feature, a different scheduling mechanism should be implemented. As a workaround, using load balancer healthcheck could be used to trigger the app to refresh content.

## Important Disclaimer
This app is provided as is under the terms of [MIT License](LICENSE).
[yt-dlp](https://github.com/yt-dlp/yt-dlp/) is bundled in `bin` folder to simplifiy deployments under this [license](https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE).
Please check the terms of service of any 3rd party including Pocket app and Youtube before using this app with their services.

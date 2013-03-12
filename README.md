PunyBlog
========

Ultraminimalist blogging armature (less than a platform, or even a framework)


Installation
------------

My recommendation for now? Don't.

Put it somewhere your webserver can see it.
Do the things you need to do to get a rack app working under your server.
Because this depends on ruby 1.9, be careful if you're using Apache/Passenger.

Run `bundle install`

You'll need to create a database.yml file. It should look like this:

    ---
    :adapter: mysql
    :host: db.example.com
    :database: my_blog
    :user: user
    :password: drowssap

Change the values as appropriate.

Pre-create the database. Don't worry about pre-creating any tables. The app will do that on startup if needed.

Tweak the css as you see fit.

Design
------

Page design is derived from the _"[Striped Html template](http://html5up.net/striped/)"_ by [@n33co](https://twitter.com/n33co) found via [DesignCart](http://www.designcart.org/).

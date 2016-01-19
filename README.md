# Sesame

An automated door unlocker for intercom systems.
Created for, and sponsored by, [Vermonster](http://www.vermonster.com/).

## Requirements

* [Heroku](https://www.heroku.com/home) or other app host
* [Redis](http://redis.io/) instance, e.g. [Heroku Redis][redis]
* [Slack](https://slack.com/) slash command and incoming webhook
* [Twilio](https://www.twilio.com/) phone number
* Building intercom system that operates by dialing a programmed phone number
  and opening the door when the recipient of the call presses 5 on the keypad
* Phone number to receive calls for visitors who don't have an access code

[redis]: https://elements.heroku.com/addons/heroku-redis

## Setup

1. Set up `/sesame` slash command and incoming webhook in Slack
2. Set required environment variables on your app host (see `.env.example`)
3. Set Twilio "Request URL" to point to the root URL of your deployed app
4. Set Twilio "Fallback URL" to `http://twimlets.com/forward?PhoneNumber=xxx`
   (where `xxx` is the same phone number specified as `OFFICE_PHONE_NUMBER`)
5. Deploy to app host, type `/sesame` in Slack, and see if it works

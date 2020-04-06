# -*- coding: utf-8 -*-
"""
Created on Mon Apr  6 14:24:28 2020

@author: DavidYQY
"""

import tweepy

consumer_key = '1k4TYaPXM6W75ijrn1qp2S20X'
consumer_secret = 'Vs2MU5gQdico6AGYs64PdcBOGdASMnIVTRVLzUdgpBY5C7UC69'
access_token = '976100169950232576-L0VWEO57uv1qdIZw3vjWZ0tkBpHH8Qz'
access_token_secret = 'lQsIlbdkQE16URzjdjnTpOpfxwVPxjB3uUoBTbuInvxg5'

auth = tweepy.OAuthHandler(consumer_key, consumer_secret)
auth.set_access_token(access_token, access_token_secret)

api = tweepy.API(auth, wait_on_rate_limit=True, wait_on_rate_limit_notify=True)
tweets = api.statuses_lookup([1233905174730682369])
tweet = tweets[0]
text = tweet.text
lang = tweet.lang
location = tweet.author.location
favorite_cnt = tweet.favorite_count
retweet_cnt = tweet.retweet_count
time = tweet.created_at

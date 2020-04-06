# -*- coding: utf-8 -*-
"""
Created on Mon Apr  6 14:24:28 2020

@author: DavidYQY
"""

from os import listdir
from tqdm import tqdm
import pandas as pd
import numpy as np
import tweepy
import random
random.seed(109)

ratio = 1/1000 # sample 1/1000 samples

# authorize twitter
consumer_key = '1k4TYaPXM6W75ijrn1qp2S20X'
consumer_secret = 'Vs2MU5gQdico6AGYs64PdcBOGdASMnIVTRVLzUdgpBY5C7UC69'
access_token = '976100169950232576-L0VWEO57uv1qdIZw3vjWZ0tkBpHH8Qz'
access_token_secret = 'lQsIlbdkQE16URzjdjnTpOpfxwVPxjB3uUoBTbuInvxg5'
auth = tweepy.OAuthHandler(consumer_key, consumer_secret)
auth.set_access_token(access_token, access_token_secret)
api = tweepy.API(auth, wait_on_rate_limit=True, wait_on_rate_limit_notify=True)

# twitter id files
directory = './COVID-19-TweetIDs'
output_dir = './tweetsInfo'
sub_dirs = ['/2020-01', '/2020-02', '/2020-03']
seen = set()

for sub_dir in sub_dirs:
    files = listdir(directory + sub_dir)
    for file in tqdm(files):
        dat = pd.DataFrame(columns = ['author','text', 'lang', 'place', 'favorite_cnt', 'retweet_cnt'])
        with open(directory + sub_dir + "/" + file, 'r') as f:
            lines = f.readlines()
            lines = [line.strip() for line in lines]
        l = len(lines)
        sampled_lines = random.sample(lines, int(np.ceil(ratio * l)))
        for i in range(0, len(sampled_lines), 100):
            ids = sampled_lines[i:(i+100)]
            tweets = api.statuses_lookup(ids)
            for tweet in tweets:
                if hasattr(tweet, 'retweeted_status'):
                    tweet = tweet.retweeted_status
                if tweet.id not in seen:
                    author = tweet.author.screen_name
                    text = tweet.text
                    lang = tweet.lang
                    place  = None
                    if tweet.place:
                        place = tweet.place.country
                    favorite_cnt = tweet.favorite_count
                    retweet_cnt = tweet.retweet_count
                    dat.loc[str(tweet.id)] = [author, text, lang, place, favorite_cnt, retweet_cnt]
                    seen.add(tweet.id)
        dat = dat.reset_index()
        dat.to_csv(output_dir + sub_dir + "/" + file.replace('txt','csv'), index = False, encoding = 'utf-8-sig')

        


# -*- coding: utf-8 -*-
"""
Created on Mon Apr  6 16:12:23 2020

@author: DavidYQY
"""


# process twitter ids on https://github.com/echen102/COVID-19-TweetIDs
from os import listdir
import pandas as pd

directory = './COVID-19-TweetIDs'
sub_dirs = ['/2020-01', '/2020-02', '/2020-03']
dat = pd.DataFrame(columns = ['month', 'day', 'hour', 'twitter_number'])

for sub_dir in sub_dirs:
    total_lines = []
    files = listdir(directory + sub_dir)
    for file in files:
        segs = file.split('-')
        month = segs[4]
        day = segs[5]
        hour = segs[-1].split('.')[0]
        with open(directory + sub_dir + "/" + file, 'r') as f:
            lines = f.readlines()
            l = len(lines)
        dat.loc[file] = [month, day, hour, l]
    '''
        lines = [line.strip() for line in lines]
        total_lines += lines
        
    with open(sub_dir[1:] + '_total.txt', 'w') as f:
        for item in total_lines:
            f.write("%s\n" % item)
    '''
#dat.to_csv('ts_tweet_num.csv', index = False)
print("totaltweet:{}".format(dat['twitter_number'].sum()))

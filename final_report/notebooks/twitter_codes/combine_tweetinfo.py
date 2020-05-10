# -*- coding: utf-8 -*-
"""
Created on Mon Apr  6 21:54:46 2020

@author: DavidYQY
"""


# combine tweetInfo/ -> tweetInfo.csv
from os import listdir
import pandas as pd

directory = './tweetsInfo'
sub_dirs = ['/2020-01', '/2020-02', '/2020-03']
output_file = 'tweetInfo.csv'
dat = pd.DataFrame(columns = ['month', 'day', 'hour'] + ['author','text', 'lang', 'place', 'favorite_cnt', 'retweet_cnt'])

for sub_dir in sub_dirs:
    total_lines = []
    files = listdir(directory + sub_dir)
    for file in files:
        segs = file.split('-')
        month = segs[4]
        day = segs[5]
        hour = segs[-1].split('.')[0]
        hourly_dat = pd.read_csv(directory + sub_dir + "/" + file, index_col = 0, encoding = 'utf-8-sig')
        hourly_dat['month'] = month
        hourly_dat['day'] = day
        hourly_dat['hour'] = hour
        dat = dat.append(hourly_dat, sort = False)

print("Total Lines: {}".format(dat.shape[0]))
dat = dat.reset_index()
dat.to_csv(output_file, index = False, encoding = 'utf-8-sig')

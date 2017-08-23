#!/usr/bin/env python

#this script calcualtes number of fibers that each tracking app should create.
# ./calculatetracks.py $MAXLMAX

import json
import sys

maxlmax = int(sys.argv[1])
tracks_per_algorithm=len(range(2, maxlmax+2, 2))

with open('config.json') as config_json:
    config = json.load(config_json)
    tracks = 0
    if config['do_tensor']: tracks+=1 
    if config['do_probabilistic']: tracks+=tracks_per_algorithm 
    if config['do_deterministic']: tracks+=tracks_per_algorithm 
    
    totaltracks=config['fibers']
    numfibers = int(totaltracks/tracks)
    print numfibers

#!/usr/local/env python3

import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from scipy import stats
import sys
import os
from glob import glob


sns.set(color_codes=True, rc={'xtick.labelsize': 6})


input_folder = sys.argv[1]
output_folder = sys.argv[2]

# check if input_folder is a folder
if not os.path.isdir(input_folder):
    raise Exception('Please select an input folder as first argument')
if not os.path.isdir(output_folder):
    raise Exception('Please select an output folder as second argument')

# Get all files in folder
file_list = glob(input_folder + '/*.tsv')

# Parse files into pandas dataframe
for i, f in enumerate(file_list):
    sample = os.path.basename(f).split('.')[0]
    df = pd.read_csv(f, sep='\t', header=9, usecols=[0,1])
    df['reads'].hist(bins=10)
    # fig = sns.distplot(df.iloc[:,1])
    fig = sns.barplot(x=df['#Length'], y=df['reads'])
    plt.xticks(rotation=90)
    plt.tight_layout()
    fig.figure.savefig(output_folder + '/' + sample + 'length_dist.png')

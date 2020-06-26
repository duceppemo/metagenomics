# metagenomics

## Installation
* Install conda (https://docs.conda.io/en/latest/miniconda.html). Choose appropiate version.
* Set conda channels:
```
conda config --add channels r
conda config --add channels bioconda
conda config --add channels defaults
conda config --add channels conda-forge
```
* Create conda environment for qiime1 and test it (http://qiime.org/install/install.html):
```
conda create -n qiime1 python=2.7 qiime matplotlib=1.4.3 mock nose -c bioconda
conda activate qiime1
print_qiime_config.py -t
conda deactivate
```
* Create conda environment for qiime2 and test it (https://docs.qiime2.org/2020.2/install/native/#install-qiime-2-within-a-conda-environment):
```
wget https://data.qiime2.org/distro/core/qiime2-2020.2-py36-linux-conda.yml
conda env create -n qiime2-2020.2 --file qiime2-2020.2-py36-linux-conda.yml
# OPTIONAL CLEANUP
rm qiime2-2020.2-py36-linux-conda.yml
source activate qiime2-2020.2
qiime --help
conda deactivate
```
* Create main conda environment to run the other tools:
```
conda create -n meta python=3.6 bbmap parallel itsxpress blast biom-format

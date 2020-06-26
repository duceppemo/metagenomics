#!/bin/bash

# qsub specific commands
#"smp" all cpu on same node vs "orte" anywhere

#$ -N metageno
#$ -S /bin/bash
#$ -cwd
#$ -pe smp 12
#$ -j y


#File naming
# JB14S01-ITS1F_BC01-Run7.fastq
# 3 fields separated by "-"
# Field 1: "JB14S01"
  # JB -> user
  # 14 -> year
  # S01 -> sample number
# Field 2:
  # ITS1F -> region amplified
  # BC01 -> barcode number
# Field 3: "Run7"
  # Run7 -> run number


#######################
#                     #
#    User Defined     #
#                     #
#######################


#Base directory for your current analysis
#all output files will be inside
export baseDir='/media/2TB_NVMe/pirl_2020-02-20_COI_F_Set1_2017'

#original fastq files
fastq=/media/30tb_raid10/data/PIRL/2020-02-20_COI_F_Set1_2017

# Maximum CPUs to use
cpu="48" #must match the "-pe smp" value at the begining of the script

#Where all scripts are
export scripts=""${HOME}"/scripts/metagenomics"

#barcode information for all samples
barcode=""${HOME}"/barcodes/barcodes.txt"

#QIIME qiime_metadata custom fields
#add the column header to the variable. Use as many as needed.
customFields=("TrapType" "Lure" "CollectionDate" "Province" "City")

#Which region to analyze
region=COI
# region="ITS2"
# region="ITS1F"

#UNITE database
unite="/media/30tb_raid10/db/UNITE"


#######################
#                     #
#   Data Stucture     #
#                     #
#######################


#log
log=""${baseDir}"/log.txt"

#folder for renamed fastq files (symbolic links)
renamedFastq="${baseDir}"/fastq
modifiedFastq="${baseDir}"/fastqHeader
export trimmed="${baseDir}"/trimmed
export extracted="${baseDir}"/extracted
qiime="${baseDir}"/qiime
qiime_metadata="${qiime}"/metadata
qiime_fasta="${qiime}"/combinedFasta
qiime_otu="${qiime}"/otu

#if forlder does not exists, create it
# -p -> create parent directories if they don't exist
# "||" if test is false
# "&&" if test is true
[ -d "$baseDir" ] || mkdir -p "$baseDir"
[ -d "$renamedFastq" ] || mkdir -p "$renamedFastq"
[ -d "$modifiedFastq" ] || mkdir -p "$modifiedFastq"
[ -d "$trimmed" ] || mkdir -p "$trimmed"
[ -d "$extracted" ] || mkdir -p "$extracted"
[ -d "$qiime" ] || mkdir -p "$qiime"
[ -d "$qiime_metadata" ] || mkdir -p "$qiime_metadata"
[ -d "$qiime_fasta" ] || mkdir -p "$qiime_fasta"
[ -d "$qiime_otu" ] || mkdir -p "$qiime_otu"


##############
#            #
#    Log     #
#            #
##############


#change the names
echo "Date: "$(date)"" | tee "$log" #create log file. Crush old one if exists
echo "" >> "$log"
echo "User: "$(whoami)"" | tee -a "$log"
echo "" >> "$log"
echo "This analysis is going to use the following programs:" | tee -a "$log" 



# Version control
# Mothur
v=$(mothur --version | grep version | cut -d "=" -f 2)
echo "Mothur v"${v}"" | tee -a "$log"

# QIIME
source activate qiime1
v=$(print_qiime_config.py -t | grep 'QIIME script version' | cut -d $'\t' -f 2)
echo "QIIME v"${v}"" | tee -a "$log"
source deactivate

# ITSx
v=$(ITSx --version 2>&1 | grep Version | cut -d " " -f 2)
echo "ITSx v"${v}"" | tee -a "$log"

# ITSxpress
# source activate qiime2-2019.10

# Biom
v=$(biom --version | cut -d " " -f 3)
echo "biom v"${v}"" | tee -a "$log"

# Python
v=$(python3 --version | cut -d " " -f 2)
echo "python v"${v}"" | tee -a "$log"


#############################
#                           #
#  Rename headers in fastq  #
#                           #
#############################


#Change fastq entry headers to include the file name
# e.g. file name: abc.fastq;
# @P03UN:100856:63398 -> @abc_P03UN:100856:63398


#Find all fastq files rercursively in a specfic location and create symbolic in analysis folder
find "$fastq" -type f -name "*.fastq*" -name "*"${region}"*" -exec ln -s {} "$renamedFastq" \;

function rename_headers()
{
  python3 "${scripts}"/add_filename_to_fastq_headers.py "$1"
}

export -f rename_headers

# Add file name in header
find -L "$renamedFastq" -type f -name "*.fastq*" -name "*"${region}"*" \
| parallel --bar --jobs "$cpu" --env scripts --env rename_headers 'rename_headers {}'

# Replace files
mv "${renamedFastq}"/*.renamed "$modifiedFastq"
for i in $(find "$modifiedFastq" -type f -name "*.renamed"); do
  mv "$i" "${i%.renamed}"
done

# Cleanup
rm -rf "$renamedFastq"


##############
#            #
# Trimming   #
#            #
##############


# Create folder to store data
[ -d "${trimmed}"/length_distribution/raw ] || mkdir -p "${trimmed}"/length_distribution/raw

# Check reads size distribution
function check_length()
{
    sample=$(basename "$1" '.fastq.gz')

    readlength.sh -Xmx440g \
    bin=10 \
    max=600 \
    in="$1" \
    out="${trimmed}"/length_distribution/"${sample}".tsv
}

export -f check_length

find "${modifiedFastq}" -type f -name "*.fastq.gz" -name "*"${region}"*" \
| parallel  --bar \
            --env check_length \
            --env trimmed \
            --jobs "$cpu" \
            'check_length {}'

python3 "${scripts}"/read_length_distribution.py \
    "${trimmed}"/length_distribution/raw \
    "${trimmed}"/length_distribution/raw

# Cleanup
find "${trimmed}"/length_distribution -name "*.tsv" -exec rm {} \;

# Remove reads too short or too long
# Inspect visually the graph to know min and max sizes to keep
# COI -> 430-480
function size_select()
{
    sample=$(basename "$1" '.fastq.gz')

    bbduk.sh -Xmx440g \
        in="$1" \
        out="${trimmed}"/"${sample}".fastq.gz \
        qtrim=lr trimq=10 \
        minlen=430 \
        maxlen=480 \
        threads=4 
}

export -f size_select

find "${modifiedFastq}" -type f -name "*.fastq.gz" -name "*"${region}"*" \
| parallel  --bar \
            --env size_select \
            --env trimmed \
            --jobs $(("$cpu"/4)) \
            'size_select {}'

# Create folder to store data
[ -d "${trimmed}"/length_distribution/trimmed ] || mkdir -p "${trimmed}"/length_distribution/trimmed
find "${trimmed}" -type f -name "*.fastq.gz" -name "*"${region}"*" \
| parallel  --bar \
            --env check_length \
            --env trimmed \
            --jobs "$cpu" \
            'check_length {}'

python3 "${scripts}"/read_length_distribution.py \
    "${trimmed}"/length_distribution \
    "${trimmed}"/length_distribution/trimmed

# Cleanup
find "${trimmed}"/length_distribution -name "*.tsv" -exec rm {} \;


#######################
#                     #
#        QIIME        #
#                     #
#######################


function find_ITS()
{
# Retrive ITS1 part of the amplicons
# https://github.com/USDA-ARS-GBRU/q2_itsxpress
    sample=$(basename "$1" '.fastq.gz')

    itsxpress \
        --fastq "$1" \
        --single_end \
        --outfile "${trimmed}"/fastq/"${sample}".fastq.gz \
        --region ITS1 \
        --taxa Fungi \
        --cluster_id 0.995 \
        --log "${trimmed}"/fastq/itsxpress/"${sample}".log \
        --threads 48
}

export -f find_ITS

[ -d "${trimmed}"/fastq/itsxpress ] || mkdir -p "${trimmed}"/fastq/itsxpress

source activate qiime2-2019.10

find "${modifiedFastq}" -type f -name "*.fastq.gz" -name "*"${region}"*" \
| parallel  --bar \
            --env find_ITS1 \
            --env trimmed \
            --jobs 4 \
            'find_ITS {}'

source deactivate

# Convert fastq to fasta
function fastq2fasta()
{
  sample=$(basename "$1" ".fastq.gz")
  zcat "$1" | sed -n '1~4s/^@/>/p;2~4p' > "${trimmed}"/fasta/"${sample}".fasta
}

export -f fastq2fasta

[ -d "${trimmed}"/fasta ] || mkdir -p "${trimmed}"/fasta

find "${trimmed}"/fastq -type f -name "*.fastq*" -name "*"${region}"*" \
| parallel --bar --jobs "$cpu" --env fastq2fasta 'fastq2fasta {}'

# Remove second part of fasta headers
find "${trimmed}"/fasta -type f -name "*.fasta" -name "*"${region}"*" \
| parallel --bar sed -i 's/%[^:]*//' {}

# Remove empty sequences
find "${trimmed}"/fasta -type f -name "*.fasta" -name "*"${region}"*" \
| parallel --bar python3 "${scripts}"/remove_empty_fasta_entries.py {}
rm "${trimmed}"/fasta/*.fasta
rename 's/\.clean//' "${trimmed}"/fasta/*.clean


#############
#           #
#   QIIME   #
#           #
#############


#"activate" qiime 
source activate qiime1

#check qiime_metadata file
validate_mapping_file.py \
  -m "${qiime_metadata}/metadata.tsv" \
  -o "${qiime_metadata}" \
  -B \
  -j Description \
  -s \
  --verbose

#Add qiime labels to fasta files
add_qiime_labels.py \
  -m "${qiime_metadata}"/metadata.tsv \
  -i "${trimmed}"/fasta \
  -c "InputFileName" \
  -o "$qiime_fasta" \
  --verbose

#pick qiime_otus
pick_open_reference_otus.py \
  -m uclust \
  --parallel \
  --min_otu_size=1 \
  --suppress_taxonomy_assignment \
  --suppress_align_and_tree \
  -i "${qiime_fasta}"/combined_seqs.fna \
  -r "${unite}"/sh_refs_qiime_ver8_99_02.02.2019.fasta \
  -o "$qiime_otu" \
  --force \
  --verbose

#Pick representative set of qiime_otus
pick_rep_set.py \
  -i "${qiime_otu}"/final_otu_map.txt \
  -f "${qiime_fasta}"/combined_seqs.fna \
  -o "$qiime_otu"/"${region}"_rep_set.fasta \
  --verbose

#Assign taxonomy with taxa file
export BLASTMAT=/home/bioinfo/prog/blast/data
assign_taxonomy.py \
  -i "$qiime_otu"/"${region}"_rep_set.fasta \
  -t "${unite}"/sh_taxonomy_qiime_ver8_99_02.02.2019.txt \
  -r "${unite}"/sh_refs_qiime_ver8_99_02.02.2019.fasta \
  -o "$qiime_otu"/"${region}"_blast_assigned_taxonomy \
  -m blast \
  --verbose

#fix non ascii characters from UNITE database
python "${scripts}"/parse_nonstandard_chars.py \
 "$qiime_otu"/"${region}"_blast_assigned_taxonomy/"${region}"_rep_set_tax_assignments.txt \
 > "$qiime_otu"/"${region}"_blast_assigned_taxonomy/"${region}"_rep_set_tax_assignments-clean.txt

#Make qiime_otu table
make_qiime_otu_table.py \
  -i "${qiime_otu}"/final_otu_map.txt \
  -o "$qiime_otu"/"${region}"_otu_table_taxo.biom \
  -t "$qiime_otu"/"${region}"_blast_assigned_taxonomy/"${region}"_rep_set_tax_assignments-clean.txt \
  --verbose

#Convert biom file for RAM package in R
biom convert \
  -i "$qiime_otu"/"${region}"_otu_table_taxo.biom \
  -o "$qiime_otu"/"${region}"_otu_table_taxo.tsv \
  --to-tsv \
  --header-key "taxonomy"

summarize_taxa_through_plots.py \
    -i "$qiime_otu"/"${region}"_otu_table_taxo.biom \
    -o "$qiime_otu"/"${region}"_taxa_summary \
    -m "${qiime_metadata}"/metadata.tsv

make_qiime_otu_heatmap.py \
    -i "$qiime_otu"/"${region}"_otu_table_taxo.biom \
    -o taxa_summary/otu_table_L3_heatmap.pdf -c Treatment -m Fasting_Map.txt

source deactivate


###########
#         #
#   RDP   #
#         #
###########


# Classify reads using Terri's trained database
java -Xmx440g -jar /home/bioinfo/prog/rdp_classifier_2.12/dist/rdp_classifier_2.12.jar \
    classify \
    -t /media/30tb_raid10/db/RDP/COI/mydata_trained/rRNAClassifier.properties \
    -o /media/2TB_NVMe/pirl_2020-02-20_COI_F_Set1_2017/rdp/rdp_calssified.tsv \
    "$qiime_otu"/"${region}"_rep_set.fasta


# Run in parallel on single record
cat "$qiime_otu"/"${region}"_rep_set.fasta | \
parallel --recstart '>' -N 1 --pipe java -Xmx440g \
    -jar /home/bioinfo/prog/rdp_classifier_2.12/dist/rdp_classifier_2.12.jar \
    classify \
    -t /media/30tb_raid10/db/RDP/COI/mydata_trained/rRNAClassifier.properties \
    -o /media/2TB_NVMe/pirl_2020-02-20_COI_F_Set1_2017/rdp/rdp_calssified_{#}.tsv \
    /dev/stdin

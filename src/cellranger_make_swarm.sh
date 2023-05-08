#!/usr/bin/env bash


# Argument parsing
usage_error () { echo >&2 "$(basename $0):  $1"; exit 2; }
assert_argument () { test "$1" != "$EOL" || usage_error "$2 requires an argument"; }
if [ "$#" != 0 ]; then
    EOL=$(printf '\1\3\3\7')
    set -- "$@" "$EOL"
    while [ "$1" != "$EOL" ]; do
        opt="$1"; shift
        case "$opt" in

            # Your options go here.
            --gtf) assert_argument "$1" "$opt"; GTF="$1"; shift;;
            --dir) assert_argument "$1" "$opt"; DIR="$1"; shift;;
      
            # Arguments processing. You may remove any unneeded line after the 1st.
            -|''|[!-]*) set -- "$@" "$opt";;                                          # positional argument, rotate to the end
            --*=*)      set -- "${opt%%=*}" "${opt#*=}" "$@";;                        # convert '--name=arg' to '--name' 'arg'
            -[!-]?*)    set -- $(echo "${opt#-}" | sed 's/\(.\)/ -\1/g') "$@";;       # convert '-abc' to '-a' '-b' '-c'
            --)         while [ "$1" != "$EOL" ]; do set -- "$@" "$1"; shift; done;;  # process remaining arguments as positional
            -*)         usage_error "unknown option: '$opt'";;                        # catch misspelled options
            *)          usage_error "this should NEVER happen ($opt)";;               # sanity test for previous patterns
    
        esac
    done
    shift  # $EOL
fi


cellranger mkref --genome=output_genome --fasta=input.fa --genes=input.gtf




# One input with ID, dir, --sample prefix
# Cellranger count on individual samples
# Cellranger aggr across samples

# This script only works if the sample names are the last part in the directory.
# Before execution, move to the same directory as desired for the output directories.
# E.g. my/directory/to/something/samplename.csv
#
# 1st argument = file with list of ids, DO NOT include tags like -RNA or _scrn. Those are added automatically
# 2nd argument = fastq directory
# 3rd argument = overall batch name. Give a name to this entire batch. The swarm file will be called
#                your_batch_name_RNA.swarm

SWARM_FILE=$3_RNA.swarm

cellranger count \
  --chemistry ARC-v1 \
  --id $p-RNA \
  --transcriptome '/fdb/cellranger/refdata-gex-GRCh38-2020-A' \
  --fastqs $2/"$p"_scrn/ \
  --localcores 12 \
  --localmem 64"


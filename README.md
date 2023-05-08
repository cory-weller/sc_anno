# README

## Requirements
1. `Singularity` version 3.0+ (`Docker` support NYI)
1. `cellranger`

Everything that needs to run in `R` should function inside of a prebuilt `singularity` container.

To check for (and if necessary, download) the container:
```bash
bash src/check_sif.sh
```

## Installing `Singularity`

See [here](https://gist.github.com/cory-weller/ae515627436596f7e82d96864df134aa)

## Prepare cellranger
If `cellranger` is not already available on your system, it can be downloaded
from the 10xgenomics website, after agreeing to its license.

Visit [HERE](https://support.10xgenomics.com/single-cell-gene-expression/software/downloads/latest)

Fill out your institution information, then follow the instructions to
retrieve one of the zipped archive files using either `curl` or `wget`.
Then extract the file using the correct `tar` command.

```bash
tar -zxvf cellranger-6.1.2.tar.gz   # z for gzipped files
tar -Jxvf cellranger-6.1.2.tar.xz   # J for xzipped files

export PATH=$(realpath cellranger-7.1.0):$PATH  
# Yes, as of May 2023 the extracted directory version 
# doesn't match the name of the tar file
```

## Prepare reference data

The reference data used by `cellranger` will, at minimum, contain:
```
── output_genome
    ├── fasta
    │   ├── genome.fa
    │   └── genome.fa.fai
    ├── genes
    │   └── genes.gtf.gz
    ├── reference.json
    └── star
        ├── chrLength.txt
        ├── chrNameLength.txt
        ├── chrName.txt
        ├── chrStart.txt
        ├── exonGeTrInfo.tab
        ├── exonInfo.tab
        ├── geneInfo.tab
        ├── Genome
        ├── genomeParameters.txt
        ├── SA
        ├── SAindex
        ├── sjdbInfo.txt
        ├── sjdbList.fromGTF.out.tab
        ├── sjdbList.out.tab
        └── transcriptInfo.tab
```

A prebuilt reference for GRCh38 (11GB) can be directly downloaded:
```bash
wget https://cf.10xgenomics.com/supp/cell-exp/refdata-gex-GRCh38-2020-A.tar.gz
# md5sum = dfd654de39bff23917471e7fcc7a00cd
```
Alternatively, it can be built after downloading source data. About
15 GB of space is required for the build process.
```bash
bash  src/build_GRCh38_ref.sh
```

The extracted top directory (e.g. `/path/to/refdata-gex-GRCh38-2020-A`
is what will be pointed to with the `--transcriptome` argument when
running `cellranger count`.



## Running a single sample

## Running batches of experiments




Create an environment with at least what is in the requirements.txt file.


TODO: 1. Make automatic QC
    2. Add in results for ATAC
    3. Make separate names for ATAC genes in the file


Run Rscript annotate.R /path/to/folder/with/outs sample_name


Also included here are some example scripts for using cell_ranger on Biowulf


## Notes

<details><summary> Preparing ref data </summary>

```bash
# GRCh38 ref genome. All headings labeled as
# >chr$ID $ID
# with arabic (not roman) numerals
ref_fasta='/fdb/cellranger/refdata-gex-GRCh38-2020-A/fasta/genome.fa'
gzip -c ${ref_fasta} > GRCh38.genome.fa.gz

# GRCh38 version 32 (Ensembl 98) GTF
genes='/fdb/cellranger/refdata-gex-GRCh38-2020-A/genes/genes.gtf'
gzip -c ${genes} > genes.gtf.gz
```

</details>


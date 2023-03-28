# BUSZ: Compressed BUS files

This repository contains the following files that were used to create and process the results of the paper "BUSZ: Compressed BUS files"

- Snakemake file to run the benchmark for all the compression and decompression methods tested
- The resulting output of the benchmarks
- An R markdown file used to analyze the data and create all plots


## Running the Snakemake workflow

### Software

We used the following software

* `bustools` version 0.40.0
* `gzip` version 1.6
* `zstd` version 1.5.2
* GNU `time` version 1.7
* `dd` coreutil version 8.28
* Snakemake version 7.14.2
* Python version 3.6.9

If you intend to use other tools, you may need to tweak their usage in the Snakefile. Furthermore, we expect that the output of the `time` command is a single number (with or without a decimal point).

### Setting up the experiment

The Snakefile expects that the BUS files are called `corrected_sorted.bus` in a directory hierarchy of `toplevel_dir / tissue / sample_id / corrected_sorted.bus`. If the toplevel directory of the experiment is called `experiments`, a sample directory structure looks like the following:

```
experiments
├── adipose
│   ├── GSM3711757
│   │   ├── ...
│   │   └── corrected_sorted.bus
│   ├── GSM3711758
│   │   ├── ...
│   │   └── corrected_sorted.bus
│   ...
├── blood
│   ├── CRX102285
│   │   ├── ...
│   │   └── corrected_sorted.bus
│   ├── CRX102286
│   │   ├── ...
│   │   └── corrected_sorted.bus
│   ... 
...
```

The configuration file, `config.yaml` must be updated with at least the paths used, i.e. the path of the `bustools` executable and the path to the experiments directory. These are under `paths['bustools']` and `paths['data_dir']` entries, respectively.

We ran the workflow using the following command:

```snakemake -c1 -j1 -q```

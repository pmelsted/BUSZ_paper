import pathlib


outdir = pathlib.Path(snakemake.config['paths'].get('out_dir', "snakemake_output"))
results_file = pathlib.Path(snakemake.config['paths'].get('results', 'benchmark_results.csv'))
results_file = outdir / results_file.with_suffix('.csv')

filenames = list(map(pathlib.Path, snakemake.input))


get_tissue = lambda fn: fn.parent.parent.name
get_sample_id = lambda fn: fn.parent.name
get_res_type = lambda fn: ''.join(fn.stem.split('_')[1:])

results_file.parent.mkdir(exist_ok=True)

with results_file.open('wt') as f:
    col_names = ['full_size', 'compressed', 'compression_t', 'decompression_t', 'res_type', 'sample_id', 'tissue']
    f.write(','.join(col_names) + '\n')
    for filename in filenames:
        file_identifier = [
            get_res_type(filename),
            get_sample_id(filename),
            get_tissue(filename),
        ] 
        res = list(map(str.strip, filename.open('rt').readlines()))
        if res[0] != 'identical':
            print(f'file {filename} failed')

        parts = res[1:] + file_identifier

        f.write(','.join(parts) + '\n')

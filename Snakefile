
configfile: "config.yaml"
import pathlib

bustools_cmd = config['paths']['bustools']
data_dir=config['paths']['data_dir']
out_dir=config['paths']['out_dir']

base_filename = 'corrected_sorted.bus'

sort_by_size_descending = lambda p: -p.lstat().st_size
all_bus_files = pathlib.Path(data_dir).glob(f"*/*/{base_filename}")
all_bus_files = sorted(all_bus_files, key=sort_by_size_descending)

def parse_tuple_int_None(limit, nsmallest=None):
	nlargest = limit
	if type(limit) is str:
		s = limit.strip(', ').split(',')
		if len(s) > 1:
			nsmallest, nlargest = tuple(map(int, map(str.strip, s)))[:2]
		else:
			s = s[0]
			nlargest = int(s) if s else 1

	return (nsmallest or None, nlargest or None)


def get_results_names(res_type, nlargest=None, nsmallest=None):
	name = f'results_{res_type}.txt'
	res = [
		pathlib.Path(out_dir) / fn.relative_to(data_dir).with_name(name)
		for fn in all_bus_files
	]

	if nlargest == nsmallest == 0:
		return []
	if nlargest is None and nsmallest is None:
		return res
	if nlargest is None:
		return res[-nsmallest:]
	if nsmallest is None:
		return res[:nlargest]
	return res[:nlargest] + res[-nsmallest:]


def define_outputs(key, nsmallest=None, max_largest=None, max_smallest=None):
	config['test_size'].setdefault(key, None)
	if key not in config['test_size']:
		print(key, 'not defined in config.yaml')
		return []
	_nsmallest, _nlargest = parse_tuple_int_None(config['test_size'][key], nsmallest=nsmallest)
	if max_largest is not None:
		_nlargest = min(_nlargest or 0, max_largest)
	if max_smallest is not None:
		_nsmallest = min(_nsmallest or 0, max_smallest)

	filenames = get_results_names(key, nlargest=_nlargest, nsmallest=_nsmallest)
	return filenames

def get_all_output_files(config):
	results_files = []
	limits = config["limits"]
	for key in config["methods"]:
		limits.setdefault(key, None)
		max_smallest, max_largest = parse_tuple_int_None(limits[key])
		outputs = define_outputs(key, max_largest=max_largest, max_smallest=max_smallest)
		results_files.extend(outputs)
	return results_files

def split_to_levels(s: str):
	is_digit = list(map(str.isdigit, s))
	if any(is_digit):
		i = is_digit.index(True)
		s = s[:i] + "_" + s[i:]
	return s

def get_listed_output_files(config):
	file_list = config.get("file_list", None)
	if file_list is None:
		return None
	if file_list["use"] is True:
		filename = file_list['name']

		out_files = []
		runall = file_list.get("runall", False)
		with pathlib.Path(filename).open('rt') as f:
			header = f.readline().strip().split(',')
			method_pos = header.index("res_type")
			tissue_pos = header.index("tissue")
			sample_pos = header.index("sample_id")
			rerun_pos = header.index("rerun")

			for row in f.readlines():
				fields = row.strip().split(',')
				method = fields[method_pos]
				tissue = fields[tissue_pos]
				sample = fields[sample_pos]
				rerun = fields[rerun_pos]

				if not runall and rerun.title() != 'True':
					continue

				method = split_to_levels(method)
				out_file = pathlib.Path(out_dir) / tissue / sample/f"results_{method}.txt"
				out_files.append(out_file)
		return out_files
	else:
		return None


all_results_files = get_listed_output_files(config)
if all_results_files is None:
	all_results_files = get_all_output_files(config)

print('Total number of files:', len(all_results_files))


# BUStools params
pfd_param = config.get('params', {}).get('pfd', '')
pfd_size = f'-P{pfd_param}' if pfd_param else ''
chunk_param = config.get("params", {}).get("N", "")
chunk_size = f"-N{chunk_param}" if chunk_param else ""

# define outputs and inputs dirs
target_dir = f'{out_dir}/{{tissue}}/{{sample_id}}'
source_dir = f'{data_dir}/{{tissue}}/{{sample_id}}'

# bustools files
og_file = f'{source_dir}/{base_filename}'
busz_file = f"{target_dir}/compressed.busz"
inflated_busfile = f"{target_dir}/inflated.bus"
bus_comptime = f"{target_dir}/compress_time.txt"
bus_infltime = f"{target_dir}/inflate_time.txt"
bus_resfile = f"{target_dir}/results_bus.txt"

# gz files
gz_file = f"{target_dir}/output_gzip_{{level}}.bus.gz"
inflated_gzfile = f"{target_dir}/output_gzip_{{level}}.bus"
gz_comptime = f"{target_dir}/compress_time_gzip_{{level}}.txt"
gz_infltime = f"{target_dir}/inflate_time_gzip_{{level}}.txt"
gz_resfile = f"{target_dir}/results_gzip_{{level}}.txt"

# zst files
zst_file = f"{target_dir}/output_zst_{{level}}.bus.zst"
inflated_zstdfile = f"{target_dir}/output_zst_{{level}}.bus"
zst_comptime = f"{target_dir}/compress_time_zst_{{level}}.txt"
zst_infltime = f"{target_dir}/inflate_time_zst_{{level}}.txt"
zst_resfile = f"{target_dir}/results_zst_{{level}}.txt"

# commands
cache_command = "dd if={input} of=/dev/null bs=1M"
time_command = "/usr/bin/time -a -f\"%e\" -o {output.time} "

rule all:
	input: all_results_files
	script: 'aggregate_results.py'

rule compile_zst_result:
	input:
		bus = og_file,
		compressed = zst_file,
		time_comp = zst_comptime,
		time_infl = zst_infltime
	output: zst_resfile
	shell: "echo identical > {output} && " \
		"wc -c {input.bus} | cut -f1 -d' ' >> {output} && " \
		"wc -c {input.compressed} | cut -f1 -d' ' >> {output} && " \
		"cat {input.time_comp} >> {output} && " \
		"cat {input.time_infl} >> {output}"

rule compile_gzip_result:
	input:
		bus = og_file,
		compressed = gz_file,
		time_comp = gz_comptime,
		time_infl = gz_infltime
	output: gz_resfile
	shell: "echo identical > {output} && " \
		"wc -c {input.bus} | cut -f1 -d' ' >> {output} && " \
		"wc -c {input.compressed} | cut -f1 -d' ' >> {output} && " \
		"cat {input.time_comp} >> {output} && " \
		"cat {input.time_infl} >> {output}"


rule compile_bus_result:
	input: 
		bus=og_file,
		orig=f"{target_dir}/orig.md5",
		restored=f"{target_dir}/restored.md5",
		compressed=busz_file,
		time_comp=bus_comptime,
		inflated=inflated_busfile,
		time_infl=bus_infltime

	output: bus_resfile

	shell: "diff -qs {input.orig} {input.restored} | rev | cut -f1 -d' ' | rev > {output} && " \
		"wc -c {input.bus} | cut -f1 -d' ' >> {output} && " \
		"wc -c {input.compressed} | cut -f1 -d' ' >> {output} && " \
		"cat {input.time_comp} >> {output} && " \
		"cat {input.time_infl} >> {output}"


rule make_md5_orig:
	input: og_file
	output: f"{target_dir}/orig.md5"
	shell: "md5sum {input} | cut -f1 -d' '> {output}"

rule make_md5_restored:
	input: inflated_busfile
	output: temp(f"{target_dir}/restored.md5")
	shell: "md5sum {input} | cut -f1 -d' '> {output}"

rule compress_bus:
	input: og_file
	output: busz=temp(busz_file),
		time=temp(bus_comptime)
	params:
		pfd = pfd_size,
		chunk_size=chunk_size
	shell: f'{cache_command} && ' \
		f'{time_command} {bustools_cmd} compress -o {{output.busz}} {{params.pfd}} {{params.chunk_size}} {{input}}'

rule compress_zstd:
	input: og_file
	output: zst=temp(zst_file),
		time=temp(zst_comptime)
	shell: f'{cache_command} && ' \
		f'{time_command} zstd -q -{{wildcards.level}} -o {{output.zst}} {{input}}'

rule compress_gzip:
	input: og_file
	output: gz=temp(gz_file),
		time=temp(gz_comptime)
	shell: f'{cache_command} && ' \
		f"{time_command} gzip -{{wildcards.level}} --keep -c {{input}} > {{output.gz}}"

rule inflate_bus:
	input: busz_file
	output: bus=temp(inflated_busfile),
		time=temp(bus_infltime)
	shell: f'{cache_command} && ' \
		f'{time_command} {bustools_cmd} inflate -o {{output.bus}} {{input}}'

rule inflate_zstd:
	input: zst_file
	output: bus=temp(inflated_zstdfile),
		time=temp(zst_infltime)
	shell: f'{cache_command} && ' \
		f'{time_command} zstd -d -q -o {{output.bus}} {{input}}'

rule inflate_gzip:
	input: gz_file
	output: bus=temp(inflated_gzfile),
		time=temp(gz_infltime)
	shell: f'{cache_command} && ' \
		f'{time_command} gzip --keep -d {{input}}'

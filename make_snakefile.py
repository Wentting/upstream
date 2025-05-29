import os
import argparse
from pathlib import Path
import yaml
import re
import shutil

def load_yaml(yaml_path):
    """读取 YAML 文件并返回数据"""
    with open(yaml_path, 'r') as file:
        return yaml.safe_load(file)

def batch_samples(samples, batch_size=None, regex=None):
        if batch_size:
            for i in range(0, len(samples), batch_size):
                yield samples[i:i + batch_size]
        elif regex:
            pattern = re.compile(regex)
            batches = {}
            for sample in samples:
                match = pattern.match(sample)
                if match:
                    key = match.group(0)
                    if key not in batches:
                        batches[key] = []
                    batches[key].append(sample)
            for batch in batches.values():
                yield batch
        else:
            yield samples
            
def copy_and_modify_snakefile(snake_template, out, bath_id, batch, input_dir, output_dir, yaml_file, suffix):
    """copy and modify snakefile

    Args:
        snake_template (_type_): snakefile template path
        out (_type_): outpath for snakefile
        bath_id (_type_): batch id
        batch (_type_): batch samples
        input_dir (_type_): inputdir of raw files in yaml file
        output_dir (_type_): outputdir of results in yaml file
        yaml_file (_type_): yaml file path
        suffix (_type_): suffix of the methylation files to be batched
    """
    print(f"Batch_id: {bath_id}")
    if bath_id == 1:
        filename = "Snakefile"
    else:
        filename = f"Snakefile_b{bath_id}"
    try:
        batch_snakefile = os.path.join(out,filename)
        shutil.copy(snake_template, batch_snakefile)
        with open(batch_snakefile, 'r') as file:
            content = file.read()
            content = content.replace('configfile: "./config.yaml"', f'configfile: "{yaml_file}"')
            content = content.replace('inputdir = config["inputfile"]["inputdir"]', f'inputdir = "{input_dir}"')
            content = content.replace('output_dir = config["outputdir"]', f'output_dir = "{output_dir}"') #TO DO: check if this is correct
            samples = ', '.join([f'"{sample}"' for sample in batch])
            content = content.replace(f'SAMPLES = glob_wildcards(f"{{inputdir}}/{{{{sample}}}}{suffix}").sample', f'SAMPLES = {batch}')
        with open(batch_snakefile, 'w') as file:
                file.write(content)
        print(f"Snakefile for batch {bath_id} created at {batch_snakefile}")
    except Exception as e:
        print(f"Error creating Snakefile for batch {bath_id}: {e}")
  
def get_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Batch file processing for Snakefile generation")
    parser.add_argument('-yaml', required=True, help="Path to the YAML file containing inputdir")
    parser.add_argument('-out', default='./' ,required=False, help="Output directory for Snakefiles")
    parser.add_argument('-suffix',default='.sra', required=False, help="Suffix of the methylation files to be batched")
    parser.add_argument('-batch', type=str, help="Batch size when using 'number' batching method")
    parser.add_argument('-regex', help="Regex pattern for file name batching when using 'filename' batching method")
    return parser

if __name__ == "__main__":
    parser = get_parser()
    args = parser.parse_args()
    
    
    # 获取脚本所在目录，并构建模板文件的绝对路径
    script_dir = os.path.dirname(os.path.abspath(__file__))
    snake_template = os.path.join(script_dir, "Snakefile")
    
    print(f"config file: {args.yaml}")    
    config = load_yaml(args.yaml)

    input_dir = config["input"]["inputdir"] #raw file path in config.yaml
    print(f"input_dir: {input_dir}")
    output_dir = config["output"]["outputdir"] #output file path in config.yaml
    print(f"output_dir: {output_dir}")
    out = args.out if args.out else os.path.dirname(args.yaml) #out snakefile path
    if not os.path.exists(out):
        os.makedirs(out)
    samples = [os.path.splitext(f)[0] for f in os.listdir(input_dir) if f.endswith(args.suffix)]
    if not samples:
        raise ValueError(f"No samples found in {input_dir} with suffix {args.suffix}")
    #samples = [f for f in os.listdir(input_dir) if f.endswith(args.suffix)]
    batch_size = int(args.batch) if args.batch.isdigit() else None
    regex = args.batch if not args.batch.isdigit() else None
    for bath_id, batch in enumerate(batch_samples(samples, batch_size, regex)):
        print(f"{bath_id} created for {batch}")
        copy_and_modify_snakefile(snake_template, out, bath_id+1, batch, input_dir, output_dir, os.path.abspath(args.yaml), args.suffix)
    print(f"Snakefiles created successfully in {out}")
    
    
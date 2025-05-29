# generat a yaml file for scMethtools, and update the path of software in the yaml file
# this file can be modified manually or by the script

import yaml
import argparse
from pathlib import Path
import shutil
import yaml
import os


def get_software_path(software_name):
    """使用which命令查找软件的安装路径"""
    return shutil.which(software_name)


def copy_template_and_update_yaml(template_path, software_list, args, filename="config.yaml"):
    # 复制 YAML 模板文件
    outpath = os.path.abspath(args.out)
    input_path = os.path.abspath(args.input)
    reference = os.path.abspath(args.reference)
    
    out_yaml = os.path.join(outpath,filename)
    shutil.copy(template_path, out_yaml)
    print(f"YAML template copied to {outpath}")
    # 读取 YAML 文件
    with open(out_yaml, 'r') as file:
        yaml_data = yaml.safe_load(file)
    
    #输入输出文件路径
    yaml_data['output']['outputdir'] = str(outpath)
    yaml_data['input']['inputdir'] = input_path
    yaml_data['reference']['genome'] = reference
    yaml_data['mode'] = args.end_mode
    
    # 检测并更新每个软件的路径和版本
    for software in software_list:
        software_name = software['name']
        software_path = get_software_path(software_name)
        if software == 'bismark':
            software_path = os.path.dirname(software_path.rstrip(os.sep)) #for bismark, only get the path of the directory
        # 如果检测到软件路径，更新软件位置
        if software_path:
            print(f"Updating {software_name} path to {software_path}")
            yaml_data['tools'][f'{software_name}'] = software_path
        else:
            print(f"{software_name} not found in PATH, please make sure it is installed or specify the path manually.")
    # 保存更新后的 YAML 文件
    with open(out_yaml, 'w') as file:
        yaml.dump(yaml_data, file, default_flow_style=False)
    print(f"YAML file updated at {outpath}")

def get_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i", "--input", type=Path, help="Path of input raw methylation files", default="./", required=False
    )
    parser.add_argument(
        "-r", "--reference",type=Path, help="File path of reference fasta", default="" ,required=False
    )
    parser.add_argument(
        "-m", "--end-mode", help="Sequencing layout, single or paired",  type=str, default='paired', required=False
    )
    parser.add_argument(
        "-o", "--out", type=Path, help="Result path", default="./", required=False
    )
    parser.add_argument(
        "--path-to-bismark",   type=Path, required=False
    )
    return parser

def main():
    
    # 定义软件列表
    software_list = [
        {"name": "fastqc"},
        {"name": "fastq-dump"},
        {"name": "trim_galore"},
        {"name": "bismark"},
        {"name": "cutadapt"},
        {"name": "samtools"},
        {"name": "scMethtools"},
    ]
    
    parser = get_parser()
    args = parser.parse_args()
    
    # 获取脚本所在目录，并构建模板文件的绝对路径
    script_dir = os.path.dirname(os.path.abspath(__file__))
    template_path = os.path.join(script_dir, "config.yaml")

    # 调用函数复制和更新 YAML 文件
    copy_template_and_update_yaml(template_path, software_list, args)

if __name__ == "__main__":
    main()


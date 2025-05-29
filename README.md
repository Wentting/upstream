The upstream process starts with the raw sequencing files and involves a series of steps such as quality control, alignment, and methylation calling. In scMethQ, an end-to-end workflow is used for data analysis.

The upstream process is based on snakemake, which needs to be configured in advance.

01 Prepare configuration files
Each submission (each execution of a methylation analysis) requires a snakefile and a yaml configuration file.

YAML file:
YAML is a configuration file.

Snakefile file:
Snakefile is a run file.
Each batch needs a Snakefile because the sample loops are different.
A batch can specify the batch_size, or specify the filename wildcard through regex.
For example, when batch_size = 1, two Snakefiles will be generated in the corresponding output directory.

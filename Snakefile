configfile: "./config.yaml"
inputdir = config["inputfile"]["inputdir"]
output_dir = config["outputdir"]

SAMPLES = glob_wildcards(f"{inputdir}/{{sample}}.sra").sample

rule all:
    input:
        #fastqdump 
        expand(f'{output_dir}/0-data/{{sample}}/fastq/{{sample}}_{{k}}.fastq.gz', sample=SAMPLES,k=[1,2]) if config['mode'] == "paired" else expand(f'{output_dir}/0-data/{{sample}}/fastq/{{sample}}.fastq.gz', sample=SAMPLES),
        #fastqc
        expand(f'{output_dir}/0-data/{{sample}}/fastqc/{{sample}}_{{k}}_fastqc.html', sample=SAMPLES, k=[1,2]) if config['mode'] == "paired" else expand(f'{output_dir}/0-data/{{sample}}/fastqc/{{sample}}_fastqc.html', sample=SAMPLES),
        #trim_galore
        expand(f'{output_dir}/0-data/{{sample}}/trim/{{sample}}_{{k}}_val_{{k}}.fq.gz', sample=SAMPLES, k=[1,2]) if config['mode'] == "paired" else expand(f'{output_dir}/0-data/{{sample}}/trim/{{sample}}_trimmed.fq.gz', sample=SAMPLES),
        #mapping
        expand(f'{output_dir}/1-mapping/{{sample}}/bam/{{sample}}_{{k}}_val_{{k}}_bismark_bt2.bam', sample=SAMPLES, k=[1,2]) if config['mode'] == "paired" else expand(f'{output_dir}/1-mapping/{{sample}}/bam/{{sample}}_1_val_1_bismark_bt2.bam', sample=SAMPLES),
        expand(f'{output_dir}/1-mapping/{{sample}}/bam/{{sample}}_{{k}}_val_{{k}}_bismark_bt2_SE_report.txt', sample=SAMPLES, k=[1,2]) if config['mode'] == "paired" else expand(f'{output_dir}/1-mapping/{{sample}}/bam/{{sample}}_1_val_1_bismark_bt2_SE_report.txt', sample=SAMPLES),
        #deduplicate
        expand(f'{output_dir}/2-deduplicate/{{sample}}/{{sample}}_{{k}}_val_{{k}}_bismark_bt2.deduplicated.bam', sample=SAMPLES, k=[1,2]),
        #methylation_call
        expand(f'{output_dir}/3-bedGraph/{{sample}}/CpG_methylation.bedGraph', sample=SAMPLES)
        

rule fastqdump:
    input:
        srafile = f"{inputdir}/{{sample}}.sra"
    output:
        fastqfile = f"{output_dir}/0-data/{{sample}}/fastq/{{sample}}.fastq.gz" if config["mode"] == "single" else [f"{output_dir}/0-data/{{sample}}/fastq/{{sample}}_1.fastq.gz", f"{output_dir}/0-data/{{sample}}/fastq/{{sample}}_2.fastq.gz"]
    log:
        f"{output_dir}/logs/{{sample}}_fastqdump.log"
    params: 
        option = config["fastqdump"]["param"],
        tool = config["tools"]["fastq-dump"],
        out = f"{output_dir}/0-data/{{sample}}/fastq/"
    shell:
        """
        if [ {config[fastqdump][enabled]} ]; then
            echo "Running fastqdump with params: {params.tool} {params.option} --outdir {params.out}"  >> {log}
            {params.tool} {params.option} {input.srafile} -v --outdir {params.out} >> {log} 2>&1
        else
            echo "Skipping fastq-dump step ..." >> {log}
        fi
        """

rule fastqc:
    input:
        fastqfiles = rules.fastqdump.output
    output:
        fastqc_report = f"{output_dir}/0-data/{{sample}}/fastqc/{{sample}}_fastqc.html" if config["mode"] == "single" else [f"{output_dir}/0-data/{{sample}}/fastqc/{{sample}}_1_fastqc.html", f"{output_dir}/0-data/{{sample}}/fastqc/{{sample}}_2_fastqc.html"],
        fastqc_file = f"{output_dir}/0-data/{{sample}}/fastqc/{{sample}}_fastqc.zip" if config["mode"] == "single" else [f"{output_dir}/0-data/{{sample}}/fastqc/{{sample}}_1_fastqc.zip", f"{output_dir}/0-data/{{sample}}/fastqc/{{sample}}_2_fastqc.zip"]
    log:
        f"{output_dir}/logs/{{sample}}_fastqc.log"
    params:
        fastq_path = config["tools"]["fastqc"],
        out = f"{output_dir}/0-data/{{sample}}/fastqc/"
    threads: config["fastqc"]["threads"]
    shell:
        """
        if [ {config[fastqc][enabled]} ]; then
            echo -e "Running fastq-qc with params: {params.fastq_path} --noextract -f fastq -c {input.fastqfiles} --outdir {params.out} -t {threads}" >> {log}
            {params.fastq_path} --noextract -f fastq -c  {input.fastqfiles} --outdir {params.out} -t {threads} >> {log} 2>&1
            echo "FastqC report finished.You can find the results in {params.out}." >> {log}
        else
            echo "Skipping FastQC step ..." >> {log}
        fi
        """

rule trim_galore:
    input:
        rules.fastqdump.output
    output:
        trimmed_fastq = f"{output_dir}/0-data/{{sample}}/trim/{{sample}}_trimmed.fq.gz" if config["mode"] == "single" else [f"{output_dir}/0-data/{{sample}}/trim/{{sample}}_1_val_1.fq.gz", f"{output_dir}/0-data/{{sample}}/trim/{{sample}}_2_val_2.fq.gz"]
    params:
        option = config["trim"]["param"],
        path = config["tools"]["trim_galore"],
        out = f"{output_dir}/0-data/{{sample}}/trim/",
        trimgalore_path = config["tools"]["trim_galore"],
        cutadapt_path = config["tools"]["cutadapt"]
    log:
        f"{output_dir}/logs/{{sample}}_trim.log"
    threads: config["trim"]["threads"]
    shell:
        """
        if [ {config[trim][enabled]} ]; then
            if [ {config[mode]} == "single" ]; then
                echo -e "trim_galore {params.option} --cores {threads} {input} -o  {params.out}" >> {log}
                {params.trimgalore_path} {params.option} --path_to_cutadapt {params.cutadapt_path} --cores {threads} {input} -o  {params.out} >> {log} 2>&1
            else
                echo -e "trim_galore --paired {params.option} --cores {threads} {input[0]} {input[1]} -o  {params.out}" >> {log}
                {params.trimgalore_path} --paired {params.option} --path_to_cutadapt {params.cutadapt_path} --cores {threads} {input[0]} {input[1]} -o  {params.out} >> {log} 2>&1
            fi
            echo "Trim_galore finished.You can find the data after adapter remove  in {params.out}." >> {log}
        else
            echo "Skipping Trimgalore step ..." >> {log}
        fi
        """

rule mapping:
    input:
        rules.trim_galore.output
    output:
        f"{output_dir}/1-mapping/{{sample}}/bam/{{sample}}_1_val_1_bismark_bt2.bam",
        f"{output_dir}/1-mapping/{{sample}}/bam/{{sample}}_2_val_2_bismark_bt2.bam",
        f"{output_dir}/1-mapping/{{sample}}/bam/{{sample}}_1_val_1_bismark_bt2_SE_report.txt",
        f"{output_dir}/1-mapping/{{sample}}/bam/{{sample}}_2_val_2_bismark_bt2_SE_report.txt"
    log:
        f"{output_dir}/logs/{{sample}}_mapping.log"
    threads: config["mapping"]["threads"]
    params:
        genome_ref = config["reference"]["genome"],
        option = config["mapping"]["param"],
        direction = "non_directional" if config["mapping"]["direction"] == "non_directional" else "",
        bis_parallel = config["mapping"]["parallel"],
        out = f"{output_dir}/1-mapping/{{sample}}/bam/",
        bismark_path = config["tools"]["bismark"],
        samtools_path = config["tools"]["samtools"],
        pbat = "--pbat" if config["mapping"]["pbat"] == "True" else ""
    shell:
        """
        if [ {config[mapping][enabled]} ]; then
            echo "Running Bismark mapping step for {input} ..." >> {log}
            # For single cell data, such as scBS-seq, used pbat method, which is non-directional
            # run Bismark in paired-end mode with --unmapped specified
            # if remapping umapped reads like "Dirty Harry" method, then use the following command
            # for unmapped R1
            # for unmapped R2
            #-----------------
            #for scBS-seq, Align with Bismark (--non_directional, SE mode)
            echo "Command: {params.bismark_path} {params.option} --path_to_bowtie2 /xtdisk/methbank_baoym/zhangmch/software/bowtie2-2.4.5-linux-x86_64 --{params.direction} --parallel {params.bis_parallel} --genome {params.genome_ref} --se {input[0]},{input[1]} -o {params.out} > {log} 2>&1"
            {params.bismark_path} {params.option} --path_to_bowtie2 /xtdisk/methbank_baoym/zhangmch/software/bowtie2-2.4.5-linux-x86_64 --{params.direction} --parallel {params.bis_parallel} --genome {params.genome_ref} --se {input[0]},{input[1]} -o {params.out} > {log} 2>&1
            echo "Bismark mapping finished. "            
        else
            echo "Skipping Bismark mapping step ..." >> {log}
        fi
        """

rule deduplicate:
    input:
        rules.mapping.output
    output:
        f"{output_dir}/2-deduplicate/{{sample}}/{{sample}}_1_val_1_bismark_bt2.deduplicated.bam",
        f"{output_dir}/2-deduplicate/{{sample}}/{{sample}}_2_val_2_bismark_bt2.deduplicated.bam"
    log:
        f"{output_dir}/logs/{{sample}}_deduplicate.log"
    params:
        option = config["mapping"]["deduplicate"]["param"],
        out = f"{output_dir}/2-deduplicate/{{sample}}/",
        bismark_path = config["tools"]["bismark"]
    shell:
        """
        if [ {config[mapping][deduplicate][enabled]} ]; then
            #for scBS-seq, Align with Bismark (--non_directional, SE mode)
            #then deduplicate_bismark (SE mode)
            #### This script is supposed to remove alignments to the same position in the genome which can arise by e.g. PCR amplification
            echo "For scBS library, using single-end mode(SE) deduplicate for R1 and R2 mapping results"
            {params.bismark_path}/deduplicate_bismark {params.option} {input[0]} --output {params.out} > {log} 2>&1
            {params.bismark_path}/deduplicate_bismark {params.option} {input[1]} --output {params.out} >> {log} 2>&1
            echo "Bismark deduplicate finished. "            
        else
            echo "Skipping Bismark rule deduplicate step ..." >> {log}
        fi
        """

rule methylation_call:
    input:
        rules.deduplicate.output
    output:
        f"{output_dir}/3-bedGraph/{{sample}}/CpG_methylation.bedGraph",
        f"{output_dir}/3-bedGraph/{{sample}}/non-CpG_methylation.bedGraph"
    log:
        f"{output_dir}/logs/{{sample}}_methylation_extract.log"
    params:
        option = config["mapping"]["methylation_extractor"]["param"],
        out = f"{output_dir}/3-bedGraph/{{sample}}/",
        bismark_path = config["tools"]["bismark"],
        samtools_path = config["tools"]["samtools"],
        genome_ref = config["reference"]["genome"],
    shell:
        """
        if [ {config[mapping][methylation_extractor][enabled]} ]; then
            # Methylation extraction for single-end alignments
            echo "Methylation extraction for single-end R1 and R2. " 
            {params.bismark_path}/bismark_methylation_extractor {params.option} --samtools_path {params.samtools_path} -s {input} --genome_folder {params.genome_ref} -o {params.out} > {log} 2>&1
            echo "Methylation extraction finished for R1 and R2. "   
            echo "Conducting merge step ... "
            merge {params.out}/CpG* > {params.out}/CpG_methylation.bedGraph
            merge {params.out}/non-CpG* > {params.out}/non-CpG_methylation.bedGraph        
        else
            echo "Skipping Bismark methylation extraction step ..." >> {log}
        fi
        """        
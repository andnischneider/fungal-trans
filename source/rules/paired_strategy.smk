if config["paired_strategy"] == "concordant":
    localrules:
        collate_fungi,
        collate_host

    rule fungi_concordant:
        """
        Takes as input fastq files with reads mapped concordantly and 
        non-concordantly to fungi.
        """
        input:
            f="results/bowtie2/{sample_id}/{sample_id}_{pair}.fungi.conc.fastq.gz",
            h="results/bowtie2/{sample_id}/{sample_id}_{pair}.fungi.noconc.fastq.gz",
        output:
            f="results/bowtie2/{sample_id}/{sample_id}_{pair}.fungi.fastq.gz",
            h="results/bowtie2/{sample_id}/{sample_id}_{pair}.nonfungi.fastq.gz"
        shell:
            """
            mv {input.f} {output.f}
            mv {input.h} {output.h} 
            """
    rule bt_host_concordant:
        """
        Input/Output are putative fungal reads not mapped concordantly to host
        """
        input:
            f="results/bowtie2/{sample_id}/{sample_id}_{pair}.fungi.host.noconc.fastq.gz",
            h="results/bowtie2/{sample_id}/{sample_id}_{pair}.fungi.host.conc.fastq.gz",
        output:
            f="results/bowtie2/{sample_id}/{sample_id}_{pair}.fungi.nohost.fastq.gz",
            h="results/bowtie2/{sample_id}/{sample_id}_{pair}.fungi.putative-host.fastq.gz"
        shell:
            """
            mv {input.f} {output.f}
            mv {input.h} {output.h}
            """
    rule star_host_concordant:
        input:
            "results/star/{sample_id}/{sample_id}.fungi.bam"
        output:
            R1f = "results/star/{sample_id}/{sample_id}_R1.fungi.nohost.fastq.gz",
            R2f = "results/star/{sample_id}/{sample_id}_R2.fungi.nohost.fastq.gz",
            R1h = "results/star/{sample_id}/{sample_id}_R1.fungi.putative-host.fastq.gz",
            R2h = "results/star/{sample_id}/{sample_id}_R2.fungi.putative-host.fastq.gz"
        params:
            R1f = "$TMPDIR/{sample_id}_R1.fungi.nohost.fastq",
            R2f = "$TMPDIR/{sample_id}_R2.fungi.nohost.fastq",
            R1h = "$TMPDIR/{sample_id}_R1.fungi.putative-host.fastq",
            R2h = "$TMPDIR/{sample_id}_R2.fungi.putative-host.fastq",
        shell:
            """
            # Extract reads mapped in proper pairs
            samtools fastq -f 2 -1 {params.R1f} -2 {params.R2f} -s /dev/null -0 /dev/null {input}
            # Extract reads not mapped in proper pairs
            samtools fastq -F 2 -1 {params.R1h} -2 {params.R2h} -s /dev/null -0 /dev/null {input}
            gzip {params.R1f} {params.R2f} {params.R1h} {params.R2h}
            mv {params.R1f}.gz {output.R1f}
            mv {params.R2f}.gz {output.R2f}
            mv {params.R1h}.gz {output.R1h}
            mv {params.R2h}.gz {output.R2h}
            """

elif config["paired_strategy"] == "both-mapped":
    rule fungi_both_mapped:
        """Extracts paired reads if both ends are mapped"""
        input:
            "results/bowtie2/{sample_id}/{sample_id}.fungi.bam"
        output:
            R1f = "results/bowtie2/{sample_id}/{sample_id}_R1.fungi.fastq.gz",
            R2f = "results/bowtie2/{sample_id}/{sample_id}_R2.fungi.fastq.gz",
            R1h = "results/bowtie2/{sample_id}/{sample_id}_R1.nonfungi.fastq.gz",
            R2h = "results/bowtie2/{sample_id}/{sample_id}_R2.nonfungi.fastq.gz"
        params:
            R1f = "$TMPDIR/{sample_id}/{sample_id}_R1.fungi.fastq",
            R2f = "$TMPDIR/{sample_id}/{sample_id}_R2.fungi.fastq",
            R1h = "$TMPDIR/{sample_id}/{sample_id}_R1.nonfungi.fastq",
            R2h= "$TMPDIR/{sample_id}/{sample_id}_R2.nonfungi.fastq",
            outdir = lambda wildcards, output: os.path.dirname(output.R1f),
            tmpdir = "$TMPDIR/{sample_id}"
        resources:
            runtime = lambda wildcards, attempt: attempt**2*30
        shell:
            """
            mkdir -p {params.tmpdir}
            # Extract reads with neither 'read unmapped (0x4)' nor 'mate unmapped (0x8)' flags
            samtools fastq -F 12 -1 {params.R1f} -2 {params.R2f} -s /dev/null -0 /dev/null {input}
            # Extract reads with both 'read unmapped' and 'mate unmapped' (host bin)
            samtools fastq -f 12 -1 {params.R1h} -2 {params.R2h} -s /dev/null -0 /dev/null {input}
            gzip {params.tmpdir}/*.fastq
            mv {params.tmpdir}/*.fastq.gz {params.outdir}
            """
    rule host_both_mapped:
        """
        Extracts paired reads where no more than one end is mapped -> fungal
        and where both reads are mapped -> putative host
        """
        input:
            "results/{aligner}/{sample_id}/{sample_id}.host.bam"
        output:
            R1f="results/{aligner}/{sample_id}/{sample_id}_R1.fungi.nohost.fastq.gz",
            R2f="results/{aligner}/{sample_id}/{sample_id}_R2.fungi.nohost.fastq.gz",
            R1h="results/{aligner}/{sample_id}/{sample_id}_R1.fungi.putative-host.fastq.gz",
            R2h="results/{aligner}/{sample_id}/{sample_id}_R2.fungi.putative-host.fastq.gz",
        params:
            R1f="$TMPDIR/{sample_id}_R1.fungi.nohost.fastq",
            R2f="$TMPDIR/{sample_id}_R2.fungi.nohost.fastq",
            R1h="$TMPDIR/{sample_id}_R1.fungi.putative-host.fastq",
            R2h="$TMPDIR/{sample_id}_R2.fungi.putative-host.fastq",
            only_this_end="$TMPDIR/{sample_id}.fungi.nohost.only_this_end.bam",
            only_that_end="$TMPDIR/{sample_id}.fungi.nohost.only_that_end.bam",
            both_unmapped="$TMPDIR/{sample_id}.fungi.nohost.both_unmapped.bam",
            merged="$TMPDIR/{sample_id}.fungi.nohost.merged.bam"
        resources:
            runtime = lambda wildcards, attempt: attempt**2*30
        shell:
            """
            # Get both reads mapped and store as 'putative host'
            samtools fastq -F 12 -1 {params.R1h} -2 {params.R2h} -s /dev/null -0 /dev/null {input} 
            # Get this end unmapped, other end mapped
            samtools view -b -f 4 -F 8 {input} > {params.only_that_end}
            # Get this end mapped, other end unmapped
            samtools view -b -F 4 -f 8 {input} > {params.only_this_end}
            # Get both reads unmapped
            samtools view -b -f 12 {input} > {params.both_unmapped}
            # Merge bam files
            samtools merge {params.merged} {params.only_that_end} {params.only_this_end} {params.both_unmapped}
            # Output fastq
            samtools fastq -1 {params.R1f} -2 {params.R2f} -0 /dev/null {params.merged}
            gzip {params.R1f} {params.R2f} {params.R1h} {params.R2h}
            mv {params.R1f}.gz {output.R1f}
            mv {params.R2f}.gz {output.R2f}
            mv {params.R1h}.gz {output.R1h}
            mv {params.R2h}.gz {output.R2h}
            rm {params.merged} {params.both_unmapped} {params.only_this_end} {params.only_that_end}
            """
elif config["paired_strategy"] == "one-mapped":
    rule fungi_one_mapped:
        """
        Reads with at least one mapped end go in 'fungi'
        Reads with no mapped ends go in 'nonfungi'
        """
        input:
            "results/bowtie2/{sample_id}/{sample_id}.fungi.bam"
        output:
            R1f="results/bowtie2/{sample_id}/{sample_id}_R1.fungi.fastq.gz",
            R2f="results/bowtie2/{sample_id}/{sample_id}_R2.fungi.fastq.gz",
            R1h="results/bowtie2/{sample_id}/{sample_id}_R1.nonfungi.fastq.gz",
            R2h="results/bowtie2/{sample_id}/{sample_id}_R2.nonfungi.fastq.gz",
        params:
            R1f = "$TMPDIR/{sample_id}_R1.fungi.fastq",
            R2f = "$TMPDIR/{sample_id}_R2.fungi.fastq",
            R1h = "$TMPDIR/{sample_id}_R1.nonfungi.fastq",
            R2h = "$TMPDIR/{sample_id}_R2.nonfungi.fastq",
            only_this_end = "$TMPDIR/{sample_id}_onlythisend.bam",
            only_that_end = "$TMPDIR/{sample_id}_onlythatend.bam",
            bothends = "$TMPDIR/{sample_id}_bothends.bam",
            merged = "$TMPDIR/{sample_id}_merged.bam"
        resources:
            runtime = lambda wildcards, attempt: attempt**2*60
        shell:
            """
            # Get this read with mate unmapped
            samtools view -b -F 4 -f 8 {input} > {params.only_this_end}
            # Get unmapped reads with mate mapped
            samtools view -b -f 4 -F 8 {input} > {params.only_that_end}
            # Get both reads mapped
            samtools view -b -F 12 {input} > {params.bothends}
            # Get none of the reads mapped
            samtools fastq -f 12 -1 {params.R1h} -2 {params.R2h} -s /dev/null -0 /dev/null {input}
            # Merge bam file
            samtools merge {params.merged} {params.only_this_end} {params.only_that_end} {params.bothends}
            # Extract fastq from merged file 
            samtools fastq -1 {params.R1f} -2 {params.R2f} -0 /dev/null {params.merged}
            gzip {params.R1f} {params.R2f} {params.R1h} {params.R2h}
            mv {params.R1f}.gz {output.R1f}
            mv {params.R2f}.gz {output.R2f}
            mv {params.R1h}.gz {output.R1h}
            mv {params.R2h}.gz {output.R2h}
            rm {params.merged} {params.bothends} {params.only_that_end} {params.only_this_end}
            """
    rule host_one_mapped:
        """
        Reads with at least one end mapped go in 'putative-host'
        """
        input:
            "results/{aligner}/{sample_id}/{sample_id}.host.bam"
        output:
            R1f="results/{aligner}/{sample_id}/{sample_id}_R1.fungi.nohost.fastq.gz",
            R2f="results/{aligner}/{sample_id}/{sample_id}_R2.fungi.nohost.fastq.gz",
            R1h="results/{aligner}/{sample_id}/{sample_id}_R1.fungi.putative-host.fastq.gz",
            R2h="results/{aligner}/{sample_id}/{sample_id}_R2.fungi.putative-host.fastq.gz",
        resources:
            runtime = lambda wildcards, attempt: attempt**2*30
        params:
            R1f="$TMPDIR/{sample_id}_R1.fungi.nohost.fastq",
            R2f="$TMPDIR/{sample_id}_R2.fungi.nohost.fastq",
            R1h="$TMPDIR/{sample_id}_R2.fungi.putative-host.fastq",
            R2h="$TMPDIR/{sample_id}_R2.fungi.putative-host.fastq",
            only_this_end= "$TMPDIR/{sample_id}.host_onlythisend.bam",
            only_that_end="$TMPDIR/{sample_id}.host_onlythatend.bam",
            bothends="$TMPDIR/{sample_id}.host_bothends.bam",
            merged="$TMPDIR/{sample_id}.host_merged.bam"
        shell:
            """
            # Extract only reads where neither read in a pair is mapped
            samtools fastq -f 12 -1 {params.R1f} -2 {params.R2f} -s /dev/null -0 /dev/null {input}
            
            # Get this read with mate unmapped
            samtools view -b -F 4 -f 8 {input} > {params.only_this_end}
            # Get unmapped reads with mate mapped
            samtools view -b -f 4 -F 8 {input} > {params.only_that_end}
            # Get both reads mapped
            samtools view -b -F 12 {input} > {params.bothends}
            # Merge
            samtools merge {params.merged} {params.only_this_end} {params.only_that_end} {params.bothends}
            # Extract fastq from merged file 
            samtools fastq -1 {params.R1h} -2 {params.R2h} -0 /dev/null {params.merged}
            
            gzip {params.R1f} {params.R2f} {params.R1h} {params.R2h}
            mv {params.R1f}.gz {output.R1f}
            mv {params.R2f}.gz {output.R2f}
            mv {params.R1h}.gz {output.R1h}
            mv {params.R2h}.gz {output.R2h}
            rm {params.merged} {params.bothends} {params.only_that_end} {params.only_this_end}
            """
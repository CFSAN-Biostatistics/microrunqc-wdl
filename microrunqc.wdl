# FDA-CFSAN microrunqc-wdl
# Author: Justin Payne (justin.payne@fda.hhs.gov)

version 1.0

import "https://github.com/biowdl/tasks/raw/develop/bwa.wdl" as bwa
# import "https://github.com/biowdl/tasks/raw/develop/bwa-mem2.wdl" as bwa2

workflow microrunqc {

    input {
        Array[Pair[File, File]] paired_reads
        Int max_threads = 8
        # String bwa_container = "staphb/bwa:0.7.17"
    }

    scatter (read_pair in paired_reads) {

        call identify {input:forward=read_pair.left}
        call trim { input:forward=read_pair.left, reverse=read_pair.right, name=identify.name }
        call assemble { input:forward=trim.forward_t, reverse=trim.reverse_t, name=identify.name }
        call computeN50 { input:assembly=assemble.assembly }
        call profile { input:assembly=assemble.assembly }
        call bioawk { input:assembly=assemble.assembly }
        call scan as scan_forward { input:file=trim.forward_t, length=bioawk.size }
        call scan as scan_reverse { input:file=trim.reverse_t, length=bioawk.size }
        call bwa.Index { input:fasta=assemble.assembly }
        call bwa.Mem {
            input:read1=trim.forward_t, 
                  read2=trim.reverse_t, 
                  bwaIndex=Index.index,
                  outputPrefix=identify.name,
                  threads=max_threads
            }
        call sam { input:bamfile=Mem.outputBam }
        call stat { input:samfile=sam.samfile, coverages=assemble.coverages }
        call report {
            input: 
                name=identify.name,
                size=bioawk.size,
                num_contigs=assemble.num_contigs,
                n50 = computeN50.n50,
                mlst=profile.report, 
                fscan=scan_forward.result, 
                rscan=scan_reverse.result,
                stats=stat.result
            }
    }

    call aggregate {input: files=report.record}

    output {
        File results = aggregate.result
    }

    # call concatenate { input:profiles=profile.profil }

    meta {
        author: "Justin Payne, Errol Strain, Jayanthi Gangiredla"
        email: "justin.payne@fda.hhs.gov, errol.strain@fda.hhs.gov, jayanthi.gangiredla@fda.hhs.gov"
        description: "a quality control pipeline, the WDL version of GalaxyTrakr's MicroRunQC"
    }


}

# xenial is the baseimage for almost all the staphb containers so we probably already have it

task identify {

    input {
        File forward
    }

    command <<< 
        set -e
        gunzip -c ~{forward} | head -n 1 | cut -d@ -f2- |cut -d. -f1 
    >>>

    output {
        String name = read_string(stdout())
    }

    runtime {
        container: "ubuntu:xenial"
        cpu: 1
        memory: "1024 MB"
    }

    parameter_meta {
        forward: "Paired-end reads, forward orientation"
    }


}



task trim {

    input {
        File forward
        File reverse
        String name = "reads"
    }

    command <<< 
        set -e
        gunzip -c ~{forward} > fwd.fq 
        gunzip -c ~{reverse} > rev.fq
        trimmomatic PE -threads 2 -phred33 fwd.fq rev.fq ~{name}.1.fq /dev/null ~{name}.2.fq /dev/null MINLEN:1 
    >>>
    

    output {
        File forward_t = "~{name}.1.fq"
        File reverse_t = "~{name}.2.fq"
    }

    runtime {
        container: "staphb/trimmomatic:0.39"
        cpu: 2
        memory: "1024 MB"
    }

    parameter_meta {
        forward: "Paired-end reads, forward orientation"
        reverse: "Paired-end reads, reverse orientation"
    }

}

task assemble {
    input {
        File forward
        File reverse
        String name = "assembly"
    }

    command <<< 
        set -e
        skesa --cores 8 --memory 4 --reads ~{forward} --reads ~{reverse} --contigs_out ~{name}.fa
        grep '>' ~{name}.fa | cut -f 3 -d _ > ~{name}.coverages.txt
        grep '>' ~{name}.fa | wc -l > num_contigs.txt
    >>>
    

    output {
        File assembly = "~{name}.fa"
        File coverages = "~{name}.coverages.txt"
        Int num_contigs = read_int("num_contigs.txt")
    }

    runtime {
        container: "staphb/skesa:2.4.0"
        cpu: 8
        memory: "4096 MB"
    }

    parameter_meta {
        forward: "Paired-end reads, forward orientation"
        reverse: "Paired-end reads, reverse orientation"
        name: "A name for the assembly, no spaces or bash-special characters"
    }

}

task sam {
    input {
        File bamfile
    }

    command <<<
        samtools view -h -o out.sam ~{bamfile}
    >>>

    output {
        File samfile = "out.sam"
    }

    runtime {
        container: "staphb/samtools:latest"
        cpu: 1
        memory: "512 MB"
    }

    parameter_meta {
        bamfile: "Input file, in BAM format"
    }

}

task bioawk {
    input {
        File assembly
    }

    command <<<
        bioawk -c fastx '{ total+=length($seq) } END{ print total }' < ~{assembly}
    >>>

    output {
        String size = read_string(stdout())
    }

    runtime {
        container: "cmkobel/bioawk:latest"
        cpu: 1
        memory: "512 MB"
    }

    parameter_meta {
        assembly: "Assembly to determine length of"
    }

}

task profile {
    input {
        File assembly
    }

    command <<< 
        mlst ~{assembly} 
    >>>

    output {
        File report = stdout()
    }

    runtime {
        container: "staphb/mlst:2.23.0"
        cpu: 8
        memory: "4096 MB"
    }

    parameter_meta {
        assembly: "Contigs from draft assemblies"
    }
}

task scan {
    input {
        File file
        String length
    }

    command <<<
        fastq-scan -g ~{length} < ~{file}
    >>>

    output {
        File result = stdout()
    }

    runtime {
        container: "staphb/fastq-scan:latest"
        cpu: 1
        memory: "512 MB"
    }

    parameter_meta {
        file: "Assembly file in FASTA format"
        length: "Presumed genome lengthn"
    }

}

task stat {
    input {
        File samfile
        File coverages
    }

    command <<<
        python <<CODE
import statistics
import json
# Simple statistical computations for insert size and assembly coverage
lengths = []
with open("~{samfile}") as sam:
    for line in sam:
        if not line.startswith('@'):
            length = abs(int(line.rsplit()[8]))
            if length:
                lengths.append(length)

median_insert = statistics.median(lengths)

with open("~{coverages}") as coverages:
    cvgs = [float(line.strip()) for line in coverages]

average_coverage = statistics.mean(cvgs)

print(json.dumps(dict(
    median_insert=median_insert,
    average_coverage=average_coverage
)))
CODE
    >>>

    output {
        Map[String, Float] result = read_json(stdout())
    }

    runtime {
        container: "python:3.10"
        cpu: 1
        memory: "512 MB"
    }

    parameter_meta {
        samfile: "Alignment file, in SAM format"
        coverages: "List of coverage values from the assembly step"
    }

}

task computeN50 {
    input {
        File assembly
    }

    command <<<
        seqtk comp ~{assembly} | cut -f 2 | sort -rn | awk '{ sum += $0; print $0, sum }' | tac | awk 'NR==1 { halftot=$2/2 } lastsize>halftot && $2<halftot { print $1 } { lastsize=$2 }'
    >>>

    output {
        Int n50 = read_int(stdout())
    }

    runtime {
        container: "staphb/seqtk:latest"
        cpu: 1
        memory: "512 MB"
    }

    parameter_meta {
        assembly: "Assembly file in FASTA"
    }
}

task report {
    input {
        String name = "sample"
        String size = "0"
        Int num_contigs = 0
        Int n50 = 0
        File mlst
        File fscan
        File rscan
        Map[String, Float] stats
    }

    command <<<
        python <<CODE
import json
import csv
with open("~{name}.csv", 'w') as record, open("~{mlst}") as mlst, open("~{fscan}") as fscan, open("~{rscan}") as rscan:
    fw = json.load(fscan)
    rv = json.load(rscan)
    keys = ('File','Contigs','Length','EstCov','N50','MedianInsert','MeanLength_R1','MeanLength_R2','MeanQ_R1','MeanQ_R2','Scheme','ST')
    rdr = csv.reader(mlst, delimiter="\t")
    _, scheme, st, *_ = next(rdr)
    wtr = csv.DictWriter(record, fieldnames=keys) # we're just using the keys to set the field order
    rec = dict(
        File="~{name}",
        Contigs="~{num_contigs}",
        Length="~{size}",
        EstCov='~{stats["average_coverage"]}',
        N50="~{n50}",
        MedianInsert='~{stats["median_insert"]}',
        MeanLength_R1=fw['qc_stats']['read_mean'],
        MeanLength_R2=rv['qc_stats']['read_mean'],
        MeanQ_R1=fw['qc_stats']['qual_mean'],
        MeanQ_R2=rv['qc_stats']['qual_mean'],
        Scheme=scheme,
        ST=st
    )
    wtr.writerow(rec)
CODE
    >>>

    output {
        File record = "~{name}.csv"
    }

    runtime {
        container: "python:3.10"
        cpu: 1
        memory: "512 MB"
    }

    parameter_meta {
        name: "Sample name, no special chars"
        size: "Assembly length in BP"
        num_contigs: "Number of assembly contigs"
        n50: "N50 of assembly"
        mlst: "MLST profile file"
        fscan: "Result of FASTQ-Scan on Forward file"
        rscan: "Result of FASTQ-Scan on reverse File"
        stats: "Other stats from the stats step"
    }

}

task aggregate {
    input {
        Array[File] files
    }

    command <<<
        echo "File,Contigs,Length,EstCov,N50,MedianInsert,MeanLength_R1,MeanLength_R2,MeanQ_R1,MeanQ_R2,Scheme,ST" > report.csv
        cat ~{sep=' ' files} >> report.csv
    >>>

    output {
        File result = "report.csv"
    }

    runtime {
        container: "ubuntu:xenial"
        cpu: 1
        memory: "512 MB"
    }

    parameter_meta {
        files: "Report rows from the report step"
    }

}

# task concatenate {
#     input {
#         Array[File] profiles
#     }

#     command {
#         python /tools/table-union.py ${sep=' ' profiles} > results.tsv
#     }

#     output {
#         File report = "results.tsv"
#     }

#     runtime {
#         docker: "cfsanbiostatistics/table-ops:latest"
#         cpu: 1
#         memory: "512 MB"
#     }

#     parameter_meta {
#         results: "List of MLST results"
#     }
# }
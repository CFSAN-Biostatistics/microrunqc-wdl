# FDA-CFSAN microrunqc-wdl
# Author: Justin Payne (justin.payne@fda.hhs.gov)

version 1.0

import "https://github.com/biowdl/tasks/raw/develop/bwa.wdl" as bwa
import "https://github.com/biowdl/tasks/raw/develop/bwa-mem2.wdl" as bwa2

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
        call bioawk {input: assembly=assemble.assembly}
        call scan as scan_forward {input: file=trim.forward_t, length=bioawk.size}
        call scan as scan_reverse {input: file=trim.reverse_t, length=bioawk.size}
        call bwa.Index {input:fasta=assemble.assembly}
        call bwa.Mem {
            input:read1=trim.forward_t, 
                  read2=trim.reverse_t, 
                  bwaIndex=Index.index,
                  outputPrefix=identify.name,
                  threads=max_threads}
    }

    call profile { input:assemblies=assemble.assembly }

    output {
        File results = profile.report
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
    >>>
    

    output {
        File assembly = "~{name}.fa"
    }

    runtime {
        container: "staphb/skesa:2.4.0"
        cpu: 8
        memory: "4096 MB"
    }

    parameter_meta {
        forward: "Paired-end reads, forward orientation"
        reverse: "Paired-end reads, reverse orientation"
    }

}

task bioawk {
    input {
        File assembly
    }

    command <<<
        set -e
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
        Array[File] assemblies
    }

    command <<< 
        set -e
        mlst ~{sep=' ' assemblies} 
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
        assemblies: "Contigs from draft assemblies"
    }
}

task scan {
    input {
        File file
        String length
    }

    command <<<
        set -e
        fastq-scan -g ~{length} < ~{file}
    >>>

    output {
        File results = stdout()
    }

    runtime {
        container: "staphb/fastq-scan:latest"
        cpu: 1
        memory: "512 MB"
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


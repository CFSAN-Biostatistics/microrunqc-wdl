# FDA-CFSAN microrunqc-wdl
# Author: Justin Payne (justin.payne@fda.hhs.gov)

version 1.0

workflow microrunqc {

    input {
        Array[Pair[File, File]] paired_reads
    }

    scatter (read_pair in paired_reads) {
        call trim { input:forward=read_pair.left, reverse=read_pair.right }
        call assemble { input:forward=trim.forward_t, reverse=trim.reverse_t }
    }

    call profile { input:assemblies=assemble.assembly }

    # call concatenate { input:profiles=profile.profil }

    meta {
        author: "Justin Payne, Errol Strain, Jayanthi Gangiredla"
        email: "justin.payne@fda.hhs.gov, errol.strain@fda.hhs.gov, jayanthi.gangiredla@fda.hhs.gov"
        description: "a quality control pipeline, the WDL version of GalaxyTrakr's MicroRunQC"
    }

    output {
        File results = profile.report
    }



}



task trim {

    input {
        File forward
        File reverse
    }

    command <<< 
        trimmomatic PE -threads 2 -phred33 <(gunzip -c ~{forward}) <(gunzip -c ~{reverse}) forward_t.fq /dev/null reverse_t.fq /dev/null MINLEN:1 
    >>>
    

    output {
        File forward_t = "forward_t.fq"
        File reverse_t = "reverse_t.fq"
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
    }

    command <<< 
        skesa --cores 8 --memory 4 --reads ~{forward} --reads ~{reverse} --contigs_out assembly.fa
    >>>
    

    output {
        File assembly = "assembly.fa"
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

task profile {
    input {
        Array[File] assemblies
    }

    command <<< mlst ~{sep=' ' assemblies} >>>

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


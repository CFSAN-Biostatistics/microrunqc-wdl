# FDA-CFSAN microrunqc-wdl
# Author: Justin Payne (justin.payne@fda.hhs.gov)

workflow microrunqc {

    Array[Array[File]] paired_reads

    scatter (read_pair in paired_reads){
        call trim { forward=read_pair[0], reverse=read_pair[1] }
        call assemble { forward=trim.forward, reverse=trim.reverse }
        call profile { assembly=assemble.assembly }
    }

    call concatenate { profiles=profile.profile }

    meta {
        author: "Justin Payne, Errol Strain, Jayanthi Gangiredla"
        email: "justin.payne@fda.hhs.gov, errol.strain@fda.hhs.gov, jayanthi.gangiredla@fda.hhs.gov"
        description: "a quality control pipeline, the WDL version of GalaxyTrakr's MicroRunQC"
    }



}



task trim {
    File forward
    File reverse

    command {

    }

    output {
        File forward
        File reverse
    }

    runtime {
        docker: "staphb/trimmomatic:0.39"
        cpu: 2
        memory: "1024 MB"
    }

    parameter_meta {
        forward: "Paired-end reads, forward orientation"
        reverse: "Paired-end reads, reverse orientation"
    }

}

task assemble {
    File forward
    File reverse

    command {

    }

    output {
        File assembly
    }

    runtime {
        docker: "staphb/skesa:2.4.0"
        cpu: 8
        memory: "4096 MB"
    }

    parameter_meta {
        forward: "Paired-end reads, forward orientation"
        reverse: "Paired-end reads, reverse orientation"
    }

}

task profile {
    File assembly

    command {

    }

    output {
        File profile
    }

    runtime {
        docker: "staphb/mlst:2.23.0"
        cpu: 4
        memory: "2048 MB"
    }

    parameter_meta {
        assembly: "Contigs from draft assembly"
    }
}

task concatenate {
    Array[File] profiles

    command {

    }

    output {
        File report
    }

    runtime {
        docker: "cfsanbiostatistics/table-ops:latest"
        cpu: 1
        memory: "512 MB"
    }

    parameter_meta {
        profiles: "List of MLST results"
    }
}


microrunqc-wdl Pipeline
=============================================

# Directories

* `backends/` : Backend configuration files (`.conf`)
* `workflow_opts/` : Workflow option files (`.json`)
* `examples/` : input JSON examples (SE and PE)
* `data/` : data TSV files for each platform
* `src/` : scripts for each task in WDL
* `docker/` : Dockerfiles
* `test/` : test scripts for developers

# A test input file

Use the paired-end data from here:

https://galaxytrakr.org/u/jpayne/h/big-olaf

```json
{
    "paired_reads":[
        {"left":"SRR20708232/forward.fastqsanger.gz", "right":"SRR20708232/reverse.fastqsanger.gz"},
        {"left":"SRR20708233/forward.fastqsanger.gz", "right":"SRR20708233/reverse.fastqsanger.gz"},
        {"left":"SRR20708234/forward.fastqsanger.gz", "right":"SRR20708234/reverse.fastqsanger.gz"},
        {"left":"SRR20708235/forward.fastqsanger.gz", "right":"SRR20708235/reverse.fastqsanger.gz"},
        {"left":"SRR20708236/forward.fastqsanger.gz", "right":"SRR20708236/reverse.fastqsanger.gz"},
        {"left":"SRR20708237/forward.fastqsanger.gz", "right":"SRR20708237/reverse.fastqsanger.gz"}
    ]
}
```
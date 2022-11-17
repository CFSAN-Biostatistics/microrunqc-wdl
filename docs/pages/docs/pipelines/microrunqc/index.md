---
title: ChiP-Seq
sidebar: main_sidebar
permalink: microrunqc
folder: docs
---

Hi Friend! Welcome to the documentation base to get you started using the [{{cookiecutter.project_name}}]({{ site.repo }}). This is a work in progress, so if you have any questions please don't hesitate to reach out by posting on our [issue board]({{ site.repo }}/issues). What are we going to be doing today?

 1. Installing Dependencies
 2. Download Data
 3. Choosing where you want to run your pipeline
   a. [Google Cloud](#google-cloud)
   b. [DNAnexus](#dnanexus)

## Step 1: Install Dependencies

We are going to be using a Dockerized Cromwell. If you haven't already, read about how to set up Docker and Cromwell on our [setup page]({{ site.github.url }}/setup) and then come back here.

## Step 2: Locate Data

For this step, I'm just going to show you where data is. You might need to reference (and/or download) data from this portal for future runs, but for the tutorials below we will generally direct you to files that are already (somewhere) on the resource. For now, just know that this portal exists, and it's a place to find raw data from experiments. So for now, for your FYI, open your browser to [https://www.encodeproject.org/experiments/ENCSR970FPM/](https://www.encodeproject.org/experiments/ENCSR970FPM/). We will provide further instruction for getting data for this tutorial in the steps below. 

## Step 3: Meet the Pipeline

This is the best part - it's time to make friends with your ChipSeq pipeline! What we are going to do
today is download a code repository from Github, and using the software we installed above (Cromwell and Docker) run and control a pipeline **from** our computer, and running on some service (e.g., Google Cloud or DNAnexus).

### Clone the Repository

First let's start on your local machine. It's recommended to make a little working location for the code we are going to pull from Github. 

```bash
mkdir -p pipelines
cd pipelines            (-- you can download other future pipelines to this same folder!
git clone https://github.com/ENCODE-DCC/chip-seq-pipeline2
cd chip-seq-pipeline2
```

What did we just download? Let's take a look!

```bash
$ tree $PWD -L 1
chip-seq-pipeline2
├── backends      
├── chip.wdl      (-- pronounced "widdle" - this is the workflow! 
├── docker_image
├── examples
├── genome
├── installers
├── Jenkinsfile   (-- a text file with instructions for testing
├── LICENSE      
├── README.md
├── src           (-- source code
├── test
└── workflow_opts

8 directories, 4 files
```

Most of it is self explanatory, but actually let's just ignore the chunk of files and tell you what you should
care about. 

 - **chip.wdl** is the brain of the operation. This is a definition of inputs and outputs that is going to be given to Cromwell to run the pipeline.
 - **workflow_ops** is where you will find files that define variables for different pipeline runners. For example if you are working on Google Cloud, you might be asked to set preference for a zone. 
 
Let's not worry about the rest for now. You can continue on by selecting the environment where you want to run the pipeline.


## Step 4: Choose Where to Run
These pipelines are quite substantial when it comes to data and analyses, so we are jumping right in to running them on substantial resources (and yes, this doesn't include your dinky laptop). Let's start with Google Cloud.

### Google Cloud
To use Google Cloud we are going to:

 1. Set up a Google Project
 2. Customize a local configuration file for Docker
 3. Launch the workflow


#### Setting Up

Google Cloud is organized around the idea of a [project](https://console.developers.google.com/project). A project comes down to a credit card that is associated with a portal where you can click to manage resources like databases and servers. So the steps we want to take today are:

**Google Project**

This is where, if you are a graduate student or part of a lab, you should have a conversation with your team about what the project is called, and importantly, what credit card will go on file. You can create a [Google Project here](https://console.developers.google.com/project).

**Storage**

Google Cloud has several kinds of database, and the one that we are going to be using is called [Google Storage](https://console.cloud.google.com/storage/browser). You can imagine Google Storage as a big bucket of files in the cloud. This is where we are going to be storing our data and analysis outputs! Set up a Google Cloud Storage bucket [here](https://console.cloud.google.com/storage/browser).

**Application Programming Interfaces**

An Application Programming Interface (API) is a way for a user like you and I to control a Google resource, such as storage or running an analysis on a server. Your Google Project has an [API Manager](https://console.developers.google.com/apis/library) page where you should go and ensure the following APIs are enabled:

  * Google Compute Engine
  * Google Cloud Storage
  * Genomics API

You might guess that "compute engine" is where servers (called instances) are deployed to run analyses, Google Storage is where the outputs go, and (a new one we are learning about!) the Genomics API is going to plug us in to some awesome functions for genomics that Google (and Stanford!) have worked on and released.

**Quotas**

A quota refers to how much (or how little, depending on if your glass is half full or half empty) of a resource your project is allowed to use. In our case, we want to increase our quota for SDD/HDD storage, and the number of vCPUs (virtual CPUs) to process more samples simultaneously. To do this, go to the Google [Compute Engine API](https://console.cloud.google.com/iam-admin/quotas) and increase these quotas:

  * CPUs
  * Persistent Disk Standard (GB)
  * Persistent Disk SSD (GB)
  * In-use IP addresses
  * Networks

That's it for the setup of the cloud! Let's jump back to our local machines and start working with some code.


#### Customize Local Variables

Remember the [workflow_opts](workflow_opts) folder you found locally?

```bash
docker.json  sge.json  slurm.json
```

For Google Cloud, we are going to use Docker containers, so we are going to be editing the `docker.json` file.
Open up that file in an editor now.

**Zones**

A zone refers to a physical location of a cloud resource. You can think of it like selecting a time zone, and it's logical for you to choose a subset that are close to you. For example, the defaults are for zones close to California:

```json
{
  "default_runtime_attributes" : {
    ...
    "zones": "us-west1-a us-west1-b us-west1-c",
    ...
}
```

**Preemptible**

A [preemptible instance](https://cloud.google.com/compute/docs/instances/preemptible) is basically leftover compute from someone else. They come at a lot cheaper than a normal instance, but the catch is that your job can be killed at any time. Since this would not be ideal say, in the middle of a long run, we are going to disable them.


```json
{
  "default_runtime_attributes" : {
    ...
    "preemptible": "0",
    ...
}
```

The entire setup is pretty simple, the entire file might look like this:

```json
{
    "default_runtime_attributes" : {
        "docker" : "quay.io/encode-dcc/chip-seq-pipeline:v1",
        "zones": "us-west1-a us-west1-b us-west1-c us-central1-c us-central1-b",
        "preemptible": "0",
        "bootDiskSizeGb": "10",
        "noAddress": "false"
    }
}
```

#### Data Inputs

Okay, time to return to our data! First, know that there are two kinds of data that you need:

 - **reference genomes** are provided in Google Storage. Each file in Google Storage has it's own URL, and you can identify one of these URLs because it starts with `gs://`. Take a look at the [data available here](https://console.cloud.google.com/storage/browser/encode-pipeline-genome-data?project=encode-dcc-1016)
 - **experiment genomes** (controls) were originally provided in the [data portal](https://www.encodeproject.org/experiments/ENCSR970FPM/) we referenced earlier, and have also been downloaded to [Google Cloud Storage](https://console.cloud.google.com/storage/browser/chip-seq-pipeline-test-samples/ENCSR936XTK) for you to use. This is called an experiment, and it's raw data that will go into our pipeline.

> If you have any trouble referencing the storage links above, contact the ENCODE-DCC or the owner of your project to get permissions.

**Reference Genomes**

From the [Google Cloud Storage](https://console.cloud.google.com/storage/browser/encode-pipeline-genome-data?project=encode-dcc-1016), we are interested in this path:

 - https://storage.googleapis.com/encode-pipeline-genome-data/hg38_google.tsv

How did I choose these files, and get the public links? I looked at the input json file (shown below) and matched names to ones that I saw in Storage. I then copied the "Public Link" in the interface.

**Experiment Genomics**
The data that we will use is from an experiment downloaded in the data portal referenced earlier. Specifically, we are interested in these files:

 - gs://chip-seq-pipeline-test-samples/ENCSR936XTK/rep1-R1.fastq.gz
 - gs://chip-seq-pipeline-test-samples/ENCSR936XTK/rep1-R2.fastq.gz
 - gs://chip-seq-pipeline-test-samples/ENCSR936XTK/rep2-R1.fastq.gz,
 - gs://chip-seq-pipeline-test-samples/ENCSR936XTK/rep2-R2.fastq.gz

 - gs://chip-seq-pipeline-test-samples/ENCSR936XTK/ctl1-R1.fastq.gz
 - gs://chip-seq-pipeline-test-samples/ENCSR936XTK/ctl1-R2.fastq.gz
 - gs://chip-seq-pipeline-test-samples/ENCSR936XTK/ctl2-R1.fastq.gz,
 - gs://chip-seq-pipeline-test-samples/ENCSR936XTK/ctl2-R2.fastq.gz


> Where did this data come from?

Specifically, for this example we are using **fastq** files for controls from the experiment page. This is actually pretty hard to find! You would first need to click on the experiment ID next to the bolded "Controls" and then scroll down to download files by clicking on the "Association Graph" or "File Details" panel. It's about halfway down the page. It should start downloads for `ENCFF*.fastq.gz` files. From here, you would need to upload these files to somewhere in your project storage, to again get a public URL for them akin to the one for the reference genome. 

Now it's a game of matching! Let's now define these variables in an input json file, the one that corresponds with the experiment name under "examples" (`ENCSR936XTK.json`).

```bash
$ ls examples/
dx  ENCSR000DYI.json  ENCSR936XTK.json  google  klab
```

Here is what the template file looks like before we edit it:

```bash
$ cat examples/ENCSR936XTK.json 
{
    "chip.pipeline_type" : "tf",
    "chip.genome_tsv" : "hg38/hg38_local.tsv",
    "chip.fastqs" : [
        [["rep1-R1.fastq.gz",
          "rep1-R2.fastq.gz"]],
        [["rep2-R1.fastq.gz",
          "rep2-R2.fastq.gz"]]
    ],
    "chip.ctl_fastqs" : [
        [["ctl1-R1.fastq.gz",
          "ctl1-R2.fastq.gz"]],
        [["ctl2-R1.fastq.gz",
          "ctl2-R2.fastq.gz"]]
    ],

    "chip.paired_end" : true,

    "chip.choose_ctl.always_use_pooled_ctl" : true,
    "chip.qc_report.name" : "ENCSR936XTK",
    "chip.qc_report.desc" : "ZNF143 ChIP-seq on human GM12878"
}
```

Let's make a copy to edit, just for Google Cloud.

```bash
cp examples/ENCSR936XTK.json examples/gce-ENCSR936XTK.json
```

Open that copied file (gce means Google Compute Engine). Here is how it looks after we fill in the variables! Note that the file paths are now to the files in Google Cloud Storage.

```bash
$ cat examples/gce-ENCSR936XTK.json
{
    "chip.pipeline_type" : "tf",
    "chip.genome_tsv" : "gs://encode-pipeline-genome-data/hg38_google.tsv",
    "chip.fastqs" : [
       [["gs://chip-seq-pipeline-test-samples/ENCSR936XTK/rep1-R1.fastq.gz",
         "gs://chip-seq-pipeline-test-samples/ENCSR936XTK/rep1-R2.fastq.gz"]],
       [["gs://chip-seq-pipeline-test-samples/ENCSR936XTK/rep2-R1.fastq.gz",
         "gs://chip-seq-pipeline-test-samples/ENCSR936XTK/rep2-R2.fastq.gz"]]
    ],
    "chip.ctl_fastqs" : [
       [["gs://chip-seq-pipeline-test-samples/ENCSR936XTK/ctl1-R1.fastq.gz",
         "gs://chip-seq-pipeline-test-samples/ENCSR936XTK/ctl1-R2.fastq.gz"]],
       [["gs://chip-seq-pipeline-test-samples/ENCSR936XTK/ctl2-R1.fastq.gz",
         "gs://chip-seq-pipeline-test-samples/ENCSR936XTK/ctl2-R2.fastq.gz"]]
    ],

    "chip.paired_end" : true,

    "chip.choose_ctl.always_use_pooled_ctl" : true,
    "chip.qc_report.name" : "ENCSR936XTK",
    "chip.qc_report.desc" : "ZNF143 ChIP-seq on human GM12878"
}
```

Next, let's learn how to interact with instances.

#### GCloud

Google's command line client is called "gcloud" and we will use it to interact with instances.
You have two options here:
 
 1. Create an instance that already has gcloud installed or
 2. Install it on your computer locally.

If you are just playing around, I'd recommend the first option as it's quicker to [create a new instance](https://console.cloud.google.com/compute/instances) here.
If you intend to use Google Cloud resources on a somewhat regular basis, then you should download
the same tools [here](https://cloud.google.com/sdk/downloads).

While it's best to follow the steps provided to install at the link above, here is the quick way to
get verification keys for a new project:

```bash
gcloud auth login --no-launch-browser
```

You'll probably need to generate credentials for your particular project. For example, for a project
with id `chip-seq-pipeline` I would then issue the command:

```bash
PROJECT=chip-seq-pipeline
gcloud config set project "${PROJECT}"
Updated property [core/project].
```

and then generate the credentials file (give it a more meaningful name):

```bash
unset GOOGLE_APPLICATION_CREDENTIALS
gcloud auth application-default login --no-launch-browser
```

It will give you a url to open, and a code there to copy paste back into the terminal. When you do that, it will tell you that you have generated default application credentials!

```bash
Go to the following link in your browser:

...

Credentials saved to file: [/home/vanessa/.config/gcloud/application_default_credentials.json]

These credentials will be used by any library that requests
Application Default Credentials.

To generate an access token for other uses, run:
  gcloud auth application-default print-access-token
```

We will rename this to be specific to the project, and export that variable.

```bash
mv $HOME/.config/gcloud/application_default_credentials.json $HOME/.config/gcloud/$PROJECT.json
export GOOGLE_APPLICATION_CREDENTIALS=$HOME/.config/gcloud/$PROJECT.json
```

This last renaming step is of course totally up to you! If you use many projects and might easily forget,
this is an easy way to remember which file. Remember that for the project you are working with, you will need
to export the variable `GOOGLE_APPLICATION_CREDENTIALS` in order to use gcloud.

#### Run the Pipeline!

Finally, we've finishing setting up Google cloud, we have our code, and we are ready to run Cromwell! As
a reminder, here is the entry point to Cromwell, inside of a Docker container.

```bash
docker run broadinstitute/cromwell:prod
```

To run the pipeline, first define variables:

```bash
OUTPUT_BUCKET=gs://workflow-challenge
PROJECT=chip-seq-pipeline
SAMPLE_NAME=vanessasaurus
WDL=chip.wdl
INPUTS=examples/gce-ENCSR936XTK.json
```

Since we need our Google Application Credentials flie to show up in the container, I'm going to copy it to the present working directory too, and modify the path for the container.

```bash
cp $GOOGLE_APPLICATION_CREDENTIALS $PWD
GOOGLE_CREDENTIALS_DOCKER=$(basename $GOOGLE_APPLICATION_CREDENTIALS)
echo ${GOOGLE_CREDENTIALS_DOCKER}
chip-seq-pipeline.json
```

Then issue this command. Notice that we are binding the present working directory to /opt (which I checked is empty) that way we can access all of our files from in the container at `/opt`:

```bash
docker run -v $PWD/:/opt -it --entrypoint java -e GOOGLE_APPLICATION_CREDENTIALS=/opt/${GOOGLE_CREDENTIALS_DOCKER} broadinstitute/cromwell:prod -jar -Dconfig.file=/opt/backends/backend.conf -Dbackend.default=google -Dbackend.providers.google.config.project=${PROJECT} -Dbackend.providers.google.config.root=${OUTPUT_BUCKET}/${SAMPLE_NAME} /app/cromwell.jar run /opt/${WDL} -i /opt/${INPUTS} -o /opt/workflow_opts/docker.json
```

The above command will run, and take at least a day to finish. If your terminal briefly loses internet
connectivity, it should re-establish the connection again. Note that my workflow bugged out, and the bug
is [recorded here](https://github.com/vsoch/wdl-pipelines/blob/master/docs/pages/docs/pipelines/chip-seq/gce-error.txt).

### DNAnexus
[DNAnexus](https://www.dnanexus.com/) is an online cloud platform for doing genomic analyses. You should [log in](https://platform.dnanexus.com/login).

#### Step 1. The Project

Create a project, or if you are part of a lab, find the correct project to work from. In my case, the first screen I saw had a small table of projects, and I clicked on "Chip-Seq-Pipeline". I didn't interact much with the interface here, but I can imagine you would want to possibly upload data to use, or find paths for data that already exist (is there a "copy paste" way to do it?)


#### Step 2. Install Dependencies

Just kidding, nobody wants to install things from scratch! You **could** follow the [instructions here](https://wiki.dnanexus.com/Downloads#DNAnexus-Platform-SDK) to install a set of local tools to interact with DNAnextus. OR you could just use a Docker container that has the tools you need. Actually, we are going to use two containers:

 - [vanessa/dx-toolkit](https://hub.docker.com/r/vanessa/dx-toolkit): (has dxWDL and dx-toolkit)

```bash
$ docker run vanessa/dx-toolkit
java -jar dxWDL.jar <action> <parameters> [options]

Actions:
  compile <WDL file>
    Compile a wdl file into a dnanexus workflow.
    Optionally, specify a destination path on the
    platform. If a WDL inputs files is specified, a dx JSON
    inputs file is generated from it.
```

You are of course free to install on your host, but it is easier to use a pre-built container. This is my preference.

#### Step 3. Convert to wdl

At this point, we have found containers with both the DNAnexus sdk and a conversion tool, and we have also previously cloned the chip-seq repository. Let's now convert the widdle (wdl) file to a format that DNAnexus can use to launch an equivalent workflow.

> On DNANexus platform TSV files are on dx://project-FB7q5G00QyxBbQZb5k11115j.

```bash
docker run -it --entrypoint bash -v $PWD:/opt vanessa/dx-toolkit

# Interactive login
dx login

WDL=chip.wdl
DEST_DIR_ON_DX=/workflow-challenge
source /dx-toolkit/environment
java -jar /dxWDL-0.69.jar compile /opt/chip.wdl -f -folder ${DEST_DIR_ON_DX} -defaults /opt/examples/dx/ENCSR936XTK_dx.json -extras /opt/workflow_opts/docker.json -project project-FJ4V1Kj0F4ZfqgJvGg9fz8Gg
```
The above would need to be programmatic - but given the (I think?) need for a login, I'm doing this way for now. Note that the project ordering for the `dx login` changes on each new login. Here is the output for a random test run:

```
Unsupported runtime attribute preemptible,we currently support Set(dx_instance_type, disks, docker, cpu, memory)
Unsupported runtime attribute bootDiskSizeGb,we currently support Set(dx_instance_type, disks, docker, cpu, memory)
Unsupported runtime attribute noAddress,we currently support Set(dx_instance_type, disks, docker, cpu, memory)
Unsupported runtime attribute zones,we currently support Set(dx_instance_type, disks, docker, cpu, memory)
Runtime attribute time for task merge_fastq is unknown
Runtime attribute time for task trim_fastq is unknown
Runtime attribute preemptible for task bwa is unknown
Runtime attribute time for task bwa is unknown
Runtime attribute time for task filter is unknown
Runtime attribute time for task bam2ta is unknown
Runtime attribute time for task spr is unknown
Runtime attribute time for task pool_ta is unknown
Runtime attribute time for task xcor is unknown
Runtime attribute time for task fingerprint is unknown
Runtime attribute time for task choose_ctl is unknown
Runtime attribute time for task macs2 is unknown
Runtime attribute preemptible for task spp is unknown
Runtime attribute time for task spp is unknown
Runtime attribute time for task idr is unknown
Runtime attribute time for task overlap is unknown
Runtime attribute time for task reproducibility is unknown
Runtime attribute time for task qc_report is unknown
Runtime attribute time for task read_genome_tsv is unknown
Runtime attribute time for task rounded_mean is unknown
Runtime attribute time for task compare_md5sum is unknown
Empty output section, no outputs will be generated
lookupObject: pipeline-test-samples/encode-chip-seq-pipeline/ENCSR936XTK/fastq/rep1-R1.fastq.gz
lookupObject: pipeline-test-samples/encode-chip-seq-pipeline/ENCSR936XTK/fastq/rep1-R2.fastq.gz
lookupObject: pipeline-test-samples/encode-chip-seq-pipeline/ENCSR936XTK/fastq/rep2-R1.fastq.gz
lookupObject: pipeline-test-samples/encode-chip-seq-pipeline/ENCSR936XTK/fastq/rep2-R2.fastq.gz
lookupObject: pipeline-test-samples/encode-chip-seq-pipeline/ENCSR936XTK/fastq/ctl1-R1.fastq.gz
lookupObject: pipeline-test-samples/encode-chip-seq-pipeline/ENCSR936XTK/fastq/ctl1-R2.fastq.gz
lookupObject: pipeline-test-samples/encode-chip-seq-pipeline/ENCSR936XTK/fastq/ctl2-R1.fastq.gz
lookupObject: pipeline-test-samples/encode-chip-seq-pipeline/ENCSR936XTK/fastq/ctl2-R2.fastq.gz
lookupObject: pipeline-genome-data/hg38_dx.tsv
workflow-FJ76b6Q0F4Zk8P2zF7QbZjvQ
$
```


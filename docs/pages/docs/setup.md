---
title: Setup
sidebar: main_sidebar
permalink: setup
folder: docs
toc: false
---

## 1. Docker

If you aren't familiar with Docker, it's a container technology that will let us easily use entire packaged software. You should set up and install Docker [per the instructions here](https://docs.docker.com/install/). Make sure that you are able to run the "hello-world" example _without needing superuser priviledges_ before you continue this tutorial.

## 2. Cromwell

[Cromwell](http://cromwell.readthedocs.io/en/stable/tutorials/FiveMinuteIntro/) is a workflow management tool developed by the Broad Institute that we will be using to interact with the pipelines. It's a Java program, so the executable that you will interact with is a ".jar" file. Thankfully, they have a Docker container ([https://hub.docker.com/r/broadinstitute/cromwell/](https://hub.docker.com/r/broadinstitute/cromwell/)) that you can use without needing to install the hairy Java application on your computer. Cromwell can be used locally, but also interacts with cloud resources to run pipelines. To get you started, we will just show you the executable that you can use locally.

```bash
$ docker run broadinstitute/cromwell:prod

cromwell 33-88e1a73-SNAP
Usage: java -jar /path/to/cromwell.jar [server|run|submit] [options] <args>...

  --help                   Cromwell - Workflow Execution Engine
  --version                
Command: server
Starts a web server on port 8000.  See the web server documentation for more details about the API endpoints.
Command: run [options] workflow-source
Run the workflow and print out the outputs in JSON format.
  workflow-source          Workflow source file.
  --workflow-root <value>  Workflow root.
  -i, --inputs <value>     Workflow inputs file.
  -o, --options <value>    Workflow options file.
  -t, --type <value>       Workflow type.
  -v, --type-version <value>
                           Workflow type version.
  -l, --labels <value>     Workflow labels file.
  -p, --imports <value>    A directory or zipfile to search for workflow imports.
  -m, --metadata-output <value>
                           An optional directory path to output metadata.
Command: submit [options] workflow-source
Submit the workflow to a Cromwell server.
  workflow-source          Workflow source file.
  --workflow-root <value>  Workflow root.
  -i, --inputs <value>     Workflow inputs file.
  -o, --options <value>    Workflow options file.
  -t, --type <value>       Workflow type.
  -v, --type-version <value>
                           Workflow type version.
  -l, --labels <value>     Workflow labels file.
  -p, --imports <value>    A directory or zipfile to search for workflow imports.
  -h, --host <value>       Cromwell server URL.
```

If your Docker is configured correctly and you've pulled and run the image, you should see the print to
the console above. Good job! Did you notice in the command we added the "prod" tag to the end?
"Prod" refers to the production image tag. If you need to find other tags, view them [here](https://hub.docker.com/r/broadinstitute/cromwell/tags/).

That's all you need to get started! Let's now go back to the [Pipelines section]({{ site.repo }}/#pipelines) where you can choose a pipeline you want to run.

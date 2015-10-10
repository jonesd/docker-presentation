# Docker

### David Jones, October 2015

---

## Content
+ Docker Introduction
+ Example
+ Orchestration

---

## Docker: the product
+ Docker: Build, Ship, Run
+ Docker is an open platform for building, shipping and running distributed applications. It gives programmers, development teams and operations engineers the common toolbox they need to take advantage of the distributed and networked nature of modern applications.

&nbsp;

## Docker: the open-source project
+ Docker is an open-source project that automates the deployment of applications inside software containers, by providing an additional layer of abstraction and automation of operating-system-level virtualization on Linux, Mac OS and Windows. (wikipedia)

---

## What is a container?
+ Container is a wrapper around an OS process
+ Process has its own file system, networking, and isolated process tree
+ Isolation is based on features of the Linux kernel
+ You can think of the container as a kind of sandboxed process

---

## Why are containers interesting?
+ Fast startup time
 + Just starting a normal OS process
+ Better utilization of host machine
 + Process isolation allows low overhead separation between hosted applications
+ Container as a process/application level component

---

# Docker Example

---
## Create a static website
+ Given a clean Linux machine how could we implement a static website?
+ Apache httpd + website files
+ We could install apache httpd in the usual fashion (apt-get install httpd...)
+ Instead use docker
+ Download the 'httpd' version 2.4 docker image from docker hub and run as a container named 'web'

```
$ docker run -d --name web httpd:2.4
Unable to find image 'httpd:2.4' locally
2.4: Pulling from library/httpd
e0f29a2edd11: Pull complete
042b0607e62f: Pull complete
....
Status: Downloaded newer image for httpd:2.4
252c24a14105cdae81b7175933a899cb073303729b55da81217d1208b46edf18

$ docker ps -a
CONTAINER ID        IMAGE               COMMAND              CREATED             STATUS              PORTS               NAMES
252c24a14105        httpd:2.4           "httpd-foreground"   15 seconds ago      Up 14 seconds       80/tcp              web

$ curl localhost
curl: (7) Failed to connect to localhost port 80: Connection refused
```

+ Why did it fail?

---

## Open network access to host

+ Containers are self-enclosed sandbox by default
+ httpd process within the web container is listening on port 80
+ No access outside of the container to that port

```
$ docker run -d --name web -p 80:80 httpd:2.4
7acf5e7346ad42ef6cb6895a1bda7fe0c2ded6baaae2df8ce22a3f16c108351a
$ curl localhost
<html><body><h1>It works!</h1></body></html>
$ docker ps -a
CONTAINER ID        IMAGE               COMMAND              CREATED             STATUS              PORTS                NAMES
7acf5e7346ad        httpd:2.4           "httpd-foreground"   5 minutes ago       Up 5 minutes        0.0.0.0:80->80/tcp   web
```

---

## What about our own content?
+ How do we get httpd to show our own content?
+ Where did the "It works!" page come from?
+ httpd by default serves content from the /htdocs directory
+ The Docker Hub page for the httpd image indicates that the image uses the /usr/local/apache2/htdocs

```
$ ls /usr/local/apache2/htdocs
ls: cannot access /usr/local/apache2/htdocs: No such file or directory
```

+ There is no httpd installed on the host. It is within the docker container
+ How do we see inside the container?

```
$ docker run -it --rm httpd:2.4 bash
root@3a9fe458f3f6:/usr/local/apache#  ls /usr/local/apache2/htdocs
index.html
root@3a9fe458f3f6:/usr/local/apache2#  cat /usr/local/apache2/htdocs/index.html
<html><body><h1>It works!</h1></body></html>
root@3a9fe458f3f6:/usr/local/apache2# exit
exit
```

+ The index.html is included with the httpd docker image

---

## Override the image's index.html
+ Create our own index.html page on the host file system

```
$ echo "<html><body>New Website</body></html>" > public-html/index.html
$ cat index.html
<html><body>New Website</body></html>
```

+ Run httpd container but replacing the image's /htdocs directory with the host's public-html directory
+ Add a volume that links a directory from the host to the container's filesystem

```
$ docker run -d --name web -p 80:80 -v $PWD/public-html:/usr/local/apache2/htdocs httpd:2.4
3970ee59b95472926b35f1b2f407f9ca0166a768ede417f1700f61337e0cf3cf
$ curl localhost
<html><body>New Website</body></html>
```
+ If we change the host's index.html then the served content will be updated too for the running container

```
$ echo "<html><body>New Website VERSION 2</body></html>" > public-html/index.html
$ curl localhost
<html><body>New Website VERSION 2</body></html>
```
---

## Container file system is Ephemeral
+ By default the file system of a docker container is initialized with the contents of the image
 + * except for a few system host files
+ File system within the container is writeable
+ Any changes made within the running container will be preserved only until the container removed
+ Container will be recreated from the image again
+ All modified data that needs to be persisted should be through a volume to the host file system
+ Advantage
 + Each container starts with the same file system content

---

## Make our own httpd image with our own website files
+ docker images are a deployable unit, or component
+ rather than using a host volume for the website content we could create our own httpd image with this content
+ how do you define the contents of an image?

```
$ vi Dockerfile
FROM httpd:2.4

COPY ./public-html/ /usr/local/apache2/htdocs/
```
+ We will extend the httpd image and include our html content
+ Build a new image called my-site

```
$ docker build -t my-site .
Sending build context to Docker daemon 3.584 kB
Step 0 : FROM httpd:2.4
 ---> 81c42bcdc4cc
Step 1 : COPY ./public-html/ /usr/local/apache2/htdocs/
 ---> 120c47d82994
Successfully built 120c47d82994
```

+ We can use it in the same wab as the httpd

```
$ docker run -d --name web -p 80:80 my-site
f3d80c02031ead6741fc43ee0ae52c9368f6958937715e50071387d942f5cde8

$ curl localhost
<html><body>New Website VERSION 2</body></html>

$ docker ps -a
CONTAINER ID        IMAGE               COMMAND              CREATED             STATUS              PORTS                NAMES
f3d80c02031e        my-site             "httpd-foreground"   3 minutes ago       Up 3 minutes        0.0.0.0:80->80/tcp   web
```

---

## How was the httpd image defined?
+ You can access the Dockerfile from docker hub
+ Most public images on the hub are built automatically from github repositories

+ docker-library/httpd/2.4/Dockerfile

```
FROM debian:jessie

ENV HTTPD_PREFIX /usr/local/apache2
ENV PATH $PATH:$HTTPD_PREFIX/bin
RUN mkdir -p "$HTTPD_PREFIX" \
	&& chown www-data:www-data "$HTTPD_PREFIX"
WORKDIR $HTTPD_PREFIX

# install httpd runtime dependencies
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		libapr1 \
		libaprutil1 \
		libpcre++0 \
		libssl1.0.0 \
	&& rm -r /var/lib/apt/lists/*
...
```

---

## Rest API for our website
+ Our website has now been extended to be AngularJS based that needs a Restful API on the server
+ This API will be implemented in NodeJS so we will need an installation of node and npm and being running a node process
+ If we were using a VirtualMachine we would package this up with httpd as a single unit
+ Docker would aim to use a second node container linked to the httpd container

```
user@helloreceipts-vm:~/projects/coe/docker/rest$ cat Dockerfile
FROM node:4.1-onbuild
EXPOSE 3000
```

```
user@helloreceipts-vm:~/projects/coe/docker/rest$ cat server.js
var express = require('express');
var app = express();

app.get('/', function (req, res) {
  res.send('Hello World!');
});

var server = app.listen(3000, function () {
  var host = server.address().address;
  var port = server.address().port;

  console.log('Example app listening at http://%s:%s', host, port);
});
```

```
$ docker build -t my-rest .
Sending build context to Docker daemon 4.096 kB
Step 0 : FROM node:4.1-onbuild
4.1-onbuild: Pulling from library/node
16b189cc8ce6: Pull complete
...
# Executing 3 build triggers
Trigger 0, COPY package.json /usr/src/app/
Step 0 : COPY package.json /usr/src/app/
Trigger 1, RUN npm install
Step 0 : RUN npm install
 ---> Running in ff83f6002ab0
...

$ docker run -it --rm --name rest -p 3000:3000 my-rest
npm info it worked if it ends with ok
npm info using npm@2.14.4
npm info using node@v4.1.2
npm info prestart my-rest@
npm info start my-rest@

> my-rest@ start /usr/src/app
> node server.js

Example app listening at http://:::3000
```
---

# Questions?
---

## Why/Motivation
+ Expectations for deployed systems have changed - trickle down from large websites
+ The move from Java centric server apps to polyglot distributed systems + pressure to deliver more frequently (finally) + API/Messaging centric architectures +  + DevOps = Complex systems + opportunity for influencing delivered environment
+ Screenshots (perhaps demo)
 + With only docker installed download/startup multiple container in one command
 + Deploy same thing on external machines
 + See centralized logging

---

## Containers History
+ Data centre - better utilization
+ Kernel changes - security
+ Heroku/PaaS
+ Docker

---

## Continuous delivery of images

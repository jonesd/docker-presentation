# Docker Introduction

### David Jones, October 2015

---

## Docker: the product
+ Docker: Build, Ship, Run
+ Docker is an open platform for building, shipping and running distributed applications. It gives programmers, development teams and operations engineers the common toolbox they need to take advantage of the distributed and networked nature of modern applications. (docker.com)

&nbsp;

## Docker: the open-source project
+ Docker is an open-source project that automates the deployment of applications inside software containers, by providing an additional layer of abstraction and automation of operating-system-level virtualization on Linux, Mac OS and Windows. (wikipedia)

---

## What is a container?
+ Container is a wrapper around an OS process
+ Process has its own file system, networking, and isolated process tree
+ Isolation is based on features of the Linux kernel
+ You can think of the container as a kind of sandboxed process

&nbsp;

+ Containers seem like light-weight Virtual Machines - in practice they are quite different

---

## Why are containers interesting?
+ Fast startup time
 + Just starting a normal OS process vs starting a virtual machine with an entire OS
+ Better utilization of host machine
 + Process isolation allows low overhead separation between hosted applications
+ Container as a self-contained deployable component
 + More of an application/component level technology than virtual machine infrastructure
+ Container images are host agnostic and can be deployed anywhere
 + Large body of ready-made containers to be used
+ Fits into a DevOps centric approach
 + Specified by configuration files that can be version controlled
 + APIs and command line access allows containers to fit into delivery pipelines and scripted solutions

---

## Docker Example Application

---

## Docker Example

+ Build and run a simple Restful NodeJS application to provide a list of countries using mongodb

+ Given a clean Linux machine how could we implement a node application?
 + NodeJS + MongoDB + application node code
+ We could install nodejs and mongodb in the usual fashion (apt-get install node...) + scripts to copy application code and run node
+ Instead we will use docker

---

## Restful Application

+ Linux based host with only docker installed on it
+ Setup a Rest container that runs a server.js file using nodejs
+ Setup a DB container that runs MongoDB
+ Host and containers linked using network
+ Notice that there are two containers vs one virtual machine

![Complete Application](images/overall.jpg)

---

## Create the Rest container

---

## Start node container
+ The docker hub website contains hundreds of official repositories and 100,000+ user contributed repositories
+ Download the 'node' version 4.1 docker image from docker hub and run as a container named 'rest'

```
$ docker run -it --rm --name rest \
    node:4.1

Unable to find image 'node:4.1' locally
4.1: Pulling from library/node
116f2940b0c5: Pull complete
...
Status: Downloaded newer image for node:4.1
```
+ Download succeeded but then the rest container immediately Exited
+ No node code to run!

---

## Simple node/expressjs application
+ Create a simple `server.js` node application using expressjs
+ /api/countries returns a static list of countries
+ Notice that there are no docker specific changes

```
var express = require('express');
var app = express();

app.get('/api/countries', function (req, res) {
  res.send(['ca', 'us']);
});

var server = app.listen(80, function () {
  var host = server.address().address;
  var port = server.address().port;

  console.log('Example app listening at http://%s:%s', host, port);
});
```

---

## Share code with rest container
+ Containers start isolated from the host so we will need to provide access to our server.js code
+ Use the following docker run arguments
 + `-v` volume argument to map the host file system current directory to the container's /usr/src/app directory
 + `-w` argument sets the container's working directory to /usr/src/app

---

## Install npm dependencies
+ First we will install the expressjs and its dependencies
+ Start a new container to execute 'npm install'
 + Container starts without delay as image/executable already downloaded to host

```
$ docker run -it --rm --name rest \
    -v $PWD:/usr/src/app -w /usr/src/app \
    node:4.1 \
    npm install

npm info using npm@2.14.4
npm info using node@v4.1.2
...
express@4.13.3 node_modules/express
npm info ok
```

+ This will result in a node_modules directory present on the host file system as `-v` volume is bidirectional

---

## Run application
+ Start a new container to execute 'npm start'

```
$ docker run -it --rm --name rest \
    -v $PWD:/usr/src/myapp -w /usr/src/myapp \
    node:4.1 \
    npm start

> rest@1.0.0 start /usr/src/myapp
> node server.js

Example app listening at http://:::80
```

+ Is the application responding to HTTP requests?

```
$ curl localhost/api/countries
curl: (7) Failed to connect to localhost port 80: Connection refused
```

---

## Inaccessible port 80

+ Containers are isolated from the host and other containers by default
+ node process within the rest container is listening on port 80
+ No access outside of the container to that port

![Design](images/rest-unconnected.jpg)

---

## Open port 80 to host

+ Restart the container using the -p option to make the container's port 80 accessible to the host at port 80
 + We could map between different port numbers on the container and the host, including random host port to overcome port conflicts

```
$ docker run -it --rm --name rest \
    -p 80:80 \
    -v $PWD:/usr/src/myapp -w /usr/src/myapp \
    node:4.1 \
    npm start

Example app listening at http://:::80

$ curl localhost/api/countries
["ca","us"]
```

+ Success!
---


![Complete Application](images/rest.jpg)

---

## Rest container as deployable unit

---

## Building a custom rest image
+ Currently the rest container is defined by:
 + node standard image
 + server.js and package.json from the host filesystem
 + docker run command line arguments
+ So many parts make it difficult to deploy to another host

+ We can build a new image that packages server.js and package.json with node as a single component
+ This image could be run on any docker installation

---

## Rest image Dockerfile
```
$ vi Dockerfile
FROM node:4.1.2

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY package.json /usr/src/app/
RUN npm install
COPY . /usr/src/app

CMD [ "npm", "start" ]
```
+ Notice how some of the docker run command line options are represented in this file

---

## Dockerfile format

+ Content of an image is defined by the Dockerfile
+ Sequence of command are run within a build container resulting in an image
+ Limited number of Dockerfile commands
 + FROM image to extend another image, typically terminating in a base Linux OS
 + RUN command line executables within the container, for example the base OS's package manager such as (apt-get install ...)
 + CMD set the default command when the built image is later run as a container
+ Plus a few more commands - often related to the docker command line arguments

---

+ Dockerfile for the parent `node:4.1.2` image

```
FROM buildpack-deps:jessie

RUN set -ex \
  && for key in \
    9554F04D7259F04124DE6B476D5A82AC7E37093B \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    0034A06D9D9B0064CE8ADF6BF1747F4AD2306D93 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
  ; do \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  done

ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 4.1.2

RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --verify SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.gz\$" SHASUMS256.txt.asc | sha256sum -c - \
  && tar -xzf "node-v$NODE_VERSION-linux-x64.tar.gz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.gz" SHASUMS256.txt.asc

CMD [ "node" ]
```

---

## Building the rest image

+ Most public images are created automatically from a github repository
+ Manually build the my-rest image using the Dockerfile

```
$ docker build -t my-rest .

Sending build context to Docker daemon 4.096 kB
Step 0 : FROM node:4.1.2
Step 1 : RUN mkdir -p /usr/src/app
...
Step 6 : CMD npm start
Successfully built 8baaa541b2b5
```

+ We can see the new image in the local list of images

```
$ docker images

REPOSITORY  TAG     IMAGE ID      CREATED        VIRTUAL SIZE
my-rest     latest  8baaa541b2b5  5 minutes ago  644.2 MB
node        4.1     a3157e9edc18  6 days ago     641.2 MB
```

---

## Run the my-rest image

+ Run the my-rest image in a similar way to the public node image
+ No longer have to use the -v volume and -w arguments to provide access to the javascript

```
$ docker run -it --rm --name rest \
    -p 80:80 \
    my-rest

Example app listening at http://:::80

$ curl localhost/api/countries
["ca","us"]
```

+ Much better
---

## Create the DB container

---

![Complete Application](images/db-start.jpg)

---

## Storing data in MongoDB

+ Currently the list of countries is hard coded into the javascript in the rest application
+ We would prefer to store the countries in a separate database, in this case mongodb
+ If we were using a Virtual Machine approach we would install mongo with nodejs in a single machine
+ With containers we decompose the system into one container per service, or process

---

## Start mongo container

+ We can use the official mongo image from docker hub
+ Mongo is run as a second container

```
$ docker run -it --rm --name db \
    mongo:3

Unable to find image 'mongo:3' locally
3: Pulling from library/mongo
MongoDB starting : pid=1 port=27017 dbpath=/data/db 64-bit host=dc3f52f88be4
allocating new datafile /data/db/local.0, filling with zeroes...
waiting for connections on port 27017
```
+ Notice that the mongo daemon creates a blank database at `/data/db/local`

---

## Rerun the mongo container

+ Lets stop and remove the existing db container and restart it

```
got signal 2 (Interrupt), will terminate after current cmd ends
dbexit:  rc: 0

$ docker run -it --rm --name db \
    mongo:3

MongoDB starting : pid=1 port=27017 dbpath=/data/db 64-bit host=1166fde3cefb
allocating new datafile /data/db/local.0, filling with zeroes...
waiting for connections on port 27017
```

+ Notice that the mongo daemon creates a blank database at `/data/db/local` again...

&nbsp;

+ We just lost all the data in our database!

---

## Container file system is Ephemeral

+ By default the file system of a docker container is initialized with the contents of the image
 + except for a few system host files
+ File system within the container is writeable
+ Any changes made within the running container will be preserved only until when the container is removed
+ Container will be recreated from the image again
+ The result as that all modified data that needs to be persisted should be accessed through a volume on the host file system
+ Advantage
 + Each container starts with the same file system content
 + Supports version controlled configuration by reducing the value of humans modifying a running container by executing ad-hoc commands  

---

## Storing mongo container data files on the host file system

+ We will again use the __-v__ argument to map the host file system directory to the container's /usr/src/app directory

```
$ mkdir db-volume
$ docker run -it --rm --name db \
    -v $PWD/db-volume:/data/db \
    mongo:3

    MongoDB starting : pid=1 port=27017 dbpath=/data/db 64-bit host=1166fde3cefb
    allocating new datafile /data/db/local.0, filling with zeroes...
    waiting for connections on port 27017
```
 + Looking at the host file system we see that the mongo datafiles are now present on the host filesystem

```
$ ls db-volume/
journal  local.0  local.ns  mongod.lock  storage.bson
```
---

## Linking the DB and Rest containers

+ The DB container is now functional but inaccessible to the rest container

![Complete Application](images/db-unconnected.jpg)

---

## Linking the DB and Rest containers

+ We now need to link the DB and Rest containers
+ As we saw before containers are isolated from the host and each other by default
+ Rather than linking the DB with the host, allowing any process access to the mongo service, we will instead link the Rest container to the DB container directly
+ The result isolates the mongo service to the rest container

```
$ docker run -it --rm --name rest \
    -p 80:80 \
    --link db:db \
    my-rest
```

---

## Accessing the mongo service from the Rest container

+ The rest container can now resolve the mongo service through the `db` domain name
 + Docker rewrites the rest container's `/etc/hosts` file to make it easier to reference linked containers

```javascript
var MongoClient = require('mongodb').MongoClient;
var url = 'mongodb://db:27017/countries';
MongoClient.connect(url, function(err, db) {
  ...
}

app.get('/api/countries', function (req, res) {
  getAllCountries(MongoClient, function(err, countries) {
    res.send(countries);  
  });
});

```
+ Rather than relying directly on the `db` domain name from the --link the full URL can be passed into the container as an environment variable
---

## Example

+ The application is now functional with the rest container using data from the db container

![Complete Application](images/overall.jpg)

---

## Orchestration

---

## docker-compose

+ Applications will typically be decomposed into more than one container
+ It is also common to have many instances of the same image running
 + Performance - spreading load across many containers
 + Availability - containers in different physical locations
+ How can this be accomplished?
 + Custom scripting that runs commands similar to the example so far
 + Additional tool and configuration that specifies the runtime ensemble

+ Docker provides the __docker-compose__ tool as the starting point for this  
+ There are many alternatives by third parties that build upon docker

---

## docker-compose.yml

+ docker-compose.yml file that specifies the runtime containers
+ All containers defined in a single file
+ Translates __docker run__ arguments into yml elements

```
$ vi docker-compose.yml
rest:
  build: .
  links:
  - db
  ports:
  - "80:80"

db:
  image: mongo:3
  volumes:
  - ./db-volume:/data/db
```
+ Notice how arguments of the rest and db run commands are represented here
---

## docker-compose up

+ The rest and db containers can now be started with a single command

```
$ docker-compose up

Creating rest_db_1...
Creating rest_rest_1...
db_1   | MongoDB starting : pid=1 port=27017 dbpath=/data/db 64-bit host=f80942718a9f
db_1   | waiting for connections on port 27017
rest_1 | > node server.js
rest_1 | Example app listening at http://:::80
```

+ docker-compose now allows us to start/stop/restart/access logs for all the containers as if they were a single unit
+ containers can also be configured with the restart element to restart on application failures and host machine startup
---

## Docker in practice

---

## Extending the host

+ So far we have decomposed our runtime environment into multiple containers, then reassembled using orchestration
+ Why not just stick to a single virtual machine?
+ Container isolation and the docker API opens the door for more options on the host
+ Multiple applications/versions on the same host to improve hardware utilization
 + Front the machine with an HTTP proxy to direct network traffic to appropriate containers (jwilder/nginx-proxy)
+ Provide shared services across all containers running on the host using docker API
 + Collect logs and ship them to a central logging repository (digitalwonderland/logstash-forwarder)
 + Standard monitoring for all containers

---

![Host](images/docker-host.jpg)

---

## Platform as a Service

+ Extension of the host leads to Platform as a Service PaaS
+ Development team focus on applications with a standard set of tooling and hosting built around it
+ Example PaaS implementations: Heroku, AWS Elastic Beanstalk, CloudFoundry, and others
+ "12 Factor App" provides guidance on designing applications for deploying to this space

---

## Docker host runtime environment

+ Docker runtime requires a modern linux kernel for the host
+ Compatible with most Linux implementations
+ Windows and MacOS hosts are supported by starting up a compatible Linux host within a Virtual Machine using Docker Machine
 + Microsoft is working on Windows Server Containers support for Windows Server 2016
+ There are also a number of cloud based hosting providers now for Docker containers
 + Amazon EC2 Container Service, Microsoft Azure, Google Container Engine, etc
 + Cloud providers typical implement their own orchestration tooling for multiple containers rather than use docker-compose

---
## Docker on the developer machine

+ Docker helps on the developer machine but is not a complete solution
+ Versioned configuration of runtime environment is a win
 + Reduces cost to setup, keeps dev machines closer to production, and indicates differences
+ Docker containers can be used to handle third party services, such as databases or HTTPD fronts where volume sharing is sufficient
+ Docker isn't a natural fit to host an IDE such as Eclipse.
 + Volume sharing between host filesystem and container provides a partial solution
 + Debugging is a barrier unless remote debugging is supported
 + Eclipse Mars provides basic container management and may be enhanced in the future

---

## Wrapping up

---

## Docker/Containers: Pros

+ Pros
 + Wrapping deployment artefacts with the entire runtime environment and configuration
 + Runtime configuration under version control rather than ad-hoc host environments
 + Fits well with internet architectures such as micro-services
 + Supports polyglot implementations
 + Docker image is becoming the standard for individual container images
 + Lots of content and help available online
 + Large number of off-the shelf containers ready to be used
 + Docker API allows for automation and third-party extensions
 + Orchestration/multiple machine support is improving
 + Commercial support for customers

---

## Docker/Containers: Cons

+ Cons
 + Lots of alternatives for orchestration of docker containers - docker-compose still under development
 + Existing applications need to be updated - mostly around passing in URL to access services in other containers
 + Jenkins support for docker containers is not complete
 + More opinionated about architecture than VM based approach
 + Increase in conceptual complexity by introducing new abstraction/layer
 + Docker is still young software and releases can break existing functionality
 + Found Ubuntu host had fewer setup issues than CentOS hosts

---

## Intelliware experience

+ ICT
 + 3 projects using Docker for Jenkins builds, delivery pipeline to staging and QA
  + Jenkins builds artefacts within Docker containers
  + Use local docker registry to access built images - similar to maven
  + Sharing hosts between multiple applications
 + HelloReceipts production runs on container based Heroku PaaS
+ e-Health
 + 1 project using Docker images for QA and production preview
  + Delivery pipeline by copying built images using docker save/load between machines
+ FS
 + 1 project using Vagrant on developer machines for runtime environment
 + Customers adopting Docker and exploring CloudFoundry

---

## Docker Concepts Summary

+ Docker Images are run to produce runtime Containers
+ Images can be private or downloaded from the public docker hub
+ Images defined by Dockerfile
+ Container runs one process
+ Containers are isolated by default
+ Container network access from host or other containers can be configured
+ Container disk storage is ephemeral and is lost when the container is removed
+ Host file system can be linked to container for permanent storage
+ Application decomposed into many containers
+ Docker compose can run and link multiple containers (docker-compose.yml)

---

# Questions?

&nbsp;

+ http://docker.com
+ http://12factor.net/
+ https://github.com/jonesd/docker-presentation
---

## Appendices

---

## Host Processes

+ How are the running containers from the example represented from the host's perspective?

```
$ ps auxf

root     /usr/bin/docker daemon -H fd://
999      \_ mongod
root     \_ npm                                         
root     |   \_ sh -c node server.js
root     |       \_ node server.js
root     \_ docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 80 -container-ip 172.17.0.40 -container-port 80
```

+ The single command process from containers are visible:
 + DB container == mongod executable
 + Rest container == npm executable
+ Docker's docker-proxy implementation for proxying from the host's port 80



---

## Image file size

+ It is easy to end up with images that are hundreds of MBs in size
+ Starting from tiny OS/libraries such as busybox can result in much smaller images
+ Images are composed of layers, one per Dockerfile command, and may be shared to reduce actual consumed disk space
+ https://imagelayers.io/

```
$ docker images

REPOSITORY  TAG                 IMAGE ID            VIRTUAL SIZE
my-rest     latest              8baaa541b2b5        644.2 MB
mongo       3                   5e53867deb23        261.3 MB
node        4.1.2               a3157e9edc18        641.2 MB
node        4.1                 a3157e9edc18        641.2 MB
mongo       2.6                 1dbbf952200b        392.3 MB
maven       3-jdk-8-onbuild     403227dcca40        827 MB
node        0.10                53a86cbfc348        633.4 MB
```

---

## Motivation
+ Expectations for deployed systems have changed - trickle down from large websites
+ The move from Java centric server apps to polyglot distributed systems + pressure to deliver more frequently (finally) + API/Messaging centric architectures +  + DevOps = Complex systems + opportunity for influencing delivered environment
+ Screenshots (perhaps demo)
 + With only docker installed download/startup multiple container in one command
 + Deploy same thing on external machines
 + See centralized logging

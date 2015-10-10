#!/bin/bash
docker run -ti -d --name slidefire -v `pwd`/lib/logo.png:/opt/presentation/lib/logo.png  -v `pwd`/css/custom.css:/opt/presentation/css/custom.css -v `pwd`/images:/opt/presentation/images -v  `pwd`:/opt/presentation/lib/md -v `pwd`/build:/build -p 8000:8000 rossbachp/presentation


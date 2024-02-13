## How to setup awcli v2 in alpine
<pre>
  What is Alpine Linux?
Alpine Linux is an extremely lightweight Linux distribution popular for use in CI/CD pipelines owing to the very small image size. The reason it is so tiny is that it has nothing installed on it at all beyond basic kernel and core linux packages like echo, printf and sed. Even bash needs to be installed to run shell scripts etc and even standard packages like those that handle certificates for corporate use (ca-certificates) need to be installed to work through proxies etc. The latest current version at time of writing is v3.18 but some earlier versions are kept up to date until their support period runs out.

Situation
My client was running a very old Alpine 3.12 linux build pipeline image used in their CI/CD pipeline. The image dated way back to 2020 and as with all older Linux distributions suffers from a lack of continued support for late package versions such as Python etc. This limits the ability to install supported software and their dependencies. As a build pipeline image, it only had a single job to do which was to deploy Infrastructure as Code (IaC) and was working perfectly fine. There were several vulnerabilities due to outdated packages being reported on and there was keen interest in upgrading to a later version of Alpine but also no express driver to do so until recently during a planned feature update with CDK (forcing an upgrade).

Task
The task given to me was to upgrade to AWS CLI v2 to support new features and services being released and allow collapsing of legacy workarounds. In addition, there was a planned upgrade to CDK v1 to CDK v2. After some initial investigation, it was determined there was a need to upgrade the build image to a later version of Alpine to support both streams of work. This was required to support Python 3.10+ as part of the latest build for AWS CLI v2 requirements and Nodejs 16+ for CDK v2. I needed to find a way to build the image with a simple way to maintain the AWS CLI v2 and CDK v2 versions.

Action
Build a working build pipeline image based on Alpine v3.17.3 to bootstrap new AWS accounts using a combination of CDK v2 and AWS CLI v2. This involved learning the nuances of the changes made in Alpine Linux v3.17 and mitigating those challenges to work inside a highly regulated corporate environment. Access had to work through corporate proxies and the image would be used as a complete bootstrapped image with pre-installed packages and gems to reduce the time needed to run release pipelines. This article speaks to installing AWS CLI v2 only.

Changes to Alpine Linux
One of the major changes made to Alpine Linux from v3.17 and beyond is that TLS 1.3 is enforced and legacy TLS renegotiation is disabled. In prior versions (starting in v3.15), TLS 1.3 was enabled also however legacy renegotiation hadn’t yet been disabled. This means that sources using say TLS 1.2 or earlier will no longer work under Alpine v3.17+.

When working within corporate proxy environments, it is necessary for your proxies to support TLS 1.3 but if they don’t, you will get “legacy renegotiation is disabled” errors when trying to access packages and repositories using TLS 1.3 such as Ruby Gems and Nodejs packages via NPM. This will require you to enable legacy renegotiation between your Docker container and your proxies:

 

  printf ‘openssl_conf = openssl_init\n\
  \n\
  [openssl_init]\n\
  ssl_conf = ssl_sect\n\
  \n\
  [ssl_sect]\n\
  system_default = system_default_sect\n\
  \n\
  [system_default_sect]\n\
  Options = UnsafeLegacyServerConnect’ >> openssl.cnf && \
  export OPENSSL_CONF=/app/openssl.cnf && \

To install and update any certificates issued by the corporate Certificate Authority (CA) to allow for trusting connections between proxies and the client, you need to install the “ca-certificate” package. I had to copy in the certificates from another base image that already had been bootstrapped so the CA certs were installed prior. To support access to apk repositories using TLS 1.3 until your proxies support it, it may be necessary to either use HTTP repositories or enable legacy renegotiation globally. In my case as I wanted to have the capability to easily roll back and not reconfigure the global “/etc/ssl/openssl.cnf”, I went with using HTTP apk repositories instead:

 

RUN sed -ie “s/https/http/g” /etc/apk/repositories && \
  apk add —update —no-cache ca-certificates coreutils tar bash curl wget jq && \
  update–ca-certificates && \

By enabling HTTP repository access temporarily, this allows access to APK repositories for installing necessary baseline certificate packages. For other 3rd party repositories such as Ruby Gems and NPM packages, these need to have . Noting that this should only be a temporary solution, we can use an environment variable to leverage a temporary openssl.cnf configuration that can easily be removed later and without affecting the system-wide openssl.cnf.
Result
Installing AWS CLI v2
One of the updates made to AWS CLI in version 2 is that it is no longer possible to install it via Python Pip like you could in version 1. In AWS CLI v2, there are several ways of installing it however not all of these work in Alpine. The AWS CLI v2 is compiled with the glibc library, however Alpine Linux uses the musl libc library. This renders official AWS instructions useless for working with Alpine. There are many articles that mention the gcompat compatibility package, however this wasn’t enough for me to compile the AWS CLI v2 packages. Below is the solution that worked for me and it involved a lot more packages to successfully compile:

apk add —update —no-cache python3 py3-pip python3-dev binutils make cmake gcc g++ libc-dev libffi-dev openssl-dev groff && \
  rm -rf /var/cache/apk/* && \

While there are many examples of ways to install and compile the packages, here is what worked for me on Alpine 3.17.3:

 

export AWS_CLI_VERSION=2.11.14
  pwd
  git clone –single-branch –depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git
  cd aws-cli
  ./configure –with-install-type=portable-exe –with-download-deps
  make
  make install
  cd ..
  aws –version
  pwd

NOTE: I had originally set the AWS CLI version to latest, however this failed to compile. Looking through GitHub I discovered that several versions beyond 2.11.14 release had failed builds. I couldn’t get any of them working until I used 2.11.14. I created an environment variable to keep the upgrade path easier. The rest of the code worked perfectly.
 
In the example below, I use the official Alpine image repository. In corporate environments with many concurrent requests, this can quickly overwhelm your daily image pull limit. It is recommended in corporate environments to publish select images to a private repository such as Elastic Container Registry (ECR). In the environment I was working on – they had published a base Alpine 3.17.3 image to a private ECR repository and had pipeline variables for setting the base image for both prod and non-prod ECR repositories.
TL;DR
The complete Dockerfile can be found below:

 

FROM ${BASE_IMAGE} AS certs

ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

COPY –from=certs /usr/local/share/ca-certificates/* /usr/local/share/ca-certificates/

FROM alpine:3.17.3

WORKDIR /app

COPY source /app

RUN sed -ie “s/https/http/g” /etc/apk/repositories && \
  printf ‘openssl_conf = openssl_init\n\
  \n\
  [openssl_init]\n\
  ssl_conf = ssl_sect\n\
  \n\
  [ssl_sect]\n\
  system_default = system_default_sect\n\
  \n\
  [system_default_sect]\n\
  Options = UnsafeLegacyServerConnect’ >> openssl.cnf && \
  export OPENSSL_CONF=/app/openssl.cnf && \
  apk add –update –no-cache ca-certificates coreutils tar bash curl wget jq && \
  update-ca-certificates && \
  apk add –update –no-cache git openssh zip build-base && \
  apk add –update –no-cache python3 py3-pip python3-dev binutils make cmake gcc g++ libc-dev libffi-dev openssl-dev groff && \
  rm -rf /var/cache/apk/* && \
  export AWS_CLI_VERSION=2.11.14 && \
  pwd && \
  git clone –single-branch –depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git && \
  cd aws-cli && \
  ./configure –with-install-type=portable-exe –with-download-deps && \
  make && \
  make install && \
  cd .. && \
  aws –version && \
  pwd

Removing Changes
Once end-to-end TLS 1.3 is supported and you no longer need to enable legacy renegotiation, simply remove the following lines:

  printf ‘openssl_conf = openssl_init\n\
  \n\
  [openssl_init]\n\
  ssl_conf = ssl_sect\n\
  \n\
  [ssl_sect]\n\
  system_default = system_default_sect\n\
  \n\
  [system_default_sect]\n\
  Options = UnsafeLegacyServerConnect’ >> openssl.cnf && \
  export OPENSSL_CONF=/app/openssl.cnf && \

Then, set apk repositories back to HTTPS before removing it entirely:

sed -ie “s/http/https/g” /etc/apk/repositories && \

An Easier Way To Install AWS CLI v2
Not all customer environments enable the use of the apk edge repositories for compliance and/or governance reasons (as in my own case). If your organisation or customer does, then your life got a whole lot simpler as you can simply install the “aws-cli” package from the apk edge repository (https://pkgs.alpinelinux.org/package/edge/community/x86_64/aws-cli):

apk add python3 py3-awscrt py3-certifi py3-colorama py3-cryptography py3-dateutil py3-distro py3-docutils py3-jmespath py3-prompt_toolkit py3-ruamel.yaml py3-urlib3 aws-cli –repository=https://dl-cdn.alpinelinux.org/alpine/edge/community
</pre>

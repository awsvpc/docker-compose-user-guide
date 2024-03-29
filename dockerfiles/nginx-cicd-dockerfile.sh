FROM nginx:${NGINX_VERSION:-1.23-alpine}

ARG BUILD_DATE
ARG BUILD_VERSION
ARG GIT_COMMIT
ARG GIT_URL

ENV VENDOR="DevOpsCornerId"
ENV AUTHOR="DevOpsCorner.id <support@devopscorner.id>"
ENV IMG_NAME="cicd-alpine"
ENV IMG_VERSION="3.16"
ENV IMG_DESC="Docker Image CI/CD"
ENV IMG_ARCH="amd64/x86_64"

ENV ALPINE_VERSION="3.16"
ENV CICD_VERSION="1.23"

LABEL maintainer="$AUTHOR" \
      architecture="$IMG_ARCH" \
      alpine-version="$ALPINE_VERSION" \
      cicd-version="$CICD_VERSION" \
      org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.name="$IMG_NAME" \
      org.label-schema.description="$IMG_DESC" \
      org.label-schema.vcs-ref="$GIT_COMMIT" \
      org.label-schema.vcs-url="$GIT_URL" \
      org.label-schema.vendor="$VENDOR" \
      org.label-schema.version="$BUILD_VERSION" \
      org.label-schema.schema-version="$IMG_VERSION" \
      org.opencontainers.image.authors="$AUTHOR" \
      org.opencontainers.image.description="$IMG_DESC" \
      org.opencontainers.image.vendor="$VENDOR" \
      org.opencontainers.image.version="$IMG_VERSION" \
      org.opencontainers.image.revision="$GIT_COMMIT" \
      org.opencontainers.image.created="$BUILD_DATE" \
      fr.hbis.docker.base.build-date="$BUILD_DATE" \
      fr.hbis.docker.base.name="$IMG_NAME" \
      fr.hbis.docker.base.vendor="$VENDOR" \
      fr.hbis.docker.base.version="$BUILD_VERSION"

ENV ANSIBLE_VERSION=2.12.2
# ENV ANSIBLE_TOWER_CLI_VERSION=3.3.9   # Depreciated, change to AWX-Cli (awxkit)
ENV AWXKIT_VERSION=21.9.0
ENV PACKER_VERSION=1.8.4
ENV TERRAFORM_VERSION=1.3.5
ENV TERRAGRUNT_VERSION=0.41.0
ENV TERRASCAN_VERSION=1.17.0
ENV HELMFILE_VERSION=0.144.0
ENV KUBECTL_VERSION=1.25.4
ENV CHECKOV_VERSION=2.1.244
ENV AWS_CLI_VERSION=2.9.1
ENV VERIFY_CHECKSUM=false

USER root
RUN apk add --no-cache \
      git \
      curl \
      zip \
      unzip \
      wget; sync

RUN apk add --no-cache \
      build-base \
      bash \
      jq \
      ca-certificates \
      openssl \
      openssh \
      openssh-server \
      vim \
      busybox-extras \
      nano \
      gcompat \
      groff \
      cmake \
      libffi-dev \
      bzip2-dev \
      python3 \
      python3-dev \
      py3-pip &&\
      set -ex; sync

# ==================== #
#  Install Terragrunt  #
# ==================== #
RUN wget -O /usr/local/bin/terragrunt \
      https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64 &&\
      chmod +x /usr/local/bin/terragrunt; sync &&\
      # ================ #
      #  Install Packer  #
      # ================ #
      wget -O packer_${PACKER_VERSION}_linux_amd64.zip \
      https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip &&\
      unzip packer_${PACKER_VERSION}_linux_amd64.zip -d /usr/local/bin &&\
      rm -f packer_${PACKER_VERSION}_linux_amd64.zip; sync &&\
      # =================== #
      #  Install Terrascan  #
      # =================== #
      wget -O terrascan.tar.gz \
      https://github.com/accurics/terrascan/releases/download/v${TERRASCAN_VERSION}/terrascan_${TERRASCAN_VERSION}_Linux_x86_64.tar.gz &&\
      tar -zxvf terrascan.tar.gz -C /usr/local/bin &&\
      chmod +x /usr/local/bin/terrascan &&\
      rm terrascan.tar.gz; sync &&\
      # =================== #
      #  Install Infracost  #
      # =================== #
      curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | bash; sync

# =============== #
#  Install TFSec  #
# =============== #
# RUN curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash; sync
COPY --from=aquasec/tfsec-alpine:latest /usr/bin/tfsec /usr/local/bin/tfsec

# =============== #
#  Install TFenv  #
# =============== #
RUN git clone https://github.com/tfutils/tfenv.git ~/.tfenv &&\
      echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc; sync &&\
      ln -sf ~/.tfenv/bin/* /usr/local/bin &&\
      mkdir -p ~/.local/bin/ &&\
      ln -sf ~/.tfenv/bin/* ~/.local/bin; sync

# =================== #
#  Install Terraform  #
# =================== #
RUN /usr/local/bin/tfenv install ${TERRAFORM_VERSION} &&\
      /usr/local/bin/terraform use ${TERRAFORM_VERSION}; sync &&\
      /usr/local/bin/terraform version; sync

# ============== #
#  Install Helm  #
# ============== #
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 &&\
      chmod +x get_helm.sh; sync &&\
      export VERIFY_CHECKSUM=${VERIFY_CHECKSUM} && ./get_helm.sh; sync &&\
      helm version; sync

# ===================== #
#  Install Helm Plugins #
# ===================== #
RUN helm plugin install https://github.com/databus23/helm-diff; sync &&\
      helm plugin install https://github.com/hypnoglow/helm-s3.git; sync &&\
      helm repo add stable https://charts.helm.sh/stable; sync &&\
      helm repo update; sync

# ================== #
#  Install Helmfile  #
# ================== #
RUN wget -O /usr/local/bin/helmfile \
      https://github.com/roboll/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_linux_amd64 &&\
      chmod +x /usr/local/bin/helmfile &&\
      helmfile --version; sync

# ================= #
#  Install Kubectl  #
# ================= #
RUN wget -O /usr/local/bin/kubectl \
      https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl &&\
      chmod +x /usr/local/bin/kubectl; sync

# =================== #
#  Install AWSCli v2  #
# =================== #
# RUN curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip -o awscliv2.zip &&\
#       unzip awscliv2.zip; sync &&\
#       ./aws/install --bin-dir /usr/local/bin/; sync
COPY --from=devopscorner/aws-cli:latest /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=devopscorner/aws-cli:latest /usr/local/bin/ /usr/local/bin/

# ========================= #
# Install Python Libraries  #
# ========================= #
RUN python3 -m pip install pip &&\
      pip3 install --upgrade pip==22.3.1 cffi &&\
      # ================= #
      #  Install Ansible  #
      # ================= #
      pip3 install --no-cache-dir \
      ansible-core==${ANSIBLE_VERSION} \
      # ansible-tower-cli==${ANSIBLE_TOWER_CLI_VERSION} \
      awxkit==${AWXKIT_VERSION} \
      PyYaml \
      Jinja2 \
      httplib2 \
      six \
      requests \
      boto3 \
      # ================= #
      #  Install Checkov  #
      # ================= #
      checkov==${CHECKOV_VERSION} &&\
      # setup root .ssh directory
      mkdir -p /root/.ssh &&\
      chmod 0700 /root/.ssh &&\
      chown -R root. /root/.ssh; sync

RUN chmod +x /tmp/*.sh

# ============= #
#  Cleanup All  #
# ============= #
RUN rm -rf /var/cache/apk/* /root/.cache /tmp/*

WORKDIR /root

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 22 80

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]

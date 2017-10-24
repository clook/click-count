FROM tomcat:8-jre8

RUN rm -rf webapps/* && \
	curl -so envconsul.tgz https://releases.hashicorp.com/envconsul/0.6.2/envconsul_0.6.2_linux_amd64.tgz && \
	tar xzvf envconsul.tgz && \
	mv envconsul /usr/local/bin/envconsul && \
	chmod +x /usr/local/bin/envconsul

COPY target/clickCount.war webapps/ROOT.war
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT /entrypoint.sh

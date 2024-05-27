# Use a base image with Java
FROM openjdk:11

# Set env var DHIS2_HOME='/home/dhis/config'
ENV JAVA_HOME='/usr/lib/jvm/java-11-openjdk-arm64' 
ENV JAVA_OPTS='-Xms4000m -Xmx7000m \
              -Dlog4j2.configurationFile=/opt/dhis2/log4j2.xml'
ENV DHIS2_HOME='/home/dhis/config'

# Create DHIS2 home directory
RUN useradd -d /home/dhis -m dhis -s /bin/false
RUN mkdir /home/dhis/config
RUN chown dhis:dhis /home/dhis/config

# Set locale timezone
RUN  dpkg-reconfigure tzdata

# copy dhis2 config
COPY --chmod=600 ./docker/dhis.conf /home/dhis/config/dhis.conf

# install tomcat
RUN apt-get update && apt-get -y install tomcat9-user
RUN cd /home/dhis/ &&\
     tomcat9-instance-create tomcat-dhis &&\
     chown -R dhis:dhis tomcat-dhis/
RUN apt-get update && apt-get -y install wget
RUN wget -O /home/dhis/tomcat-dhis/webapps/ROOT.war \
     https://releases.dhis2.org/40/dhis2-stable-40.3.0.war

RUN /home/dhis/tomcat-dhis/bin/setenv.sh

# Expose the Tomcat port
EXPOSE 8080

# Start Tomcat
CMD  /home/dhis/tomcat-dhis/bin/startup.sh; tail -f /home/dhis/tomcat-dhis/logs/catalina.out

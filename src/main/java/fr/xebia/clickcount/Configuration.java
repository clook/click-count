package fr.xebia.clickcount;

import javax.inject.Singleton;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


@Singleton
public class Configuration {

	private static final Logger log = LoggerFactory.getLogger(Configuration.class);
    public final String redisHost;
    public final int redisPort;
    public final int redisConnectionTimeout;  //milliseconds

    public Configuration() {
		String envHost = System.getenv("HOST_REDIS");
		redisHost = (envHost != null && !envHost.isEmpty())  ? envHost : "redis";
		log.info(">> Redis host: " + redisHost);

		String envPort = System.getenv("PORT_REDIS");
		redisPort = (envPort != null && !envPort.isEmpty())  ? Integer.valueOf(envPort) : 6379;
		log.info(">> Redis port: " + redisPort);

        redisConnectionTimeout = 2000;
    }
}

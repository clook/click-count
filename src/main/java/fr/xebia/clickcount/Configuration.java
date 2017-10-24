package fr.xebia.clickcount;

import javax.inject.Singleton;

@Singleton
public class Configuration {

    public final String redisHost;
    public final int redisPort;
    public final int redisConnectionTimeout;  //milliseconds

    public Configuration() {
		String envHost = System.getenv("HOST_REDIS");
		redisHost = (envHost != null && !envHost.isEmpty())  ? envHost : "redis";
		System.out.println("Redis server: " + redisHost);

		String envPort = System.getenv("PORT_REDIS");
		redisPort = (envPort != null && !envPort.isEmpty())  ? Integer.valueOf(envPort) : 6379;

        redisConnectionTimeout = 2000;
    }
}

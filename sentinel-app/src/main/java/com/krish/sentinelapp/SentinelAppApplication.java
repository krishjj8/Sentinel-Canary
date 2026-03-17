package com.krish.sentinelapp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;

@SpringBootApplication
@ComponentScan(basePackages = "com.krish")
public class SentinelAppApplication {

	public static void main(String[] args) {
		SpringApplication.run(SentinelAppApplication.class, args);
	}

}

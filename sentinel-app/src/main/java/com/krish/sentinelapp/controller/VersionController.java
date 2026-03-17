package  com.krish.sentinelapp.controller;


import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class VersionController {

    @GetMapping("/version")
    public Map<String, String> version() {
        return Map.of(
                "version","v2",
                "status","healthy"

        );
    }
}
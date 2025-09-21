package com.ecommerce;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {
    
    @Autowired
    private UserRepository userRepository;
    
    @PostMapping("/admin-login")
    public ResponseEntity<?> adminLogin(@RequestBody Map<String, String> credentials) {
        String username = credentials.get("username");
        String password = credentials.get("password");
        
        User user = userRepository.findByUsernameAndPassword(username, password);
        if (user != null && ("ADMIN".equals(user.getRole()) || "STAFF".equals(user.getRole()))) {
            return ResponseEntity.ok(Map.of("token", "admin-token-" + user.getId(), "role", user.getRole()));
        }
        return ResponseEntity.badRequest().body(Map.of("error", "Invalid credentials"));
    }
    
    @PostMapping("/customer-login")
    public ResponseEntity<?> customerLogin(@RequestBody Map<String, String> credentials) {
        String mobile = credentials.get("mobile");
        
        User user = userRepository.findByMobile(mobile);
        if (user == null) {
            user = new User(mobile, "", mobile, "CUSTOMER");
            userRepository.save(user);
        }
        return ResponseEntity.ok(Map.of("token", "customer-token-" + user.getId(), "userId", user.getId()));
    }
}
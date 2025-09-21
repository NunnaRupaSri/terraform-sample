package com.ecommerce;

import jakarta.persistence.*;

@Entity
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String username;
    private String password;
    private String mobile;
    private String role; // ADMIN, STAFF, CUSTOMER
    
    // Constructors
    public User() {}
    
    public User(String username, String password, String mobile, String role) {
        this.username = username;
        this.password = password;
        this.mobile = mobile;
        this.role = role;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    
    public String getMobile() { return mobile; }
    public void setMobile(String mobile) { this.mobile = mobile; }
    
    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }
}
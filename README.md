# E-Commerce Application

## Architecture
- **Backend**: Java Spring Boot with H2 Database
- **Frontend**: React.js with React Router

## Features

### Admin Side (5 Users: 1 Admin + 4 Staff)
- Username/Password login
- Product management (CRUD operations)
- Inventory management
- Role-based access (ADMIN/STAFF)

### Customer Side
- Mobile number login (auto-registration)
- Product catalog browsing
- Shopping cart functionality
- Payment processing

## Setup Instructions

### Backend (Java Spring Boot)
```bash
cd ecommerce-backend
mvn spring-boot:run
```
Server runs on: http://localhost:8080

### Frontend (React.js)
```bash
cd ecommerce-frontend
npm install
npm start
```
Client runs on: http://localhost:3000

## Default Admin Users
Create these users in H2 database:
- Admin: username=admin, password=admin123, role=ADMIN
- Staff: username=staff1, password=staff123, role=STAFF
- Staff: username=staff2, password=staff123, role=STAFF
- Staff: username=staff3, password=staff123, role=STAFF
- Staff: username=staff4, password=staff123, role=STAFF

## API Endpoints
- POST /api/auth/admin-login - Admin/Staff login
- POST /api/auth/customer-login - Customer login via mobile
- GET /api/products - Get all products
- POST /api/products - Create product (Admin only)
- PUT /api/products/{id} - Update product (Admin only)
- DELETE /api/products/{id} - Delete product (Admin only)

## Access URLs
- Customer Login: http://localhost:3000/
- Admin Login: http://localhost:3000/admin
- Admin Dashboard: http://localhost:3000/admin-dashboard
- Customer Dashboard: http://localhost:3000/customer-dashboard
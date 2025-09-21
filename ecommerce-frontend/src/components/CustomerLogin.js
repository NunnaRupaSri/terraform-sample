import React, { useState } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';

const CustomerLogin = () => {
  const [mobile, setMobile] = useState('');
  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    try {
      const response = await axios.post('http://localhost:8080/api/auth/customer-login', { mobile });
      localStorage.setItem('customerToken', response.data.token);
      localStorage.setItem('customerId', response.data.userId);
      navigate('/customer-dashboard');
    } catch (error) {
      alert('Login failed');
    }
  };

  return (
    <div className="login-container">
      <h2>Customer Login</h2>
      <form onSubmit={handleLogin}>
        <input
          type="tel"
          placeholder="Mobile Number"
          value={mobile}
          onChange={(e) => setMobile(e.target.value)}
          required
        />
        <button type="submit">Login</button>
      </form>
      <p><a href="/admin">Admin Login</a></p>
    </div>
  );
};

export default CustomerLogin;
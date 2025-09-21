import React, { useState, useEffect } from 'react';
import axios from 'axios';

const CustomerDashboard = () => {
  const [products, setProducts] = useState([]);
  const [cart, setCart] = useState([]);
  const [showCart, setShowCart] = useState(false);

  useEffect(() => {
    fetchProducts();
  }, []);

  const fetchProducts = async () => {
    try {
      const response = await axios.get('http://localhost:8080/api/products');
      setProducts(response.data);
    } catch (error) {
      console.error('Error fetching products:', error);
    }
  };

  const addToCart = (product) => {
    const existingItem = cart.find(item => item.id === product.id);
    if (existingItem) {
      setCart(cart.map(item => 
        item.id === product.id 
          ? {...item, quantity: item.quantity + 1}
          : item
      ));
    } else {
      setCart([...cart, {...product, quantity: 1}]);
    }
  };

  const removeFromCart = (productId) => {
    setCart(cart.filter(item => item.id !== productId));
  };

  const getTotalPrice = () => {
    return cart.reduce((total, item) => total + (item.price * item.quantity), 0).toFixed(2);
  };

  const handlePayment = () => {
    alert(`Payment of $${getTotalPrice()} processed successfully!`);
    setCart([]);
    setShowCart(false);
  };

  return (
    <div className="customer-dashboard">
      <div className="header">
        <h2>E-Commerce Store</h2>
        <button onClick={() => setShowCart(!showCart)}>
          Cart ({cart.length})
        </button>
      </div>

      {showCart && (
        <div className="cart">
          <h3>Shopping Cart</h3>
          {cart.length === 0 ? (
            <p>Cart is empty</p>
          ) : (
            <>
              {cart.map(item => (
                <div key={item.id} className="cart-item">
                  <span>{item.name} x {item.quantity}</span>
                  <span>${(item.price * item.quantity).toFixed(2)}</span>
                  <button onClick={() => removeFromCart(item.id)}>Remove</button>
                </div>
              ))}
              <div className="cart-total">
                <strong>Total: ${getTotalPrice()}</strong>
                <button onClick={handlePayment}>Pay Now</button>
              </div>
            </>
          )}
        </div>
      )}

      <div className="products-grid">
        {products.map(product => (
          <div key={product.id} className="product-card">
            {product.imageUrl && <img src={product.imageUrl} alt={product.name} />}
            <h3>{product.name}</h3>
            <p>{product.description}</p>
            <p className="price">${product.price}</p>
            <p>Stock: {product.stock}</p>
            <button 
              onClick={() => addToCart(product)}
              disabled={product.stock === 0}
            >
              {product.stock === 0 ? 'Out of Stock' : 'Add to Cart'}
            </button>
          </div>
        ))}
      </div>
    </div>
  );
};

export default CustomerDashboard;
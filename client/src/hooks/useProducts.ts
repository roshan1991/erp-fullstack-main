import { useState, useEffect } from 'react';

export interface Product {
    id: number;
    name: string;
    category: string;
    price: number;
    stock: number;
    barcode?: string;
    sku?: string;
    image?: string;
    image_url?: string;
    status: string;
}

export const useProducts = () => {
    const [products, setProducts] = useState<Product[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    const fetchProducts = async () => {
        try {
            setLoading(true);
            const token = localStorage.getItem('access_token');

            if (!token) {
                throw new Error('Not authenticated. Please log in.');
            }

            const response = await fetch(`${import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1'}/products?skip=0&limit=100`, {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });

            if (!response.ok) {
                const errorData = await response.json().catch(() => ({}));
                throw new Error(errorData.detail || `Failed to fetch products (${response.status})`);
            }

            const data = await response.json();
            setProducts(data.products || []);
            setError(null);
        } catch (err: any) {
            setError(err.message);
            console.error('Error fetching products:', err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchProducts();
    }, []);

    const addProduct = async (product: Omit<Product, 'id'>) => {
        try {
            const token = localStorage.getItem('access_token');
            const response = await fetch(`${import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1'}/products`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(product)
            });

            if (!response.ok) throw new Error('Failed to add product');

            const newProduct = await response.json();
            setProducts([...products, newProduct]);
            return newProduct;
        } catch (err: any) {
            setError(err.message);
            throw err;
        }
    };

    const updateProduct = async (id: number, updates: Partial<Product>) => {
        try {
            const token = localStorage.getItem('access_token');
            const response = await fetch(`${import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1'}/products/${id}`, {
                method: 'PUT',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(updates)
            });

            if (!response.ok) throw new Error('Failed to update product');

            const updatedProduct = await response.json();
            setProducts(products.map(p => p.id === id ? updatedProduct : p));
            return updatedProduct;
        } catch (err: any) {
            setError(err.message);
            throw err;
        }
    };

    const deleteProduct = async (id: number) => {
        try {
            const token = localStorage.getItem('access_token');
            const response = await fetch(`${import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1'}/products/${id}`, {
                method: 'DELETE',
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });

            if (!response.ok) throw new Error('Failed to delete product');

            setProducts(products.filter(p => p.id !== id));
        } catch (err: any) {
            setError(err.message);
            throw err;
        }
    };

    return {
        products,
        loading,
        error,
        addProduct,
        updateProduct,
        deleteProduct,
        refreshProducts: fetchProducts
    };
};

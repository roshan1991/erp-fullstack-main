import { useState } from "react";
import { Table, Button, Badge, Form, InputGroup, Spinner, Alert } from "react-bootstrap";
import { Plus, Search, Filter, Edit2, Trash2, RefreshCw } from "lucide-react";
import { GenericModal } from "../../components/common/GenericModal";
import { useProducts, type Product } from "../../hooks/useProducts";
import api from "../../lib/api";
import { useAuth } from "../../context/AuthContext";

export function InventoryList() {
    const { checkPermission } = useAuth();
    const { products, addProduct, updateProduct, deleteProduct, refreshProducts } = useProducts();

    const [showModal, setShowModal] = useState(false);
    const [searchTerm, setSearchTerm] = useState("");
    const [uploading, setUploading] = useState(false);
    const [editingId, setEditingId] = useState<number | null>(null);
    const [syncing, setSyncing] = useState(false);
    const [syncMessage, setSyncMessage] = useState("");
    const [syncError, setSyncError] = useState("");

    // Form State
    const [formData, setFormData] = useState<Omit<Product, "id">>({
        name: "",
        sku: "",
        barcode: "",
        category: "Electronics",
        stock: 0,
        price: 0,
        status: "In Stock",
        image: ""
    });

    const handleSyncFromWooCommerce = async () => {
        try {
            setSyncing(true);
            setSyncMessage("");
            setSyncError("");

            const response = await api.post("/sync/woocommerce-to-inventory");
            setSyncMessage(`Successfully synced! Added: ${response.data.synced}, Updated: ${response.data.updated}, Skipped: ${response.data.skipped}`);

            // Refresh the products list
            await refreshProducts();
        } catch (err: any) {
            setSyncError(err.response?.data?.detail || "Failed to sync products from WooCommerce");
        } finally {
            setSyncing(false);
        }
    };

    const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        setUploading(true);
        const uploadData = new FormData();
        uploadData.append("file", file);

        try {
            const response = await fetch(`${import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1'}/upload/image`, {
                method: "POST",
                body: uploadData,
            });

            if (!response.ok) throw new Error("Upload failed");

            const data = await response.json();
            setFormData({ ...formData, image: data.url });
        } catch (error) {
            console.error("Error uploading image:", error);
            alert("Failed to upload image");
        } finally {
            setUploading(false);
        }
    };

    const handleOpenAdd = () => {
        setEditingId(null);
        setFormData({
            name: "",
            sku: "",
            barcode: "",
            category: "Electronics",
            stock: 0,
            price: 0,
            status: "In Stock",
            image: ""
        });
        setShowModal(true);
    };

    const handleOpenEdit = (product: Product) => {
        setEditingId(product.id);
        setFormData({
            name: product.name,
            sku: product.sku,
            barcode: product.barcode,
            category: product.category,
            stock: product.stock,
            price: product.price,
            status: product.status,
            image: product.image
        });
        setShowModal(true);
    };

    const handleConfirm = () => {
        if (editingId) {
            updateProduct(editingId, formData);
        } else {
            addProduct(formData);
        }
        setShowModal(false);
    };

    const filteredProducts = products.filter(p =>
        p.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        (p.sku?.toLowerCase().includes(searchTerm.toLowerCase()) ?? false) ||
        (p.barcode?.includes(searchTerm) ?? false)
    );

    return (
        <div className="p-4">
            <div className="d-flex justify-content-between align-items-center mb-4">
                <h2>Inventory Management</h2>
                <div className="d-flex gap-2">
                    {checkPermission('inventory', 'create') && ( // Using create/update roughly. Sync is create/update
                        <Button
                            variant="info"
                            onClick={handleSyncFromWooCommerce}
                            disabled={syncing}
                        >
                            <RefreshCw size={18} className="me-2" />
                            {syncing ? "Syncing..." : "Sync from WooCommerce"}
                        </Button>
                    )}
                    {checkPermission('inventory', 'create') && (
                        <Button variant="primary" onClick={handleOpenAdd}>
                            <Plus size={18} className="me-2" />
                            Add Product
                        </Button>
                    )}
                </div>
            </div>

            {syncMessage && <Alert variant="success" dismissible onClose={() => setSyncMessage("")}>{syncMessage}</Alert>}
            {syncError && <Alert variant="danger" dismissible onClose={() => setSyncError("")}>{syncError}</Alert>}

            <div className="mb-4">
                <InputGroup>
                    <InputGroup.Text className="bg-white border-end-0">
                        <Search size={18} className="text-muted" />
                    </InputGroup.Text>
                    <Form.Control
                        placeholder="Search by name, SKU, or barcode..."
                        className="border-start-0 ps-0"
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                    />
                    <Button variant="outline-secondary">
                        <Filter size={18} />
                    </Button>
                </InputGroup>
            </div>

            <div className="bg-white rounded shadow-sm">
                <Table hover responsive className="mb-0 align-middle">
                    <thead className="bg-light">
                        <tr>
                            <th>Image</th>
                            <th>Name</th>
                            <th>SKU</th>
                            <th>Barcode</th>
                            <th>Category</th>
                            <th>Stock</th>
                            <th>Price</th>
                            <th>Status</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredProducts.map((product) => (
                            <tr key={product.id}>
                                <td>
                                    {product.image ? (
                                        <img
                                            src={product.image.startsWith('http') ? product.image : `${import.meta.env.VITE_API_URL || 'http://localhost:8000'}${product.image}`}
                                            alt={product.name}
                                            style={{ width: '40px', height: '40px', objectFit: 'cover' }}
                                            className="rounded"
                                        />
                                    ) : (
                                        <div className="bg-light rounded d-flex align-items-center justify-content-center text-muted" style={{ width: '40px', height: '40px' }}>
                                            <small>No Img</small>
                                        </div>
                                    )}
                                </td>
                                <td className="fw-medium">{product.name}</td>
                                <td className="text-muted small">{product.sku}</td>
                                <td className="text-muted small">{product.barcode || "-"}</td>
                                <td><Badge bg="light" text="dark" className="border">{product.category}</Badge></td>
                                <td>{product.stock}</td>
                                <td>${product.price ? Number(product.price).toFixed(2) : '0.00'}</td>
                                <td>
                                    <Badge bg={
                                        product.status === "In Stock" ? "success" :
                                            product.status === "Low Stock" ? "warning" : "danger"
                                    }>
                                        {product.status}
                                    </Badge>
                                </td>
                                <td>
                                    {checkPermission('inventory', 'update') && (
                                        <Button
                                            variant="link"
                                            className="text-primary p-0 me-2"
                                            onClick={() => handleOpenEdit(product)}
                                        >
                                            <Edit2 size={16} />
                                        </Button>
                                    )}
                                    {checkPermission('inventory', 'delete') && (
                                        <Button
                                            variant="link"
                                            className="text-danger p-0"
                                            onClick={() => deleteProduct(product.id)}
                                        >
                                            <Trash2 size={16} />
                                        </Button>
                                    )}
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </Table>
            </div>

            <GenericModal
                show={showModal}
                onHide={() => setShowModal(false)}
                title={editingId ? "Edit Product" : "Add New Product"}
                onConfirm={handleConfirm}
                confirmText={editingId ? "Save Changes" : "Add Product"}
            >
                <Form>
                    <Form.Group className="mb-3">
                        <Form.Label>Product Name</Form.Label>
                        <Form.Control
                            type="text"
                            placeholder="Enter product name"
                            value={formData.name}
                            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        />
                    </Form.Group>
                    <div className="row">
                        <div className="col-md-6 mb-3">
                            <Form.Label>SKU</Form.Label>
                            <Form.Control
                                type="text"
                                placeholder="E.g., ELEC-001"
                                value={formData.sku}
                                onChange={(e) => setFormData({ ...formData, sku: e.target.value })}
                            />
                        </div>
                        <div className="col-md-6 mb-3">
                            <Form.Label>Barcode</Form.Label>
                            <Form.Control
                                type="text"
                                placeholder="Scan or enter barcode"
                                value={formData.barcode}
                                onChange={(e) => setFormData({ ...formData, barcode: e.target.value })}
                            />
                        </div>
                    </div>
                    <div className="row">
                        <div className="col-md-6 mb-3">
                            <Form.Label>Category</Form.Label>
                            <Form.Select
                                value={formData.category}
                                onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                            >
                                <option>Electronics</option>
                                <option>Furniture</option>
                                <option>Accessories</option>
                                <option>Office Supplies</option>
                            </Form.Select>
                        </div>
                        <div className="col-md-6 mb-3">
                            <Form.Label>Status</Form.Label>
                            <Form.Select
                                value={formData.status}
                                onChange={(e) => setFormData({ ...formData, status: e.target.value })}
                            >
                                <option>In Stock</option>
                                <option>Low Stock</option>
                                <option>Out of Stock</option>
                            </Form.Select>
                        </div>
                    </div>
                    <div className="row">
                        <div className="col-md-6 mb-3">
                            <Form.Label>Stock Quantity</Form.Label>
                            <Form.Control
                                type="number"
                                value={formData.stock}
                                onChange={(e) => setFormData({ ...formData, stock: parseInt(e.target.value) || 0 })}
                            />
                        </div>
                        <div className="col-md-6 mb-3">
                            <Form.Label>Price ($)</Form.Label>
                            <Form.Control
                                type="number"
                                step="0.01"
                                value={formData.price}
                                onChange={(e) => setFormData({ ...formData, price: parseFloat(e.target.value) || 0 })}
                            />
                        </div>
                    </div>
                    <Form.Group className="mb-3">
                        <Form.Label>Product Image</Form.Label>
                        <div className="d-flex gap-2">
                            <Form.Control
                                type="file"
                                accept="image/*"
                                onChange={handleFileUpload}
                            />
                            {uploading && <Spinner animation="border" size="sm" />}
                        </div>
                        {formData.image && (
                            <div className="mt-2">
                                <small className="text-success">Image uploaded successfully</small>
                                <img src={`${import.meta.env.VITE_API_URL || 'http://localhost:8000'}${formData.image}`} alt="Preview" className="d-block mt-1" style={{ height: '50px' }} />
                            </div>
                        )}
                    </Form.Group>
                </Form>
            </GenericModal>
        </div>
    );
}

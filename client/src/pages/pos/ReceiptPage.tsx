import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { Button, Card, Spinner, Alert } from "react-bootstrap";
import { Printer, ArrowLeft } from "lucide-react";
import api from "../../lib/api";

interface OrderItem {
    id: number;
    product_name: string;
    quantity: number;
    unit_price: number;
    subtotal: number;
}

interface Order {
    id: number;
    total_amount: number;
    status: string;
    created_at: string;
    customer?: {
        name: string;
        email?: string;
        phone?: string;
        address?: string;
    };
    items: OrderItem[];
    payments: { method: string; amount: number }[];
}

export function ReceiptPage() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [order, setOrder] = useState<Order | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");

    useEffect(() => {
        fetchOrder();
    }, [id]);

    const fetchOrder = async () => {
        try {
            const response = await api.get(`/pos/orders/${id}`);
            setOrder(response.data);
        } catch (err: any) {
            setError("Failed to load receipt details.");
        } finally {
            setLoading(false);
        }
    };

    const handlePrint = () => {
        window.print();
    };

    if (loading) return <div className="text-center p-5"><Spinner animation="border" /></div>;
    if (error) return <Alert variant="danger" className="m-4">{error}</Alert>;
    if (!order) return <Alert variant="warning" className="m-4">Order not found</Alert>;

    // Custom blue colors from the design
    const themeColor = "#2c5282"; // Deep Blue
    const lightBlue = "#ebf4ff";   // Light Blue for footer

    return (
        <div className="p-4 bg-light min-vh-100 font-sans">
            {/* Action Bar */}
            <div className="d-flex justify-content-between align-items-center mb-4 d-print-none container" style={{ maxWidth: '850px' }}>
                <Button variant="outline-secondary" onClick={() => navigate("/pos")}>
                    <ArrowLeft size={18} className="me-2" /> Back to POS
                </Button>
                <Button variant="primary" onClick={handlePrint} style={{ backgroundColor: themeColor, borderColor: themeColor }}>
                    <Printer size={18} className="me-2" /> Print Invoice
                </Button>
            </div>

            {/* Invoice Card */}
            <Card className="shadow-lg border-0 mx-auto overflow-hidden" style={{ maxWidth: '850px', minHeight: '1000px' }}>
                {/* Top Blue Bar */}
                <div style={{ height: '20px', backgroundColor: themeColor, width: '100%' }}></div>

                <Card.Body className="p-0 d-flex flex-column">
                    <div className="p-5 flex-grow-1">
                        {/* Header */}
                        <div className="d-flex justify-content-between align-items-start mb-5">
                            <div>
                                <h1 className="fw-bold mb-2" style={{ color: themeColor, fontSize: '3rem' }}>Invoice</h1>
                                <div className="text-muted fw-medium">
                                    <p className="mb-0">Invoice N {order.id.toString().padStart(6, '0')}</p>
                                    <p className="mb-0">{new Date(order.created_at).toLocaleDateString()}</p>
                                </div>
                            </div>
                            <div className="text-end">
                                {/* Logo */}
                                <div className="d-flex justify-content-end">
                                    <img src="/vite.svg" alt="Company Logo" style={{ height: '60px' }} />
                                </div>
                            </div>
                        </div>

                        {/* Addresses Row */}
                        <div className="row mb-5 gx-5">
                            {/* Bill From */}
                            <div className="col-6">
                                <div className="py-1 px-3 mb-3 text-white fw-bold" style={{ backgroundColor: themeColor }}>
                                    Bill From
                                </div>
                                <div className="px-2">
                                    <h5 className="fw-bold mb-1" style={{ color: themeColor }}>ERP Solutions</h5>
                                    <p className="mb-0 text-muted">123 Street, City, State</p>
                                    <p className="mb-0 text-muted">23123</p>
                                    <p className="mb-0 text-muted">+00 000 000 000</p>
                                </div>
                            </div>

                            {/* Bill To */}
                            <div className="col-6">
                                <div className="py-1 px-3 mb-3 text-white fw-bold" style={{ backgroundColor: themeColor }}>
                                    Bill To
                                </div>
                                <div className="px-2">
                                    <h5 className="fw-bold mb-1" style={{ color: themeColor }}>{order.customer?.name || "Guest Check"}</h5>
                                    <p className="mb-0 text-muted">{order.customer?.address || "123 Street, City, State"}</p>
                                    <p className="mb-0 text-muted">{order.customer?.phone || "23123"}</p>
                                    <p className="mb-0 text-muted">{order.customer?.email || "+00 000 000 000"}</p>
                                </div>
                            </div>
                        </div>

                        {/* Items Table */}
                        <div className="mb-5">
                            {/* Table Header */}
                            <div className="d-flex text-white fw-bold py-2 px-3 mb-2" style={{ backgroundColor: themeColor }}>
                                <div style={{ flex: 3 }}>Description</div>
                                <div style={{ flex: 1, textAlign: 'center' }}>Rate</div>
                                <div style={{ flex: 1, textAlign: 'center' }}>Qty</div>
                                <div style={{ flex: 1, textAlign: 'right' }}>Total</div>
                            </div>

                            {/* Table Body */}
                            <div className="d-flex flex-column gap-2">
                                {order.items.map((item) => (
                                    <div key={item.id} className="d-flex border-bottom pb-2 px-3 text-muted align-items-center">
                                        <div style={{ flex: 3 }} className="fw-medium text-dark">{item.product_name}</div>
                                        <div style={{ flex: 1, textAlign: 'center' }}>${Number(item.unit_price || 0).toFixed(2)}</div>
                                        <div style={{ flex: 1, textAlign: 'center' }}>{item.quantity}0</div>
                                        <div style={{ flex: 1, textAlign: 'right' }} className="fw-bold text-dark">${Number(item.subtotal || 0).toFixed(2)}</div>
                                    </div>
                                ))}
                                {/* Add some empty rows for visual spacing if needed */}
                                {Array.from({ length: Math.max(0, 5 - order.items.length) }).map((_, i) => (
                                    <div key={`empty-${i}`} className="d-flex border-bottom pb-2 px-3 text-muted" style={{ minHeight: '35px' }}>
                                        <div style={{ flex: 3 }}></div>
                                        <div style={{ flex: 1 }}></div>
                                        <div style={{ flex: 1 }}></div>
                                        <div style={{ flex: 1 }}></div>
                                    </div>
                                ))}
                            </div>
                        </div>

                        {/* Footer Section: Payment & Totals */}
                        <div className="row align-items-end mt-4">
                            {/* Payment Info */}
                            <div className="col-6">
                                <div className="py-1 px-3 mb-3 text-white fw-bold d-inline-block" style={{ backgroundColor: themeColor, minWidth: '150px' }}>
                                    Payment Info
                                </div>
                                <div className="px-2">
                                    <p className="mb-1 text-dark fw-medium">Bank Account</p>
                                    <p className="mb-0 text-muted">ER73829 27382 28338</p>

                                    {/* Actual Payment Methods */}
                                    <div className="mt-3 pt-2 border-top">
                                        {order.payments.map((p, i) => (
                                            <div key={i} className="small text-muted">{p.method}: ${Number(p.amount || 0).toFixed(2)}</div>
                                        ))}
                                    </div>
                                </div>
                            </div>

                            {/* Totals */}
                            <div className="col-6">
                                <div className="px-4">
                                    <div className="d-flex justify-content-between mb-2 fw-medium text-muted">
                                        <span>Subtotal</span>
                                        <span className="text-dark">${Number(order.total_amount || 0).toFixed(2)}</span>
                                    </div>
                                    <div className="d-flex justify-content-between mb-3 fw-medium text-muted">
                                        <span>Tax</span>
                                        <span className="text-dark">$0.00</span>
                                    </div>
                                    <div className="d-flex justify-content-between py-2 px-3 text-white fw-bold align-items-center" style={{ backgroundColor: themeColor }}>
                                        <span className="fs-5">Total</span>
                                        <span className="fs-5">${Number(order.total_amount || 0).toFixed(2)}</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Thank You Footer */}
                    <div className="p-5 mt-auto" style={{ backgroundColor: lightBlue }}>
                        <h3 className="fw-bold mb-3" style={{ color: themeColor }}>Thank you!</h3>
                        <p className="text-muted small mb-0" style={{ maxWidth: '600px', lineHeight: '1.6' }}>
                            Capricornus is one of the and one of the 48 constellations enumerated by Ptolemy.
                            The constellation lies in an area of the sky called Sea or Water, formed by many water-related constellations, such as Aquarius, Pisces, and Eridanus.
                        </p>
                    </div>
                </Card.Body>
            </Card>

            {/* Print Styles Override */}
            <style>
                {`
                    @media print {
                        @page { 
                            margin: 10mm;
                            size: auto;
                        }
                        body {
                            background-color: white !important;
                            -webkit-print-color-adjust: exact !important;
                            print-color-adjust: exact !important;
                        }
                        body * {
                            visibility: hidden;
                        }
                        .card, .card * {
                            visibility: visible;
                        }
                        .card {
                            position: absolute;
                            left: 0;
                            top: 0;
                            width: 100%;
                            min-height: auto !important;
                            margin: 0 !important;
                            padding: 0 !important;
                            box-shadow: none !important;
                            border: none !important;
                            background-color: white !important;
                        }
                        .d-print-none {
                            display: none !important;
                        }
                        /* Ensure text contrasts well on print if needed, though exact should handle it */
                    }
                `}
            </style>
        </div>
    );
}

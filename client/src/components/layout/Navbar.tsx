import { Bell, User, Menu } from "lucide-react";
import { Navbar as BSNavbar, Container, Nav, Dropdown, Button } from "react-bootstrap";
import { useAuth } from "../../context/AuthContext";
import { useNavigate } from "react-router-dom";

interface NavbarProps {
    onToggleSidebar: () => void;
}

export function Navbar({ onToggleSidebar }: NavbarProps) {
    const { user, logout } = useAuth();
    const navigate = useNavigate();

    const handleLogout = () => {
        logout();
        navigate('/login');
    };

    return (
        <BSNavbar bg="white" variant="light" className="border-bottom shadow-sm py-2">
            <Container fluid>
                <div className="d-flex align-items-center gap-3">
                    <Button
                        variant="link"
                        className="p-0 text-dark d-lg-none"
                        onClick={onToggleSidebar}
                    >
                        <Menu size={24} />
                    </Button>
                    <BSNavbar.Brand className="d-none d-md-block m-0">Dashboard</BSNavbar.Brand>
                </div>

                <BSNavbar.Toggle />

                <Nav className="ms-auto align-items-center gap-3 flex-row">
                    <Nav.Link href="#">
                        <Bell size={20} className="text-secondary" />
                    </Nav.Link>
                    <Dropdown align="end">
                        <Dropdown.Toggle variant="link" id="dropdown-user" className="text-decoration-none p-0 d-flex align-items-center">
                            <div className="bg-secondary rounded-circle d-flex align-items-center justify-content-center text-white me-2" style={{ width: 32, height: 32 }}>
                                <User size={16} />
                            </div>
                            <span className="text-dark d-none d-md-inline">{user?.full_name || user?.username || 'User'}</span>
                        </Dropdown.Toggle>

                        <Dropdown.Menu>
                            <Dropdown.Item onClick={() => navigate('/profile')}>Profile</Dropdown.Item>
                            <Dropdown.Item onClick={() => navigate('/settings')}>Settings</Dropdown.Item>
                            <Dropdown.Divider />
                            <Dropdown.Item onClick={handleLogout} className="text-danger">Sign out</Dropdown.Item>
                        </Dropdown.Menu>
                    </Dropdown>
                </Nav>
            </Container>
        </BSNavbar>
    );
}

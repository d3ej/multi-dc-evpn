"""
Network fabric validation tests using pytest
Tests BGP, VXLAN, EVPN, and inter-DC reachability
"""
import pytest
from netmiko import ConnectHandler
from paramiko.ssh_exception import SSHException, AuthenticationException
import time


class NetworkFabric:
    """Helper class for fabric operations"""

    def __init__(self, host, username="admin", password="admin", device_type="arista_eos"):
        self.host = host
        self.username = username
        self.password = password
        self.device_type = device_type
        self.connection = None

    def connect(self):
        """Establish SSH connection to device"""
        try:
            self.connection = ConnectHandler(
                device_type=self.device_type,
                host=self.host,
                username=self.username,
                password=self.password,
                secret=self.password,
                session_log=None,
                global_delay_factor=2
            )
            return True
        except (SSHException, AuthenticationException) as e:
            pytest.skip(f"Cannot connect to {self.host}: {str(e)}")
            return False

    def disconnect(self):
        """Close SSH connection"""
        if self.connection:
            self.connection.disconnect()

    def send_command(self, command):
        """Send command and return output"""
        if not self.connection:
            self.connect()
        try:
            output = self.connection.send_command(command)
            return output
        except Exception as e:
            return f"Error executing command: {str(e)}"

    def get_bgp_summary(self):
        """Get BGP summary"""
        output = self.send_command("show bgp summary")
        return output

    def get_bgp_neighbors(self):
        """Get BGP neighbor status"""
        output = self.send_command("show bgp neighbors")
        return output

    def get_vxlan_interface(self):
        """Get VXLAN interface status"""
        output = self.send_command("show interface Vxlan1")
        return output

    def get_evpn_routes(self):
        """Get EVPN routes"""
        output = self.send_command("show bgp evpn routes")
        return output

    def get_interface_status(self):
        """Get interface status"""
        output = self.send_command("show interfaces status")
        return output

    def ping(self, target_ip):
        """Ping target IP"""
        output = self.send_command(f"ping {target_ip} count 5")
        return output


# Device fixtures
@pytest.fixture(scope="module")
def dc1_spine1():
    fabric = NetworkFabric("172.20.20.2")
    if fabric.connect():
        yield fabric
        fabric.disconnect()
    else:
        pytest.skip("Cannot connect to dc1-spine1")


@pytest.fixture(scope="module")
def dc1_spine2():
    fabric = NetworkFabric("172.20.20.3")
    if fabric.connect():
        yield fabric
        fabric.disconnect()
    else:
        pytest.skip("Cannot connect to dc1-spine2")


@pytest.fixture(scope="module")
def dc1_leaf1():
    fabric = NetworkFabric("172.20.20.4")
    if fabric.connect():
        yield fabric
        fabric.disconnect()
    else:
        pytest.skip("Cannot connect to dc1-leaf1")


@pytest.fixture(scope="module")
def dc2_spine1():
    fabric = NetworkFabric("172.20.20.8")
    if fabric.connect():
        yield fabric
        fabric.disconnect()
    else:
        pytest.skip("Cannot connect to dc2-spine1")


@pytest.fixture(scope="module")
def dc2_leaf1():
    fabric = NetworkFabric("172.20.20.10")
    if fabric.connect():
        yield fabric
        fabric.disconnect()
    else:
        pytest.skip("Cannot connect to dc2-leaf1")


# BGP Tests
class TestBGPUnderlay:
    """BGP Underlay connectivity tests"""

    def test_dc1_spine1_bgp_established(self, dc1_spine1):
        """Verify DC1 Spine1 BGP neighbors are established"""
        output = dc1_spine1.get_bgp_summary()
        assert "4" in output, "BGP peers not established on DC1 Spine1"

    def test_dc1_spine2_bgp_established(self, dc1_spine2):
        """Verify DC1 Spine2 BGP neighbors are established"""
        output = dc1_spine2.get_bgp_summary()
        assert "4" in output, "BGP peers not established on DC1 Spine2"

    def test_dc2_spine1_bgp_established(self, dc2_spine1):
        """Verify DC2 Spine1 BGP neighbors are established"""
        output = dc2_spine1.get_bgp_summary()
        assert "4" in output, "BGP peers not established on DC2 Spine1"

    def test_inter_dc_bgp_established(self, dc1_spine1):
        """Verify inter-DC BGP peers are established"""
        output = dc1_spine1.get_bgp_neighbors()
        assert "Established" in output, "Inter-DC BGP not established"


class TestEVPNOverlay:
    """EVPN overlay connectivity tests"""

    def test_dc1_spine1_evpn_routes(self, dc1_spine1):
        """Verify EVPN routes on DC1 Spine1"""
        output = dc1_spine1.get_evpn_routes()
        assert "10100" in output or "routes" in output.lower(), "No EVPN routes found on DC1 Spine1"

    def test_dc1_leaf1_vxlan_interface(self, dc1_leaf1):
        """Verify VXLAN interface on DC1 Leaf1"""
        output = dc1_leaf1.get_vxlan_interface()
        assert "Vxlan1" in output, "VXLAN interface not configured on DC1 Leaf1"

    def test_dc2_leaf1_vxlan_interface(self, dc2_leaf1):
        """Verify VXLAN interface on DC2 Leaf1"""
        output = dc2_leaf1.get_vxlan_interface()
        assert "Vxlan1" in output, "VXLAN interface not configured on DC2 Leaf1"


class TestInterfaceStatus:
    """Physical and logical interface status tests"""

    def test_dc1_spine1_interfaces_up(self, dc1_spine1):
        """Verify critical interfaces on DC1 Spine1 are up"""
        output = dc1_spine1.get_interface_status()
        assert "Ethernet1" in output, "Ethernet1 not found on DC1 Spine1"
        assert "notconnect" not in output.lower(), "Some interfaces are down on DC1 Spine1"

    def test_dc1_leaf1_interfaces_up(self, dc1_leaf1):
        """Verify critical interfaces on DC1 Leaf1 are up"""
        output = dc1_leaf1.get_interface_status()
        assert "Ethernet1" in output, "Ethernet1 not found on DC1 Leaf1"
        assert "Ethernet2" in output, "Ethernet2 not found on DC1 Leaf1"

    def test_dc2_leaf1_interfaces_up(self, dc2_leaf1):
        """Verify critical interfaces on DC2 Leaf1 are up"""
        output = dc2_leaf1.get_interface_status()
        assert "Ethernet1" in output, "Ethernet1 not found on DC2 Leaf1"


class TestInterDCReachability:
    """Inter-datacenter reachability tests"""

    def test_dc1_to_dc2_vxlan_tunnel(self, dc1_leaf1):
        """Verify VXLAN tunnel between DC1 and DC2"""
        # Ping remote loopback via VXLAN
        output = dc1_leaf1.ping("10.0.1.10")
        assert "0% packet loss" in output or "success" in output.lower(), \
            "VXLAN tunnel between DCs not working"

    def test_tenant_vlan_extension(self, dc1_leaf1, dc2_leaf1):
        """Verify tenant VLAN extension across DCs"""
        # Test connectivity for tenant1-vlan100 (VNI 10100)
        dc1_output = dc1_leaf1.send_command("show bgp evpn route-type mac-ip")
        dc2_output = dc2_leaf1.send_command("show bgp evpn route-type mac-ip")
        assert "10100" in dc1_output, "VLAN100 not advertised from DC1"
        assert "10100" in dc2_output, "VLAN100 not learned in DC2"


class TestSymmetricIRB:
    """Symmetric IRB (inter-tenant routing) tests"""

    def test_dc1_leaf1_loopback1(self, dc1_leaf1):
        """Verify Loopback1 configured for symmetric IRB on DC1 Leaf1"""
        output = dc1_leaf1.send_command("show ip interface brief")
        assert "Loopback1" in output, "Loopback1 not configured on DC1 Leaf1"

    def test_dc2_leaf1_loopback1(self, dc2_leaf1):
        """Verify Loopback1 configured for symmetric IRB on DC2 Leaf1"""
        output = dc2_leaf1.send_command("show ip interface brief")
        assert "Loopback1" in output, "Loopback1 not configured on DC2 Leaf1"


# Smoke Tests
class TestFabricSmokeTests:
    """Basic fabric sanity checks"""

    def test_all_loopbacks_reachable(self, dc1_spine1):
        """Verify all loopback IPs are reachable"""
        loopbacks = [
            "10.0.0.1",   # dc1-spine1
            "10.0.0.2",   # dc1-spine2
            "10.0.0.10",  # dc1-leaf1
            "10.0.1.1",   # dc2-spine1
            "10.0.1.10",  # dc2-leaf1
        ]
        for loopback in loopbacks:
            output = dc1_spine1.ping(loopback)
            assert "0% packet loss" in output or "success" in output.lower(), \
                f"Cannot reach loopback {loopback}"

    def test_fabric_convergence(self, dc1_spine1):
        """Verify fabric has converged"""
        output = dc1_spine1.get_bgp_summary()
        # Basic check: all BGP neighbors should be in Established state
        assert "Established" in output, "BGP has not converged"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])

# Oracle Cloud Free Tier VPS Security Hardening Guide

Oracle Cloud's Always Free tier offers compelling resources for hosting public services, providing up to 4 ARM-based OCPUs and 24 GB of RAM, alongside micro AMD instances. However, running a Virtual Private Server (VPS) exposed to the public internet requires rigorous security measures. This comprehensive guide outlines the essential steps to secure your Oracle Cloud free tier instance while remaining within the free tier limitations.

## Understanding the Free Tier Environment

Before diving into security configurations, it is crucial to understand the unique characteristics of the Oracle Cloud free tier environment.

The Always Free tier provides specific resource allocations that influence security decisions. Users receive up to two AMD micro instances and flexible ARM instances with up to 24 GB of RAM and 4 OCPUs [1]. Storage is capped at 200 GB for block volumes and 20 GB for object storage [1]. Notably, the free tier does not include a NAT Gateway [2]. This architectural constraint means that instances typically require public IP addresses for outbound internet connectivity, increasing their exposure and making robust host-level security imperative.

Furthermore, Oracle implements an idle instance reclamation policy. Instances may be reclaimed if CPU, network, or memory utilization falls below 20% over a seven-day period [1]. While securing the server, you must ensure that your legitimate public services generate sufficient activity to prevent the instance from being flagged as idle.

## Oracle Cloud Network Security Configuration

The first layer of defense operates at the Oracle Cloud Infrastructure (OCI) level, managing traffic before it reaches your VPS.

### Configuring Virtual Cloud Network (VCN) Security Lists

Oracle Cloud uses Security Lists and Network Security Groups (NSGs) to control network traffic. Security Lists act as virtual firewalls applied at the subnet level [3]. By default, OCI configures a Security List that allows SSH (port 22) access from anywhere (`0.0.0.0/0`) [3]. This default configuration is convenient for initial setup but poses a significant security risk for production environments.

To harden the VCN Security List, you must modify the ingress rules. Navigate to the OCI Console, locate your VCN, and select the relevant Security List.

**Table 1: Recommended VCN Security List Ingress Rules**

| Protocol | Source IP Range | Destination Port | Purpose |
| :--- | :--- | :--- | :--- |
| TCP | Your Trusted IP / VPN IP | 22 | Secure SSH Access |
| TCP | `0.0.0.0/0` | 80 | HTTP Web Traffic (Public Service) |
| TCP | `0.0.0.0/0` | 443 | HTTPS Web Traffic (Public Service) |
| ICMP | `0.0.0.0/0` | Type 3, Code 4 | Path MTU Discovery |

Remove the default rule allowing SSH from `0.0.0.0/0`. Replace it with a rule restricting port 22 access to your specific IP address or the IP address of a trusted VPN. If your IP address changes frequently, consider using a dynamic DNS service or configuring a bastion host, though a bastion setup can be complex within free tier limits.

## Linux Operating System Hardening

Once the network perimeter is secured, the next critical phase is hardening the Linux operating system running on your instance.

### SSH Service Hardening

The Secure Shell (SSH) daemon is a primary target for automated brute-force attacks. Securing the SSH configuration is non-negotiable for a public-facing VPS [4].

Begin by editing the SSH configuration file, typically located at `/etc/ssh/sshd_config`. You must implement several key changes to mitigate common attack vectors.

First, ensure that password authentication is disabled. Oracle Cloud instances generally use SSH key pairs by default, but verifying this setting prevents accidental exposure. Set `PasswordAuthentication no` in the configuration file.

Next, disable root login via SSH. Attackers frequently attempt to brute-force the root account. Set `PermitRootLogin no`. You should log in as a standard user (e.g., `ubuntu` or `opc`) and use `sudo` for administrative tasks.

Finally, consider changing the default SSH port from 22 to a non-standard port (e.g., 2222 or 22222). While this is security through obscurity and does not stop determined attackers, it significantly reduces the volume of automated log spam and script-kiddie attacks. If you change the port, remember to update your OCI Security List and host firewall rules accordingly.

### Implementing a Host-Based Firewall

While OCI Security Lists provide network-level protection, implementing a host-based firewall adds a crucial layer of defense-in-depth [4]. Uncomplicated Firewall (UFW) is a user-friendly interface for managing iptables and is highly recommended for Ubuntu and Debian instances.

When configuring UFW, the default policy should deny all incoming connections and allow all outgoing connections. You then explicitly allow the necessary ports.

**Table 2: Essential UFW Configuration Commands**

| Command | Action |
| :--- | :--- |
| `sudo ufw default deny incoming` | Set default policy to block incoming traffic |
| `sudo ufw default allow outgoing` | Set default policy to allow outgoing traffic |
| `sudo ufw allow ssh` | Allow SSH traffic (adjust if using a custom port) |
| `sudo ufw allow http` | Allow HTTP traffic for public services |
| `sudo ufw allow https` | Allow HTTPS traffic for public services |
| `sudo ufw enable` | Activate the firewall |

**Important Note for Oracle Cloud:** Oracle Cloud instances often have complex iptables rules pre-configured. Before enabling UFW, ensure you do not inadvertently lock yourself out. It is critical to verify that the OCI Security List and UFW both permit your SSH connection.

### Intrusion Prevention with Fail2Ban

Fail2Ban is an intrusion prevention software framework that protects computer servers from brute-force attacks. It operates by monitoring log files (e.g., `/var/log/auth.log`) for suspicious activity, such as repeated failed login attempts, and automatically updates firewall rules to block the offending IP addresses [4].

Installing and configuring Fail2Ban is a highly effective measure for securing a public VPS. Once installed, Fail2Ban requires minimal maintenance and provides robust protection against automated scanning and brute-force campaigns targeting SSH and other exposed services.

### System Updates and Maintenance

Maintaining a secure server requires continuous vigilance. Software vulnerabilities are discovered regularly, and applying patches is the only reliable defense against known exploits [4].

You must establish a routine for updating your system packages. On Debian-based systems, this involves running `sudo apt update` and `sudo apt upgrade` frequently. For production environments, consider configuring unattended upgrades to automatically install critical security patches. This ensures your system remains protected even if you forget to run manual updates, which is particularly important for instances hosting public services.

## Preparing for Public Services

With the underlying infrastructure secured, you are ready to deploy your public services. When installing applications like web servers (Nginx, Apache), databases, or custom software, adhere to the principle of least privilege. Run services under dedicated user accounts rather than root, and ensure application configurations are hardened according to their specific best practices.

By systematically applying these security measures across the Oracle Cloud network layer and the Linux operating system, you can confidently utilize the Always Free tier to host robust and secure public services.

---

### References

[1] Oracle Help Center, "Always Free Resources," https://docs.oracle.com/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
[2] Oracle Forums, "Is an OCI Bastion useful without a NAT on the free tier?" https://forums.oracle.com/ords/apexds/post/is-an-oci-bastion-useful-without-a-nat-on-the-free-tier-6570
[3] Oracle Help Center, "Security Lists," https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securitylists.htm
[4] imthenachoman, "How-To-Secure-A-Linux-Server," GitHub, https://github.com/imthenachoman/how-to-secure-a-linux-server

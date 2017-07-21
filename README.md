# Plex Nginx Reverse Proxy
 
This configuration will allow you to serve Plex via Nginx.
Rediesigned to support multiple plex servers behind a single nginx gateway
 
## Minimal Requirements
 
Nginx
 
Plex:
* Remote Access - Disable
* Network - Custom server access URLs = `https://<your-domain>:443,http://<your-domain>:80`
* Network - Secure connections = Preferred.
* (Please note you can force ssl by setting required and not adding the http url, however some players which do not support https will no longer function).
 
## Optional Requirements
 
UFW or other firewall:
* Deny port 32400 externally (Plex still pings over 32400, some clients may use 32400 by mistake despite 443 and 80 being set).
 
CloudFlare:
* SSL set to at least Full.
* Firewall disabled if an abnormal amount of load is expected.

## Added features

* Multiple plex server configs
* Multple PlexPy config with Proxy_Redirect (may not be required, but needed on my setup)
* Ombi Request config
* Certbot path exemption (for letsencrypt certificate)

## To be added

* Smart TV Fix (if there is one)
* Chrome Pause fix

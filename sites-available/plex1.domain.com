#Config for server 1
#domain: plex.DOMAIN.COM  #Replace DOMAIN.com with your domain

server {
	listen 127.0.0.1:80;
	listen 127.0.0.1:443 ssl http2; #http2 can provide a substantial improvement for streaming: https://blog.cloudflare.com/introducing-http2/
	server_name plex.DOMAIN.COM;	#Replace DOMAIN.com with your domain

	#Faster resolving, improves stapling time. Timeout and nameservers may need to be adjusted for your location Google's have been used here.
	resolver 8.8.4.4 8.8.8.8 valid=300s;
	resolver_timeout 10s;
	
	ssl_session_cache shared:SSL:10m;
	ssl_session_timeout 10m;

	#Use letsencrypt.org to get a free and trusted ssl certificate
	ssl_certificate /etc/letsencrypt/live/plex.DOMAIN.COM/fullchain.pem;	#Replace DOMAIN.com with your domain
	ssl_certificate_key /etc/letsencrypt/live/plex.DOMAIN.COM/privkey.pem;	#Replace DOMAIN.com with your domain

	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_prefer_server_ciphers on;
	#Intentionally not hardened for security for player support and encryption video streams has a lot of overhead with something like AES-256-GCM-SHA384.
	ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:ECDHE-RSA-DES-CBC3-SHA:ECDHE-ECDSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';

	#Why this is important: https://blog.cloudflare.com/ocsp-stapling-how-cloudflare-just-made-ssl-30/
	ssl_stapling on;
	ssl_stapling_verify on;
	#For letsencrypt.org you can get your chain like this: https://esham.io/2016/01/ocsp-stapling
	ssl_trusted_certificate /etc/letsencrypt/live/plex.DOMAIN.COM/chain.pem;	#Replace DOMAIN.com with your domain

	#Reuse ssl sessions, avoids unnecessary handshakes
	#Turning this on will increase performance, but at the cost of security. Read below before making a choice.
	#https://github.com/mozilla/server-side-tls/issues/135
	#https://wiki.mozilla.org/Security/Server_Side_TLS#TLS_tickets_.28RFC_5077.29
	#ssl_session_tickets on;
	ssl_session_tickets off;

	#Use: openssl dhparam -out dhparam.pem 2048 - 4096 is better but for overhead reasons 2048 is enough for Plex.
	ssl_dhparam /etc/nginx/ssl/dhparam.pem;		#Change if needed to your path
	ssl_ecdh_curve secp384r1;

	#Will ensure https is always used by supported browsers which prevents any server-side http > https redirects, as the browser will internally correct any request to https.
	#Recommended to submit to your domain to https://hstspreload.org as well.
	#!WARNING! Only enable this if you intend to only serve Plex over https, until this rule expires in your browser it WONT BE POSSIBLE to access Plex via http, remove 'includeSubDomains;' if you only want it to effect your Plex (sub-)domain.
	#This is disabled by default as it could cause issues with some playback devices it's advisable to test it with a small max-age and only enable if you don't encounter issues. (Haven't encountered any yet)
	#add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

	#Plex has A LOT of javascript, xml and html. This helps a lot, but if it causes playback issues with devices turn it off. (Haven't encountered any yet)
	gzip on;
	gzip_vary on;
	gzip_min_length 1000;
	gzip_proxied any;
	gzip_types text/plain text/css text/xml application/xml text/javascript application/x-javascript image/svg+xml;
	gzip_disable "MSIE [1-6]\.";

	#Nginx default client_max_body_size is 1MB, which breaks Camera Upload feature from the phones.
	#Increasing the limit fixes the issue. Anyhow, if 4K videos are expected to be uploaded, the size might need to be increased even more
	client_max_body_size 100M;

	#Forward real ip and host to Plex
	proxy_set_header Host $host;
	proxy_set_header X-Real-IP $remote_addr;
	proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	proxy_set_header X-Forwarded-Proto $scheme;

	#Websockets
	proxy_http_version 1.1;
	proxy_set_header Upgrade $http_upgrade;
	proxy_set_header Connection "upgrade";

	#Buffering off send to the client as soon as the data is received from Plex.
	proxy_redirect off;
	proxy_buffering off;


        location ^~ /.well-known {
                alias /usr/share/nginx/html/.well-known;
        }

        location / {
                proxy_pass http://plex_backend1;
        }

        #PlexPy forward for server 1
        location /plexpya {
                proxy_pass http://127.0.0.2:8183;		# Update with your plexpy server IP and port
                proxy_redirect http://127.0.0.2:8183 https://plex.DOMAIN.COM/plexpya/;		# Update with your plexpy server IP and port, and replace DOMAIN.COm
        }
        #PlexPy forward for server 2
        location /plexpyb {
        proxy_pass http://127.0.0.3:8181;				# Update with your plexpy server IP and port
        proxy_redirect http://127.0.0.3:8181 https://plex.DOMAIN.COM/plexpyb/;	# Update with your plexpy server IP and port, and replace DOMAIN.COM
        }
        #PlexRequests forward for Ombi
        location /request {
                proxy_pass http://127.0.0.4:3000;		# Update with your Ombi server IP and port
                proxy_redirect http://127.0.0.4:3000 https://plex.DOMAIN.COM/request/;	# Update with your Ombi server IP and port, and replace DOMAIN.com. NOTE: /requests is reserved by Ombi
        }

}

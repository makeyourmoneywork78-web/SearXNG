# SearXNG search backend for epfo_smart_discovery.
#
# Build:   docker build -t epfo-searxng deploy/searxng
# Run:     docker run -p 8080:8080 epfo-searxng      # then GET http://localhost:8080/search?q=test&format=json
# Deploy:  point a Render "Web Service" at this Dockerfile (see README.md).
#
# The main app connects by setting SEARXNG_BASE_URL to this service's URL.
FROM searxng/searxng:latest

# Granian (the image's server) defaults its bind host to loopback; force all
# IPv4 interfaces so the platform load balancer can reach the container.
ENV GRANIAN_HOST=0.0.0.0

# Ship our config next to the image (a non-volume path so it always persists);
# render-entrypoint.sh installs it into the /etc/searxng volume at startup.
COPY --chown=977:977 settings.yml /usr/local/searxng/app-settings.yml
COPY --chown=977:977 --chmod=0755 render-entrypoint.sh /usr/local/searxng/render-entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/usr/local/searxng/render-entrypoint.sh"]

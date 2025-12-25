# Dockerfile for custom phpLDAPadmin with custom templates
FROM osixia/phpldapadmin:0.9.0

# Copy custom templates into the image
COPY templates/creation/*.xml /usr/share/phpldapadmin/templates/creation/

# Optionally set permissions (if needed)
RUN chown www-data:www-data /usr/share/phpldapadmin/templates/creation/*.xml

# No entrypoint override needed; base image handles startup

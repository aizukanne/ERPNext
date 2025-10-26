# Dockerfile for ERPNext with All Apps
# Based on official frappe/erpnext image

FROM frappe/erpnext:v15.75.1

USER frappe
WORKDIR /home/frappe/frappe-bench

# Install all Frappe apps
# Using specific versions for stability

# HRMS - Human Resources Management
RUN bench get-app --branch version-15 --skip-assets hrms https://github.com/frappe/hrms

# CRM - Customer Relationship Management  
RUN bench get-app --branch main --skip-assets crm https://github.com/frappe/crm

# Helpdesk - Support ticket system
RUN bench get-app --branch main --skip-assets helpdesk https://github.com/frappe/helpdesk

# Insights - Business Intelligence & Analytics
RUN bench get-app --branch main --skip-assets insights https://github.com/frappe/insights

# Gameplan - Project Management
RUN bench get-app --branch main --skip-assets gameplan https://github.com/frappe/gameplan

# LMS - Learning Management System
RUN bench get-app --branch main --skip-assets lms https://github.com/frappe/lms

# Healthcare - Medical Practice Management
RUN bench get-app --branch version-15 --skip-assets healthcare https://github.com/frappe/healthcare

# Lending - Loan Management
RUN bench get-app --branch version-15 --skip-assets lending https://github.com/frappe/lending

# Create dummy config file for HRMS build (it needs socketio_port from this file)
RUN mkdir -p sites && echo '{"socketio_port": 9000}' > sites/common_site_config.json

# Build assets in stages to reduce memory usage
# Stage 1: Core apps (frappe + erpnext)
RUN bench build --apps frappe,erpnext

# Stage 2: HR & Business apps
RUN bench build --apps hrms,crm,helpdesk

# Stage 3: Analytics & Project Management
RUN bench build --apps insights,gameplan

# Stage 4: Education & Domain-specific
RUN bench build --apps lms,healthcare,lending

# Remove dummy config file (will be created properly at runtime)
RUN rm -f sites/common_site_config.json

# Set proper permissions
USER root
RUN chown -R frappe:frappe /home/frappe/frappe-bench
USER frappe

# Labels for documentation
LABEL maintainer="your-name@example.com"
LABEL description="ERPNext with HRMS, CRM, Helpdesk, Insights, Gameplan, LMS, Healthcare, and Lending"
LABEL version="15.75.1-full"

# Default command (inherited from base image)
# Can be overridden by Nomad job configuration

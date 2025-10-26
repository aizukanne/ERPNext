# Dockerfile for ERPNext with All Apps
# Based on official frappe/erpnext image

FROM frappe/erpnext:v15.75.1

USER frappe
WORKDIR /home/frappe/frappe-bench

# Install all Frappe apps
# Using specific versions for stability

# HRMS - Human Resources Management
RUN bench get-app --branch version-15 hrms https://github.com/frappe/hrms

# CRM - Customer Relationship Management  
RUN bench get-app --branch version-15 crm https://github.com/frappe/crm

# Helpdesk - Support ticket system
RUN bench get-app --branch main helpdesk https://github.com/frappe/helpdesk

# Insights - Business Intelligence & Analytics
RUN bench get-app --branch main insights https://github.com/frappe/insights

# Gameplan - Project Management
RUN bench get-app --branch main gameplan https://github.com/frappe/gameplan

# LMS - Learning Management System
RUN bench get-app --branch main lms https://github.com/frappe/lms

# Healthcare - Medical Practice Management
RUN bench get-app --branch version-15 healthcare https://github.com/frappe/healthcare

# Lending - Loan Management
RUN bench get-app --branch version-15 lending https://github.com/frappe/lending

# Build assets for all apps (this takes time!)
RUN bench build --apps frappe,erpnext,hrms,crm,helpdesk,insights,gameplan,lms,healthcare,lending

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

# CDC API Service - PlantUML Diagram Documentation

This directory contains comprehensive PlantUML diagrams that illustrate the CDC API service architecture, data flows, and components from high-level to low-level perspectives.

## Diagram Overview

### 1. High-Level Architecture (`01-high-level-architecture.puml`)
- **Purpose**: Shows the overall CDC ecosystem and service interactions
- **Audience**: Stakeholders, architects, product managers
- **Key Elements**: 
  - Main services (CDC API, Flow API, Status Service)
  - External systems (NIOS, Splunk, SIEM)
  - Data flow directions
  - Service boundaries

### 2. Component Architecture (`02-component-architecture.puml`)
- **Purpose**: Detailed internal components of the CDC API service
- **Audience**: Developers, technical architects
- **Key Elements**:
  - Service components (gRPC server, HTTP gateway, business logic)
  - Data layer (database tables)
  - External clients
  - Internal relationships

### 3. Data Flow Sequence (`03-data-flow-sequence.puml`)
- **Purpose**: End-to-end sequence of API operations
- **Audience**: Developers, QA engineers
- **Key Elements**:
  - Configuration creation flow
  - Configuration retrieval flow
  - Status update flow
  - Error scenarios

### 4. Database Schema (`04-database-schema.puml`)
- **Purpose**: Database design and relationships
- **Audience**: Database administrators, developers
- **Key Elements**:
  - Table structures
  - Relationships and constraints
  - Triggers and indexes
  - Data types and purposes

### 5. Container Data Flow (`05-container-data-flow.puml`)
- **Purpose**: Data processing flow through CDC containers
- **Audience**: Operations teams, data engineers
- **Key Elements**:
  - Input containers (dns_in, rpz_in, etc.)
  - Processing (Flume)
  - Output containers (siem_out, splunk_out, etc.)
  - Data transformation paths

### 6. PubSub Event Flow (`06-pubsub-event-flow.puml`)
- **Purpose**: Event-driven flow orchestration
- **Audience**: Developers, system architects
- **Key Elements**:
  - Flow event processing
  - Container orchestration
  - Error handling
  - Status updates

### 7. Template System (`07-template-system.puml`)
- **Purpose**: Configuration template generation system
- **Audience**: Developers, configuration managers
- **Key Elements**:
  - Template files for each container type
  - Data sources for template generation
  - Template engine functionality
  - Configuration generation process

### 8. Deployment Architecture (`08-deployment-architecture.puml`)
- **Purpose**: Production deployment and runtime environment
- **Audience**: DevOps engineers, infrastructure teams
- **Key Elements**:
  - Kubernetes deployment
  - Service dependencies
  - Network connections
  - Monitoring setup

### 9. API Specifications (`09-api-specifications.puml`)
- **Purpose**: REST API endpoint documentation
- **Audience**: API consumers, frontend developers
- **Key Elements**:
  - API endpoints and methods
  - Request/response formats
  - Status codes
  - Container types

### 10. Error Handling and Monitoring (`10-error-handling-monitoring.puml`)
- **Purpose**: System resilience, monitoring, and observability
- **Audience**: SRE teams, operations
- **Key Elements**:
  - Error handling strategies
  - Monitoring and metrics
  - Security measures
  - Performance optimization

## How to Use These Diagrams

### Viewing the Diagrams
1. **Online**: Use [PlantUML Online Server](http://www.plantuml.com/plantuml/)
2. **VS Code**: Install PlantUML extension
3. **Local**: Install PlantUML locally with Java

### Understanding the CDC API Service
1. Start with **High-Level Architecture** for overall understanding
2. Review **Component Architecture** for internal structure
3. Follow **Data Flow Sequence** for operational understanding
4. Examine **Database Schema** for data persistence
5. Study **Container Data Flow** for data processing
6. Understand **PubSub Event Flow** for event handling
7. Review **Template System** for configuration management
8. Check **Deployment Architecture** for production setup
9. Reference **API Specifications** for integration
10. Review **Error Handling** for operational resilience

### For Different Roles

**Developers**:
- Focus on diagrams 2, 3, 6, 7, 9
- Understand component interactions and API contracts

**Operations Teams**:
- Focus on diagrams 5, 8, 10
- Understand deployment, monitoring, and data flows

**Architects**:
- Review all diagrams
- Focus on 1, 2, 8 for architectural decisions

**QA Engineers**:
- Focus on diagrams 3, 9
- Understand API flows and error scenarios

## CDC API Service Summary

The CDC API service is a central component in the CDC (Cyber Data Collection) ecosystem that:

1. **Manages Configurations**: Stores and serves configuration templates for various CDC containers
2. **Orchestrates Flows**: Coordinates data flow configurations based on CDC Flow API definitions
3. **Handles Templates**: Generates container-specific configurations from templates
4. **Monitors Status**: Tracks deployment status and container health
5. **Processes Events**: Responds to flow changes via PubSub messaging
6. **Supports Multiple Containers**: Handles input (DNS, RPZ, gRPC, IP metadata), output (SIEM, Splunk, reporting), and processing (Flume) containers

The service acts as the configuration management hub for the entire CDC data processing pipeline, ensuring that on-premise containers are properly configured to collect, process, and export network security data to various destination systems.

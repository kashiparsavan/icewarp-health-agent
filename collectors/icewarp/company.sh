#!/bin/bash

# Checklist "General Information -> Company name" is not stored inside
# IceWarp itself; it identifies *the customer this server belongs to*, so it
# must be set manually per install via COMPANY_NAME in config/agent.conf.
# agent_init() already copies it into DATA, this collector just guarantees
# the key always exists (even empty) so it's never missing from the report.

collector_run() {

    collector_set "general.company" "${COMPANY_NAME:-}"

}

###############################################################################
#
# Windows IceWarp Health Agent - Example Configuration
#
# Copy this file to agent.local.psd1 and edit the site-specific values.
# agent.local.psd1 is ignored by Git.
#
# Paths may be absolute or relative to the windows/ directory.
#
###############################################################################

@{
    # IceWarp installation and command-line tool.
    IceWarpHome        = 'C:\Program Files\IceWarp'
    ToolPath           = 'C:\Program Files\IceWarp\tool.exe'
    ToolTimeoutSeconds = 10

    # Agent output. Both are relative to windows/ by default.
    OutputJson         = 'output\health.json'
    LogDirectory       = 'logs'

    # Report identity. The technician can also be overridden with -Technician.
    CompanyName        = ''
    Technician         = 'Parsavan'
    ChecklistVersion   = '1.14'

    # Optional DNS inputs for future mail/DNS collectors.
    MailHostname       = ''
    MailDomain         = ''
}

DeepSee Audit
==============

Installation
-----------

1. Download Installer.xml (from /_CLS/DeepSeeAudit/ folder in repository) into Caché Studio (any namespace)
2. Run in terminal (any namespace) under user with %All role: 

        set pVars("Namespace")="{Namespace}"
        do ##class(DeepSeeAudit.Installer).setup(.pVars)
  
      {Namespace} is a namespace you want to install to (by default {Namespace}="dsaudit"). If it does not exist it would be created automatically. Important: corresponding database for {Namespace} must be in "mgr/{Namespace}". 

Installer would create (if needed) Namespace and corresponding database, download source code from GitHub and compile it, build cube, enable audit, set new parameters (DSTIME, DSINTERVAL) in %SYS.Audit and create required web application if one does not exist. Moreover Installer would create new task for automatic synchronization of cube with database. By default synch task would run every 60 minutes (you always can change period in [Home] > [Task Manager] > [Task Schedule]).

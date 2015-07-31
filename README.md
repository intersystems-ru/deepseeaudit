Cache-MDX2JSON
==============

RESTful web api for MDX2JSON transformation (also JSONP and XML/A). Also supports requests about Dashboards and Widgets. Supports Caché 2014.1+.

Installation
-----------

1. Download Installer.xml (from /_CLS/habra/ folder in repository) into Caché Studio (any namespace)
2. Run in terminal (any namespace) under user with %All role: 

        set pVars("Namespace")="{Namespace}"
        set pVars("RealTimeSync")=1
        do ##class(DeepSeeAudit.Installer).setup(.pVars)
  
      {Namespace} is a namespace you want to install to. If it does not exist it would be created automatically. 
      You should although define {RealTimeSync} if you want to set automatic synchronization of cube with database.

Installer would create (if needed) Namespace and corresponding database, download source code from GitHub and compile it, build cube, enable audit and create required web application if one does not exist.
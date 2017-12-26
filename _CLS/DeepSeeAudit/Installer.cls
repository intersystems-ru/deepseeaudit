Class DeepSeeAudit.Installer Extends %XML.Adaptor
{

XData Install [ XMLNamespace = INSTALLER ]
{
<Manifest>

<IfNotDef Var="Namespace">
<Var Name="Namespace" Value="dsaudit"/>
<Log Text="Set namespace to ${Namespace}" Level="0"/>
</IfNotDef>

<If Condition='(##class(Config.Namespaces).Exists("${Namespace}")=0)'>
<Log Text="Creating namespace ${Namespace}" Level="0"/>
<Namespace Name="${Namespace}" Create="yes" Code="${Namespace}" Ensemble="" Data="${Namespace}">
<Configuration>
<Database Name="${Namespace}" Dir="${MGRDIR}/${Namespace}" Create="yes" MountRequired="true" Resource="%DB_${Namespace}" PublicPermissions="RW" MountAtStartup="true"/>
</Configuration>
</Namespace>
<Log Text="...Ready!" Level="0"/>
</If>

<Namespace Name="${Namespace}" Create="no">
<Log Text="Mapping globals and packages" Level="0"/>
<Configuration>
<Database Name="${Namespace}" Dir="${MGRDIR}/${Namespace}" Create="no"/>
<GlobalMapping Global="CacheAuditD" From="CACHEAUDIT"/> 
<ClassMapping Package="Security.Datatype" From="CACHESYS"/>
</Configuration>
<Log Text="...Ready!" Level="0"/>

<Log Text="Copying classes" Level="0"/>
<RunInstall Class="DeepSeeAudit.Installer" Method="CopyClasses"/>
<Log Text="...Ready!" Level="0"/>

<Log Text="Copying dashboards and pivots" Level="0"/>
<RunInstall Class="DeepSeeAudit.Installer" Method="CopyDFI"/>
<Log Text="...Ready!" Level="0"/>

<Log Text="Prepare web application, enable audit" Level="0"/>
<RunInstall Class="DeepSeeAudit.Installer" Method="PrepareCSP"/>
<Log Text="...Ready!" Level="0"/>

<Log Text="Download and build cube" Level="0"/>
<RunInstall Class="DeepSeeAudit.Installer" Method="BuildCube"/>
<Log Text="...Ready!" Level="0"/>

<Log Text="Turning on real time synchronization" Level="0"/>
<RunInstall Class="DeepSeeAudit.Installer" Method="TurnSync"/>
<Log Text="...Ready!" Level="0"/>
</Namespace>

</Manifest>
}

ClassMethod setup(ByRef pVars, pLogLevel As %Integer = 0, pInstaller As %Installer.Installer) As %Status [ CodeMode = objectgenerator, Internal ]
{
 	quit ##class(%Installer.Manifest).%Generate(%compiledclass, %code, "Install")
}

ClassMethod TurnSync(pVars, pLogLevel, tInstaller) As %Status
{
	set namespace = tInstaller.Evaluate("${Namespace}")
	do tInstaller.PushNS(namespace)
	set className = "%SYS.Audit"
	
	set st = ..SetParameterValue(className, "DSTIME", "AUTO")
	set st2 = ..SetParameterValue(className, "DSINTERVAL", "5")
		
	set status = $$$ADDSC(st, st2)
	if $$$ISERR(status) throw ##class(%Installer.Exception).CreateFromStatus(status)
		
	set st = $system.OBJ.CompileList(className _ ".cls")
	set st2 = ##class(%DeepSee.CubeManager.Task.Synch).Schedule() //Run every 60 minutes
	
	set status = $$$ADDSC(st, st2)
	if $$$ISERR(status) throw ##class(%Installer.Exception).CreateFromStatus(status)
	
	do tInstaller.PopNS()
	return $$$OK
}

/// <b>ClassName</b> - Class where parameter should be changed.<br>
/// <b>ParameterName</b> - Name of that parameter.<br>
/// <b>ParameterValue</b> - New value of parameter.
ClassMethod SetParameterValue(ClassName As %String, ParameterName As %String, ParameterValue As %String) As %Status
{
	if (##class(%Dictionary.ParameterDefinition).%ExistsId(ClassName _ "||" _ ParameterName) = 1) {
		set pDef = ##class(%Dictionary.ParameterDefinition).%OpenId(ClassName _ "||" _ ParameterName)
	} else {
		set pDef = ##class(%Dictionary.ParameterDefinition).%New(ClassName _ ":" _ ParameterName)
	}
		
	set pDef.Default = ParameterValue
	set status = pDef.%Save()
	return status
}

ClassMethod PrepareCSP(pVars, pLogLevel, tInstaller) As %Status
{
	set namespace = tInstaller.Evaluate("${Namespace}")
	set cspName = "/csp/" _ namespace
	
    do tInstaller.PushNS("%SYS")
	 
	if (##class(Security.Applications).Exists(cspName) = 1) {
		set status = ##class(Security.Applications).Get(cspName, .properties)
		if $$$ISERR(status) throw ##class(%Installer.Exception).CreateFromStatus(status)
		
		set properties("DeepSeeEnabled") = 1
		
		set status = ##class(Security.Applications).Modify(cspName, .properties)
		if $$$ISERR(status) throw ##class(%Installer.Exception).CreateFromStatus(status)	
	} else {
		do ##class(Security.System).GetInstallationSecuritySetting(.security)
    	if (security="None") {
    		set properties("AutheEnabled") = 64 // Unauthenticated
    	} else {
	    	set properties("AutheEnabled") = 32 // Password
    	}
    	
    	set properties("NameSpace") = namespace
    	set properties("DeepSeeEnabled") = 1
    	
    	set status = ##class(Security.Applications).Create(cspName, .properties)
    	if $$$ISERR(status) throw ##class(%Installer.Exception).CreateFromStatus(status)
	}
	
	// This is to enable system audit event
    set sysObj = ##class(Security.System).%OpenId("SYSTEM")
    if +sysObj = 0 set sysObj = ##class(Security.System).%New()
    set sysObj.AuditEnabled = 1
    set status = sysObj.%Save()
    kill sysObj
    if $$$ISERR(status) throw ##class(%Installer.Exception).CreateFromStatus(status)
	
	//do EnableDeepSee^%SYS.cspServer("/csp/" _ namespace _ "/")
	do tInstaller.PopNS()
	return $$$OK
}

ClassMethod BuildCube(pVars, pLogLevel, tInstaller) As %Status
{
	set namespace = tInstaller.Evaluate("${Namespace}")
	
	do tInstaller.PushNS(namespace)
	set status = ##class(%DeepSee.Utils).%BuildCube("Audit")
	if $$$ISERR(status) throw ##class(%Installer.Exception).CreateFromStatus(status)
	
	do tInstaller.PopNS()
	return $$$OK
}

ClassMethod CopyClasses(pVars, pLogLevel, tInstaller)
{
	
	set sc = $$$OK
	
	set i = 0
	while 1 {
		set id = "DeepSeeAudit.CLSData||File" _ i
		if (##class(%Dictionary.CompiledXData).%ExistsId(id) = 0) Q	
		set class = ##class(%Dictionary.CompiledXData).%OpenId(id)
		set data = $zconvert(class.Data.Read(class.Data.Size), "O", "UTF8")
		set className = $piece(class.Description,".",1,*-1)
		
		set Namespace = tInstaller.Evaluate("${Namespace}")
		do tInstaller.PushNS(Namespace)
		
		if ('##class(%Dictionary.ClassDefinition).%ExistsId(className)) {
			set clsDef = ##class(%Dictionary.ClassDefinition).%New()
			set clsDef.Name = className
			set sc = clsDef.%Save()
			do tInstaller.Log(pLogLevel, "Creating class", className)
			quit:$$$ISERR(sc) 
		}
		
		set sc = ##class(%Compiler.UDL.TextServices).SetTextFromString(,className,$System.Encryption.Base64Decode(data))
		
		do $system.OBJ.Compile(className)
		
		do tInstaller.PopNS()
		
		set i = i + 1
	}
		
	quit sc
}

ClassMethod CopyDFI(pVars, pLogLevel, tInstaller)
{
	set sc = $$$OK
	set i = 0
	
	while 1 {
		set id = "DeepSeeAudit.DFIData||File" _ i
		if (##class(%Dictionary.CompiledXData).%ExistsId(id) = 0) Q		
		set dfi = ##class(%Dictionary.CompiledXData).%OpenId(id)
		set data = ##class(%GlobalCharacterStream).%New()
		do data.Clear()
		
		do data.Write(
			$System.Encryption.Base64Decode(
				$zconvert(
					dfi.Data.Read(dfi.Data.Size), 
					"O", 
					"UTF8"
					)
				)
			)
			
		set dfiName = dfi.Description
				
		set Namespace = tInstaller.Evaluate("${Namespace}")
		do tInstaller.PushNS(Namespace)
		
		if '##class(%DeepSee.UI.FolderItemDocument).%ExistsId(dfiName) {
			try {
		        set tDoc = ##class(%DeepSee.UI.FolderItemDocument).%New(dfiName)
		        set sc = tDoc.ImportFromXML(data)
		        set sc = tDoc.Save()
		        do tInstaller.Log(pLogLevel, "Creating DFI", dfiName)
		    } Catch e {
		        set sc = e.AsStatus()
		        quit
		    }
		} else {
			try {
				set tDoc = ##class(%DeepSee.UI.FolderItemDocument).%OpenId(dfiName)
				set sc = tDoc.ImportFromXML(data)
				set sc = tDoc.Save()
				do tInstaller.Log(pLogLevel, "Creating DFI", dfiName)
			} Catch e {
		        set sc = e.AsStatus()
		        quit
		    }
		}
		
		do tInstaller.PopNS()
		
		set i = i + 1
	}
	
	quit sc
}

}


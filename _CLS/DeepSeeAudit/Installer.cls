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
	do ..Update()
	set status = ##class(%DeepSee.Utils).%BuildCube("Audit")
	if $$$ISERR(status) throw ##class(%Installer.Exception).CreateFromStatus(status)
	
	do tInstaller.PopNS()
	return $$$OK
}

/// Download src and compile cube class.<br>
/// <b>Namespace</b> - Namespace where audit cube should be created.
ClassMethod Update()
{
    set owner = "intersystems-ru"
    set repository = "deepseeaudit"
    set branch = "master"
    Set SSLConfig = "GitHub"
    
    set Namespace = $namespace
   
    zn "%SYS"
    do:'##class(Security.SSLConfigs).Exists(SSLConfig) ##class(Security.SSLConfigs).Create(SSLConfig)

 	set req = ##class(%Net.HttpRequest).%New()
 	set req.Https = 1
	set req.SSLConfiguration = SSLConfig
	set req.Server = "api.github.com"
	set req.Location = "repos/" _ owner _ "/" _ repository _ "/contents" 	// as described in https://developer.github.com/v3/repos/	
	do:$d(branch) req.SetParam("ref", branch) 								// if omitted the repository’s default branch (usually master) would be used
	do req.SetHeader("Accept","application/vnd.github.v3+json") 			// we want to receive API v3
	
 	set links = ##class(%ListOfDataTypes).%New()
 	
 	/*do links.Insert("https://raw.githubusercontent.com/mkashche/deepseeaudit/master/_CLS/habra/cube.xml")
 	do links.Insert("https://raw.githubusercontent.com/mkashche/deepseeaudit/master/_DFI/pivot.xml")
 	do links.Insert("https://raw.githubusercontent.com/mkashche/deepseeaudit/master/_DFI/dashboard.xml")*/
 	Set st = ..ProcessDirectory("",req,.links)
 	Return:$$$ISERR(st) st
 	
 	zn Namespace
	set st = ..DownloadFiles(links, req, .list)
	set st2 = $system.OBJ.CompileList(.list)
	
	set status = $$$ADDSC(st, st2)
	if $$$ISERR(status) throw ##class(%Installer.Exception).CreateFromStatus(status)
}

/// Download list of files on https://raw.githubusercontent.com/ server.<br>
/// <b>Links</b> - List of links to raw files.<br>
/// <b>Request</b> - Authenticated/Set %Net.HttpRequest object.<br>
/// <b>Items</b> - Returns an array of the items loaded. 
ClassMethod DownloadFiles(Links As %ListOfDataTypes, Request As %Net.HttpRequest, Output Items) As %Status
{
	kill Items
	set Request.Server = "raw.githubusercontent.com"
	set st = $$$OK
	
	for i = 1:1:Links.Count() {
		set streq = Request.Get($e(Links.GetAt(i),35,*)) // Remove "https://raw.githubusercontent.com/" from URL. 
  		set:$$$ISERR(streq) st = $$$ADDSC(st, streq)
  		set binarystream = Request.HttpResponse.Data
  		do binarystream.Rewind() // just in case

  		set stream = ##class(%GlobalCharacterStream).%New() //translating binary stream into character stream
  		while 'binarystream.AtEnd { 
  			do stream.Write(binarystream.Read()) 
  		}
  		do stream.Rewind()

  		set stload = $system.OBJ.LoadStream(stream,"",.error,.items,,,,"UTF8")
  		set:$$$ISERR(stload) st = $$$ADDSC(st, stload)
  		merge Items = items  // Does not overwrite existing array keys: Items(itemname)=""	
	}
	
	set Request.Server = "api.github.com"
	return st
}

ClassMethod ProcessDirectory(Path As %String = "", Request As %Net.HttpRequest, ByRef Links As %ListOfDataTypes) As %Status
{
	Set location = Request.Location
	Set Request.Location = Request.Location _ Path
	
	Set st = Request.Get(,,$$$NO)
	Return:$$$ISERR(st) st
	Return:(Request.HttpResponse.StatusCode = 404) $$$ERROR($$$GeneralError,"Repository doesn't exist OR you don't have access")
	Return:((Request.HttpResponse.StatusCode = 403) && (Request.HttpResponse.GetHeader("X-RATELIMIT-REMAINING")=0)) $$$ERROR($$$GeneralError,"API rate limit exceeded. Try logging in.")
 	Return:(Request.HttpResponse.StatusCode '= 200) $$$ERROR($$$GeneralError,"Received " _ Request.HttpResponse.StatusCode _ " status, expected 200")
 	
 	#dim objects As List of %ZEN.proxyObject
 	#dim obj As %ZEN.proxyObject
	Set st = ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(Request.HttpResponse.Data,,.objects,1)
	Return:$$$ISERR(st) st
	
	For i = 1:1:objects.Count() {		
		Set obj = objects.GetAt(i)
		If (obj.type = "dir") {
			Set st = ..ProcessDirectory("/"_obj.name,Request,.Links)
			Return:$$$ISERR(st) st		
		} ElseIf (obj.type = "file") {
			Do:..IsCacheFile(obj) Links.Insert(obj."download_url")
		} Else {
			// obj.type = "symlink" or obj.type = "submodule"
		} 
	}
	Set Request.Location = location // to keep track of where in the repository tree we are
	Return $$$OK
}

ClassMethod IsCacheFile(File As %ZEN.proxyObject) As %Boolean
{
	Set extensions = ",xml,cls,csp,csr,mac,int,bas,inc,gbl,prj,obj,pkg,gof,"
	Return:($L(File.name,".")=1) 0 //no extension
	Set File.Extension = $P(File.name,".",$L(File.name,"."))
	Return $F(extensions,","_$ZCVT(File.Extension,"l")_",")
}

}


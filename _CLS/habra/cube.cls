/// Данные аудита
Class habra.cube Extends %DeepSee.CubeDefinition [ DependsOn = %SYS.Audit, ProcedureBlock ]
{

/// Cube definition from Architect.
XData Cube [ XMLNamespace = "http://www.intersystems.com/deepsee" ]
{
<cube xmlns="http://www.intersystems.com/deepsee" name="Audit" displayName="Audit" description="Данные аудита" disabled="false" abstract="false" sourceClass="%SYS.Audit" countMeasureName="%COUNT" bucketSize="8" bitmapChunkInMemory="false" precompute="0" disableListingGroups="false">
  <dimension name="Who" disabled="false" hasAll="false" allCaption="All Username" allDisplayName="Username" type="data" calendar="gregorian" iKnowType="entity" hidden="false" showHierarchies="default">
    <hierarchy name="H1" disabled="false">
      <level name="Username" disabled="false" sourceProperty="Username" list="false" useDisplayValue="true" useAsFilter="true">
      </level>
    </hierarchy>
  </dimension>
  <dimension name="What" disabled="false" hasAll="false" allCaption="All Event" allDisplayName="Event" type="data" calendar="gregorian" iKnowType="entity" hidden="false" showHierarchies="default">
    <hierarchy name="H1" disabled="false">
      <level name="Event" disabled="false" sourceProperty="Event" list="false" useDisplayValue="true" useAsFilter="true">
      </level>
    </hierarchy>
  </dimension>
  <dimension name="When" disabled="false" hasAll="false" allCaption="All UTCTimeStamp" allDisplayName="UTCTimeStamp" sourceExpression="$zdatetimeh(%source.UTCTimeStamp,3)" type="time" calendar="gregorian" iKnowType="entity" hidden="false" showHierarchies="default">
    <hierarchy name="H1" disabled="false">
      <level name="Year" disabled="false" timeFunction="Year" list="false" useDisplayValue="true" useAsFilter="true">
        <additionalDescription>undefined</additionalDescription>
      </level>
      <level name="Month" disabled="false" timeFunction="MonthYear" list="false" useDisplayValue="true" useAsFilter="true">
        <additionalDescription>undefined</additionalDescription>
      </level>
      <level name="Week" disabled="false" timeFunction="WeekYear" list="false" useDisplayValue="true" useAsFilter="true">
        <additionalDescription>undefined</additionalDescription>
      </level>
      <level name="Day" disabled="false" timeFunction="DayMonthYear" list="false" useDisplayValue="true" useAsFilter="true">
      </level>
    </hierarchy>
  </dimension>
  <listing name="New_listing1" disabled="false" listingType="table" fieldList="Authentication,UTCTimeStamp,CSPSessionID,ClientIPAddress,Description,Event,EventData,EventSource,EventType,Namespace,OSUsername,Roles,Status,UserInfo,&apos;https://who.is/whois-ip/ip-address/&apos;||ClientIPAddress">
    <additionalDescription>undefined</additionalDescription>
  </listing>
</cube>
}

Parameter DOMAIN;

}

